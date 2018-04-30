module Ports.Mail
    exposing
        ( Letter
        , Mail
        , Program
        , cmd
        , expectResponse
        , letter
        , map
        , none
        , program
        , send
        )

{-| A different way of using ports in Elm, as a request and response similar to http request. Please look at the readme and github example for a full explanation of this package.


# Mail

@docs Mail, Letter, letter, expectResponse, send, map, cmd, none


# Program

@docs Program, program

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Platform
import Platform.Cmd


-- TYPES --


{-| Identical to the type `Platform.Program`
-}
type alias Program json model msg =
    Platform.Program json (Model model msg) (Msg msg)


{-| `Mail` is stuff thats sent out of the Elm run time. Regular Elm `Cmd`s are wrapped up as a `Mail`, along with `Letter`s. `Mail` is sent out from update functions as `(Model, Mail Msg)`, just like `Cmd`s are in a normal Elm application.

    update : Msg -> Model -> ( Model, Mail Msg )
    update msg model =
        case msg of
            ShutDownClicked ->
                ( model, attemptShutDown )

            ShutDownGranted True ->
                ( model, shutDown )

            ShutDownGranted False ->
                ( model, Mail.none )

    attemptShutDown : Mail Msg
    attemptShutDown =
        Encode.null
            |> Mail.etter "attemptShutDown"
            |> Mail.ExpectResponse Decode.bool ShutDownGranted
            |> Mail.send

-}
type Mail msg
    = Letter_ (Letter msg)
    | Cmd (Cmd msg)


{-| Letters are things that go through ports into the JS side of your application. They can either be made to expect an explicit response, or be made to just "send and forget" without receiving a response.

    Mail.letter "receiveName" (Encode.sting "Ludwig")
    -- The address "receiveName" in JS will receive
    -- the value "Ludwig"

-}
type Letter msg
    = Letter String Encode.Value (Maybe (Decoder msg))


type alias Model model msg =
    { appModel : model
    , appUpdate : msg -> model -> ( model, Mail msg )
    , threads : Dict Int (Decoder msg)
    , freeThreads : List Int
    , threadCount : Int
    , toJs : Value -> Cmd msg
    , fromJs : (Value -> Msg msg) -> Sub (Msg msg)
    }


type Msg msg
    = AppMsg msg
    | PortsMsg Decode.Value


{-| The same as `Html.program` with two exceptions. First the model takes toJs and fromJs ports. Second, the init and update functions return `(model, Mail msg)` instead of `(model, Cmd msg)`. You can still issue `Cmd msg`s, just through the `Mail.cmd` function. The toJs and fromJs ports _must_ have the following names and type signatures.

    port fromJs : (Json.Encode.Value -> msg) -> Sub msg

    port toJs : Json.Encode.Value -> Cmd msg

-}
program :
    { init : ( model, Mail msg )
    , update : msg -> model -> ( model, Mail msg )
    , view : model -> Html msg
    , subscriptions : model -> Sub msg
    , toJs : Value -> Cmd msg
    , fromJs : (Value -> Msg msg) -> Sub (Msg msg)
    }
    -> Platform.Program Never (Model model msg) (Msg msg)
program manifest =
    { init = init manifest.toJs manifest.fromJs manifest.update manifest.init
    , update = update manifest.update
    , view = view manifest.view
    , subscriptions = subscriptions manifest.subscriptions
    }
        |> Html.program


view : (model -> Html msg) -> Model model msg -> Html (Msg msg)
view appView model =
    model.appModel
        |> appView
        |> Html.map AppMsg


subscriptions : (model -> Sub msg) -> Model model msg -> Sub (Msg msg)
subscriptions appSubscriptions model =
    [ Sub.map AppMsg (appSubscriptions model.appModel)
    , model.fromJs PortsMsg
    ]
        |> Sub.batch


init :
    (Value -> Cmd msg)
    -> ((Value -> Msg msg) -> Sub (Msg msg))
    -> (msg -> model -> ( model, Mail msg ))
    -> ( model, Mail msg )
    -> ( Model model msg, Cmd (Msg msg) )
init toJs fromJs appUpdate ( appModel, mail ) =
    ( { appModel = appModel
      , appUpdate = appUpdate
      , threads = Dict.empty
      , freeThreads = []
      , threadCount = 0
      , toJs = toJs
      , fromJs = fromJs
      }
    , mail
    )
        |> handleMail


update :
    (msg -> model -> ( model, Mail msg ))
    -> Msg msg
    -> Model model msg
    -> ( Model model msg, Cmd (Msg msg) )
update f msg model =
    case msg of
        AppMsg msg ->
            model.appModel
                |> f msg
                |> Tuple.mapFirst (insertAppModel model)
                |> handleMail

        PortsMsg json ->
            handleIncomingPort model json


handleIncomingPort : Model model msg -> Decode.Value -> ( Model model msg, Cmd (Msg msg) )
handleIncomingPort model json =
    json
        |> decodeField "thread" Decode.int
        |> Result.toMaybe
        |> Maybe.andThen (getDecoder model.threads)
        |> Maybe.map (useDecoder model json)
        |> Maybe.withDefault ( model, Cmd.none )


useDecoder : Model model msg -> Decode.Value -> ( Int, Decoder msg ) -> ( Model model msg, Cmd (Msg msg) )
useDecoder model json ( thread, decoder ) =
    case decodeField "payload" decoder json of
        Ok msg ->
            { model
                | threads = Dict.remove thread model.threads
                , freeThreads = thread :: model.freeThreads
            }
                |> update model.appUpdate (AppMsg msg)

        Err _ ->
            ( model, Cmd.none )


getDecoder : Dict Int (Decoder msg) -> Int -> Maybe ( Int, Decoder msg )
getDecoder threads thread =
    Dict.get thread threads
        |> Maybe.map ((,) thread)


decodeField : String -> Decoder a -> Decode.Value -> Result String a
decodeField field decoder =
    Decode.decodeValue (Decode.field field decoder)


insertAppModel : Model model msg -> model -> Model model msg
insertAppModel model appModel =
    { model | appModel = appModel }


handleMail : ( Model model msg, Mail msg ) -> ( Model model msg, Cmd (Msg msg) )
handleMail ( model, mail ) =
    case mail of
        Letter_ letter ->
            handleLetter letter model

        Cmd cmd ->
            ( model, Cmd.map AppMsg cmd )


handleLetter : Letter msg -> Model model msg -> ( Model model msg, Cmd (Msg msg) )
handleLetter (Letter address payload maybeDecoder) model =
    case maybeDecoder of
        Just decoder ->
            let
                ( newModel, thread ) =
                    newThread model
            in
            ( insertThread thread decoder newModel
            , Cmd.map AppMsg <| toCmd address (Just thread) payload model
            )

        Nothing ->
            ( model
            , Cmd.map AppMsg <| toCmd address Nothing payload model
            )


newThread : Model model msg -> ( Model model msg, Int )
newThread model =
    case model.freeThreads of
        first :: rest ->
            ( { model | freeThreads = rest }
            , first
            )

        [] ->
            ( { model | threadCount = model.threadCount + 1 }
            , model.threadCount
            )


insertThread : Int -> Decoder msg -> Model model msg -> Model model msg
insertThread thread decoder model =
    { model | threads = Dict.insert thread decoder model.threads }


toCmd : String -> Maybe Int -> Value -> Model model msg -> Cmd msg
toCmd address maybeThread payload model =
    [ ( "address", Encode.string address )
    , ( "thread", encodeMaybe maybeThread Encode.int )
    , ( "payload", payload )
    ]
        |> Encode.object
        |> model.toJs


encodeMaybe : Maybe a -> (a -> Value) -> Value
encodeMaybe maybe encoder =
    case maybe of
        Just val ->
            encoder val

        Nothing ->
            Encode.null



-- MAIL FUNCTIONS --


{-| You can still use `Cmd`s in a `Mail.Program`, you just have to wrap it using `Mail.cmd`

    Random.generate NewFace (Random.int 1 6)
        |> Mail.cmd
    -- : Mail Msg

    Mail.none == Mail.cmd Cmd.none

-}
cmd : Cmd msg -> Mail msg
cmd =
    Cmd


{-| Construct a letter. The `String` parameter is the "address" your `Encode.Value` will reach. The address is defined as the key in the javascript object given to `PortsMail` in your javascript. In the following case its `"getRandomNumber"`

    -- In Elm
    Mail.letter "getRandomNumber" (Encode.int 12)

    -- In JavaScript
    PortsMail(app, {
        getRandomNumber: function(payload, reply) {
            reply(Math.floor(payload * Math.random()));
        }
    });

-}
letter : String -> Encode.Value -> Letter msg
letter funcName payload =
    Letter funcName payload Nothing


{-| Many ports are sent out with the expectation of a response. To define what exactly your outgoing message expects in return, use this function. It takes a `Decoder a` of the value it expects in the incoming Json, a `Msg` constructor that can handle the result of decoding the value, and an existing letter.

    Mail.expectResponse Decode.int RandomNumberFetched

-}
expectResponse : Decoder a -> (Result String a -> msg) -> Letter msg -> Letter msg
expectResponse decoder ctor (Letter funcName json _) =
    Letter funcName json (Just <| toMsgDecoder decoder ctor)


toMsgDecoder : Decoder a -> (Result String a -> msg) -> Decoder msg
toMsgDecoder decoder ctor =
    Decode.value
        |> Decode.andThen
            (Decode.succeed << ctor << Decode.decodeValue decoder)


{-| This function packs a `Letter` up into a `Mail`.
-}
send : Letter msg -> Mail msg
send =
    Letter_


{-| No `Mail` to send, just like..

    Cmd.none : Cmd msg
    Mail.none : Mail msg

-}
none : Mail msg
none =
    cmd Cmd.none


{-| Map your `Mail` from one type to another

    Mail.map LoginMsg loginMail

..much like..

    Cmd.map LoginMsg loginCmd
    Html.map LoginMsg Login.view

-}
map : (a -> b) -> Mail a -> Mail b
map ctor mail =
    case mail of
        Letter_ (Letter funcName json Nothing) ->
            Letter_ (Letter funcName json Nothing)

        Letter_ (Letter funcName json (Just decoder)) ->
            decoder
                |> Decode.map ctor
                |> Just
                |> Letter funcName json
                |> Letter_

        Cmd cmd ->
            Cmd (Cmd.map ctor cmd)
