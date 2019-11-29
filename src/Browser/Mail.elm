module Browser.Mail exposing
    ( Letter
    , Mail
    , Program
    , application
    , cmd
    , document
    , element
    , expectResponse
    , letter
    , map
    , none
    , send
    )

import Browser exposing (UrlRequest)
import Browser.Navigation as Navigation
import Dict exposing (Dict)
import Html exposing (Html)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Url


type alias Program json model msg =
    Platform.Program json (Model model msg) (Msg msg)


type Msg msg
    = AppMsg msg
    | PortsMsg Decode.Value


type Mail msg
    = Letter_ (Letter msg)
    | Cmd (Cmd msg)


type Letter msg
    = Letter String Encode.Value (Maybe (Decoder msg))


type alias Model model msg =
    { appModel : model
    , threads : Dict Int (Decoder msg)
    , freeThreads : List Int
    , threadCount : Int
    , toJs : Decode.Value -> Cmd msg
    , fromJs : (Decode.Value -> Msg msg) -> Sub (Msg msg)
    }


element :
    { init : flags -> ( model, Mail msg )
    , view : model -> Html msg
    , update : msg -> model -> ( model, Mail msg )
    , subscriptions : model -> Sub msg
    , toJs : Decode.Value -> Cmd msg
    , fromJs : (Decode.Value -> Msg msg) -> Sub (Msg msg)
    }
    -> Program flags model msg
element args =
    Browser.element
        { init =
            makeInit
                { init = args.init
                , toJs = args.toJs
                , fromJs = args.fromJs
                }
        , view = .appModel >> args.view >> Html.map AppMsg
        , update = update args.update
        , subscriptions = makeSubscriptions args.subscriptions
        }


application :
    { init : flags -> Url.Url -> Navigation.Key -> ( model, Mail msg )
    , view : model -> Browser.Document msg
    , update : msg -> model -> ( model, Mail msg )
    , subscriptions : model -> Sub msg
    , onUrlRequest : UrlRequest -> msg
    , onUrlChange : Url.Url -> msg
    , toJs : Decode.Value -> Cmd msg
    , fromJs : (Decode.Value -> Msg msg) -> Sub (Msg msg)
    }
    -> Program flags model msg
application args =
    Browser.application
        { init =
            makeApplicationInit
                { init = args.init
                , toJs = args.toJs
                , fromJs = args.fromJs
                }
        , view = .appModel >> args.view >> mapDocument
        , update = update args.update
        , subscriptions = makeSubscriptions args.subscriptions
        , onUrlRequest = args.onUrlRequest >> AppMsg
        , onUrlChange = args.onUrlChange >> AppMsg
        }


document :
    { init : flags -> ( model, Mail msg )
    , view : model -> Browser.Document msg
    , update : msg -> model -> ( model, Mail msg )
    , subscriptions : model -> Sub msg
    , toJs : Decode.Value -> Cmd msg
    , fromJs : (Decode.Value -> Msg msg) -> Sub (Msg msg)
    }
    -> Program flags model msg
document args =
    Browser.document
        { init =
            makeInit
                { init = args.init
                , toJs = args.toJs
                , fromJs = args.fromJs
                }
        , view = .appModel >> args.view >> mapDocument
        , update = update args.update
        , subscriptions = makeSubscriptions args.subscriptions
        }


mapDocument : Browser.Document msg -> Browser.Document (Msg msg)
mapDocument doc =
    { title = doc.title
    , body = List.map (Html.map AppMsg) doc.body
    }


makeSubscriptions :
    (model -> Sub msg)
    -> Model model msg
    -> Sub (Msg msg)
makeSubscriptions subscriptions model =
    [ Sub.map AppMsg (subscriptions model.appModel)
    , model.fromJs PortsMsg
    ]
        |> Sub.batch


update :
    (msg -> model -> ( model, Mail msg ))
    -> Msg msg
    -> Model model msg
    -> ( Model model msg, Cmd (Msg msg) )
update appUpdate msg model =
    case msg of
        AppMsg appMsg ->
            let
                ( newAppModel, mail ) =
                    appUpdate appMsg model.appModel
            in
            handleMail
                (setAppModel newAppModel model)
                mail

        PortsMsg json ->
            handleIncomingPort appUpdate json model


makeApplicationInit :
    { init : flags -> Url.Url -> Navigation.Key -> ( model, Mail msg )
    , toJs : Decode.Value -> Cmd msg
    , fromJs : (Decode.Value -> Msg msg) -> Sub (Msg msg)
    }
    -> flags
    -> Url.Url
    -> Navigation.Key
    -> ( Model model msg, Cmd (Msg msg) )
makeApplicationInit args flags url key =
    let
        ( firstAppModel, firstMail ) =
            args.init flags url key
    in
    handleMail
        { appModel = firstAppModel
        , threads = Dict.empty
        , freeThreads = []
        , threadCount = 0
        , toJs = args.toJs
        , fromJs = args.fromJs
        }
        firstMail


makeInit :
    { init : flags -> ( model, Mail msg )
    , toJs : Decode.Value -> Cmd msg
    , fromJs : (Decode.Value -> Msg msg) -> Sub (Msg msg)
    }
    -> flags
    -> ( Model model msg, Cmd (Msg msg) )
makeInit args flags =
    let
        ( firstAppModel, firstMail ) =
            args.init flags
    in
    handleMail
        { appModel = firstAppModel
        , threads = Dict.empty
        , freeThreads = []
        , threadCount = 0
        , toJs = args.toJs
        , fromJs = args.fromJs
        }
        firstMail


setAppModel : model -> Model model msg -> Model model msg
setAppModel appModel model =
    { model | appModel = appModel }


handleMail : Model model msg -> Mail msg -> ( Model model msg, Cmd (Msg msg) )
handleMail model mail =
    case mail of
        Letter_ letter_ ->
            handleLetter letter_ model

        Cmd cmd_ ->
            ( model, Cmd.map AppMsg cmd_ )


handleIncomingPort :
    (msg -> model -> ( model, Mail msg ))
    -> Decode.Value
    -> Model model msg
    -> ( Model model msg, Cmd (Msg msg) )
handleIncomingPort appUpdate json model =
    let
        useDecoder : Int -> Decoder msg -> ( Model model msg, Cmd (Msg msg) )
        useDecoder thread msgDecoder =
            let
                newModel : Model model msg
                newModel =
                    { model
                        | threads = Dict.remove thread model.threads
                        , freeThreads = thread :: model.freeThreads
                    }
            in
            case
                Decode.decodeValue
                    (Decode.field "payload" msgDecoder)
                    json
            of
                Ok appMsg ->
                    update appUpdate (AppMsg appMsg) newModel

                Err _ ->
                    ( newModel
                    , Cmd.none
                    )

        getDecoder : Int -> Decoder ( Model model msg, Cmd (Msg msg) )
        getDecoder thread =
            case Dict.get thread model.threads of
                Just msgDecoder ->
                    Decode.succeed
                        (useDecoder thread msgDecoder)

                Nothing ->
                    Decode.fail "Thread Does Not Exist"
    in
    Decode.decodeValue
        (Decode.field "thread" Decode.int
            |> Decode.andThen getDecoder
        )
        json
        |> Result.withDefault ( model, Cmd.none )


handleLetter : Letter msg -> Model model msg -> ( Model model msg, Cmd (Msg msg) )
handleLetter (Letter address payload maybeDecoder) model =
    let
        toCmd : Maybe Int -> Cmd (Msg msg)
        toCmd maybeThread =
            [ ( "address", Encode.string address )
            , ( "thread"
              , maybeThread
                    |> Maybe.map Encode.int
                    |> Maybe.withDefault Encode.null
              )
            , ( "payload", payload )
            ]
                |> Encode.object
                |> model.toJs
                |> Cmd.map AppMsg
    in
    case maybeDecoder of
        Just decoder ->
            let
                ( newModel, thread ) =
                    case model.freeThreads of
                        first :: rest ->
                            ( { model | freeThreads = rest }
                            , first
                            )

                        [] ->
                            ( { model | threadCount = model.threadCount + 1 }
                            , model.threadCount
                            )
            in
            ( { newModel
                | threads =
                    Dict.insert thread decoder model.threads
              }
            , toCmd (Just thread)
            )

        Nothing ->
            ( model
            , toCmd Nothing
            )


cmd : Cmd msg -> Mail msg
cmd =
    Cmd


letter : String -> Encode.Value -> Letter msg
letter funcName payload =
    Letter funcName payload Nothing


expectResponse : Decoder a -> (Result Decode.Error a -> msg) -> Letter msg -> Letter msg
expectResponse decoder ctor (Letter funcName json _) =
    Decode.value
        |> Decode.andThen
            (Decode.succeed << ctor << Decode.decodeValue decoder)
        |> Just
        |> Letter funcName json


send : Letter msg -> Mail msg
send =
    Letter_


none : Mail msg
none =
    cmd Cmd.none


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

        Cmd cmd_ ->
            Cmd (Cmd.map ctor cmd_)
