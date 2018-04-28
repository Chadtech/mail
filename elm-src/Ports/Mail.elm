module Ports.Mail
    exposing
        ( Letter
        , Mail
        , Msg
        , Program
        , cmd
        , expectResponse
        , letter
        , map
        , none
        , program
        , send
        )

import Dict exposing (Dict)
import Html exposing (Html)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Platform
import Platform.Cmd


-- TYPES --


type alias Program json model msg =
    Platform.Program json (Model model msg) (Msg msg)


type Mail msg
    = Letter_ (Letter msg)
    | Cmd (Cmd msg)
    | None


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

        None ->
            ( model, Cmd.none )


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


cmd : Cmd msg -> Mail msg
cmd =
    Cmd


letter : String -> Encode.Value -> Letter msg
letter funcName payload =
    Letter funcName payload Nothing


expectResponse : Decoder a -> (Result String a -> msg) -> Letter msg -> Letter msg
expectResponse decoder ctor (Letter funcName json _) =
    Letter funcName json (Just <| toMsgDecoder decoder ctor)


toMsgDecoder : Decoder a -> (Result String a -> msg) -> Decoder msg
toMsgDecoder decoder ctor =
    Decode.value
        |> Decode.andThen
            (Decode.succeed << ctor << Decode.decodeValue decoder)


send : Letter msg -> Mail msg
send =
    Letter_


none : Mail msg
none =
    None


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

        None ->
            None
