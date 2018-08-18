module Ports.Mail
    exposing
        ( Letter
        , Mail
        , Program
        , programWithFlags
        , programWithNavigation
        , programWithNavigationAndFlags
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

@docs Program, program, programWithFlags, programWithNavigation, programWithNavigationAndFlags

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Platform
import Platform.Cmd
import Navigation


-- TYPES --


{-| Identical to the type `Platform.Program`
-}
type alias Program json model msg =
    Platform.Program json (Model model msg) (Msg msg)


{-| `Mail` is stuff thats sent out of the Elm run time. `Mail` is sent out from update functions as `(Model, Mail Msg)`, just like `Cmd`s are in a normal Elm application. Regular Elm `Cmd`s can be wrapped up as a `Mail`, along with `Letter`s.

    import Ports.Mail as Mail exposing (Mail)

    update : Msg -> Model -> ( Model, Mail Msg )
    update msg model =
        case msg of
            ShutDownClicked ->
                ( model, attemptShutDown )

            ShutDownGranted (Ok True) ->
                ( model, shutDown )

            ShutDownGranted _ ->
                ( model, Mail.none )

    attemptShutDown : Mail Msg
    attemptShutDown =
        Encode.null
            |> Mail.letter "attemptShutDown"
            |> Mail.expectResponse Decode.bool ShutDownGranted
            |> Mail.send

-}
type Mail msg
    = Single (SingleMail msg)
    | Batched (List (SingleMail msg))


type SingleMail msg
    = Letter_ (Letter msg)
    | Cmd (Cmd msg)


{-| `Letter`s are things that go through ports into the JS side of your application. They can either be made to expect an explicit response, or be made to just "send and forget" without receiving a response.

    Mail.letter "receiveName" (Encode.string "Ludwig")
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


{-| The same as `Html.program` with two exceptions. First the model takes toJs and fromJs ports. Second, the init and update functions return `(model, Mail msg)` instead of `(model, Cmd msg)`. You can still issue `Cmd msg`s, just through the `Mail.cmd` function. The toJs and fromJs ports *must* have the following names and type signatures.

    import Json.Encode
    import Ports.Mail as Mail exposing (Mail)

    main : Mail.Program Never Model Msg
    main =
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        , toJs = toJs
        , fromJs = fromJs
        }
            |> Mail.program

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


{-| The same as `Html.programWithFlags` with two exceptions. First the model takes toJs and fromJs ports. Second, the init and update functions return `(model, Mail msg)` instead of `(model, Cmd msg)`. You can still issue `Cmd msg`s, just through the `Mail.cmd` function. The toJs and fromJs ports *must* have the following names and type signatures.

    import Json.Encode
    import Ports.Mail as Mail exposing (Mail)

    init : Flags -> (Model, Mail msg)
    init flags = ...

    main : Mail.Program flags Model Msg
    main =
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        , toJs = toJs
        , fromJs = fromJs
        }
            |> Mail.programWithFlags

    port fromJs : (Json.Encode.Value -> msg) -> Sub msg

    port toJs : Json.Encode.Value -> Cmd msg

-}
programWithFlags :
    { init : flags -> ( model, Mail msg )
    , update : msg -> model -> ( model, Mail msg )
    , view : model -> Html msg
    , subscriptions : model -> Sub msg
    , toJs : Value -> Cmd msg
    , fromJs : (Value -> Msg msg) -> Sub (Msg msg)
    }
    -> Platform.Program flags (Model model msg) (Msg msg)
programWithFlags manifest =
    { init = (\flags -> init manifest.toJs manifest.fromJs manifest.update (manifest.init flags))
    , update = update manifest.update
    , view = view manifest.view
    , subscriptions = subscriptions manifest.subscriptions
    }
        |> Html.programWithFlags


{-| The same as `Navigation.programWithFlags` with two exceptions. First the model takes toJs and fromJs ports. Second, the init and update functions return `(model, Mail msg)` instead of `(model, Cmd msg)`. You can still issue `Cmd msg`s, just through the `Mail.cmd` function. The toJs and fromJs ports *must* have the following names and type signatures.
To read more about the Navigation library: <http://package.elm-lang.org/packages/elm-lang/navigation>
-}
programWithNavigationAndFlags :
    (Navigation.Location -> Msg msg)
    ->
        { init : flags -> Navigation.Location -> ( model, Mail msg )
        , update : msg -> model -> ( model, Mail msg )
        , view : model -> Html msg
        , subscriptions : model -> Sub msg
        , toJs : Value -> Cmd msg
        , fromJs : (Value -> Msg msg) -> Sub (Msg msg)
        }
    -> Platform.Program flags (Model model msg) (Msg msg)
programWithNavigationAndFlags locationToMsg manifest =
    { init = (\flags location -> init manifest.toJs manifest.fromJs manifest.update (manifest.init flags location))
    , update = update manifest.update
    , view = view manifest.view
    , subscriptions = subscriptions manifest.subscriptions
    }
        |> Navigation.programWithFlags locationToMsg


{-| The same as `Navigation.program` with two exceptions. First the model takes toJs and fromJs ports. Second, the init and update functions return `(model, Mail msg)` instead of `(model, Cmd msg)`. You can still issue `Cmd msg`s, just through the `Mail.cmd` function. The toJs and fromJs ports *must* have the following names and type signatures.
To read more about the Navigation library: <http://package.elm-lang.org/packages/elm-lang/navigation>
-}
programWithNavigation :
    (Navigation.Location -> Msg msg)
    ->
        { init : Navigation.Location -> ( model, Mail msg )
        , update : msg -> model -> ( model, Mail msg )
        , view : model -> Html msg
        , subscriptions : model -> Sub msg
        , toJs : Value -> Cmd msg
        , fromJs : (Value -> Msg msg) -> Sub (Msg msg)
        }
    -> Platform.Program Never (Model model msg) (Msg msg)
programWithNavigation locationToMsg manifest =
    { init = (\location -> init manifest.toJs manifest.fromJs manifest.update (manifest.init location))
    , update = update manifest.update
    , view = view manifest.view
    , subscriptions = subscriptions manifest.subscriptions
    }
        |> Navigation.program locationToMsg


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


convertBatchedMailsToCmdList : ( Model model msg, List (SingleMail msg) ) -> ( Model model msg, List (Cmd (Msg msg)) )
convertBatchedMailsToCmdList ( model, mails ) =
    List.foldr
        (\mail ( modelToUpdate, cmdList ) ->
            let
                ( updatedModel, newCmd ) =
                    handleSingleMail ( modelToUpdate, mail )
            in
                ( updatedModel, cmdList ++ [ newCmd ] )
        )
        ( model, [] )
        mails


handleMail : ( Model model msg, Mail msg ) -> ( Model model msg, Cmd (Msg msg) )
handleMail ( model, mail ) =
    case mail of
        Batched mails ->
            let
                ( newModel, cmdList ) =
                    convertBatchedMailsToCmdList ( model, mails )
            in
                ( newModel, Platform.Cmd.batch cmdList )

        Single singleMail ->
            handleSingleMail ( model, singleMail )


handleSingleMail : ( Model model msg, SingleMail msg ) -> ( Model model msg, Cmd (Msg msg) )
handleSingleMail ( model, mail ) =
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
    Single << Cmd


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
    Single << Letter_


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
        Batched singleMails ->
            Batched (List.map (mapSingle ctor) singleMails)

        Single mail ->
            mapSingle ctor mail
                |> Single


mapSingle : (a -> b) -> SingleMail a -> SingleMail b
mapSingle ctor mail =
    case mail of
        Letter_ (Letter funcName json Nothing) ->
            (Letter_) (Letter funcName json Nothing)

        Letter_ (Letter funcName json (Just decoder)) ->
            decoder
                |> Decode.map ctor
                |> Just
                |> Letter funcName json
                |> Letter_

        Cmd cmd ->
            Cmd (Cmd.map ctor cmd)


{-| Batch a list of Mail so that each one is executed after eachother.
This allows you to send multiple letters at once and is equivalent to Cmd.batch.

    Mail.batch [StoreFirebaseUser, StoreFirebaseMessage]

-}
batch : List (Mail msg) -> Mail msg
batch =
    List.foldr
        (\batchedMails mail ->
            case mail of
                Single m1 ->
                    case batchedMails of
                        Batched mails ->
                            Batched (mails ++ [ m1 ])

                        Single m2 ->
                            Batched [ m1, m2 ]

                Batched mailList1 ->
                    case batchedMails of
                        Batched mailList2 ->
                            Batched (mailList1 ++ mailList2)

                        Single m1 ->
                            Batched (mailList1 ++ [ m1 ])
        )
        (Batched [])
