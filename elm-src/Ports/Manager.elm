module Ports.Manager
    exposing
        ( Error(..)
        , Manager
        , decode
        , encode
        , init
        , jsonRequest
        , request
        , update
        )

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, decodeValue)
import Json.Encode as Encode exposing (Value)


-- TYPES --


type alias Manager msg =
    { threads : Dict Int (Decoder msg)
    , threadCount : Int
    , send : Value -> Cmd msg
    }


type Error
    = IdDecoderFailed String
    | ThreadDoesNotExist
    | SubscriptionDoesNotExist


type Msg msg
    = AppMsg msg
    | PortsMsg Decode.Value


init : (String -> msg) -> (Value -> Cmd msg) -> Manager msg
init errCtor send =
    { threads = Dict.empty
    , threadCount = 0
    , send = send
    }


update : Maybe (Request a msg) -> Manager msg -> ( Manager msg, Cmd msg )
update maybeRequest manager =
    case maybeRequest of
        Just request ->
            ( { manager
                | threads =
                    Dict.set
                        manager.threadCount
                        request
                        manager.threads
                , threadCount = manager.threadCount + 1
              }
            , request.jsMsg
                |> encode manager.threadCount
                |> manager.send
            )

        Nothing ->
            ( manager, Cmd.none )


encode : Int -> ( String, Encode.Value ) -> Encode.Value
encode id ( type_, pmayload ) =
    [ ( "id", Encode.string id )
    , ( "type", Encode.string type_ )
    , ( "payload", payload )
    ]
        |> Encode.object


idDecoder : Decoder Int
idDecoder =
    Decode.field "id" Decode.int


payload : Decoder a -> Decoder a
payload decoder =
    Decode.field "payload"


decode : Manager msg -> Decode.Value -> msg
decode manager json =
    case decodeValue idDecoder json of
        Ok id ->
            resolveThread id manager json

        Err err ->
            case decode errDecoder json of
                Ok id ->
                    handleError id manager

                Err _ ->
                    err
                        |> IdDecoderFailed
                        |> manager.errCtor


resolveThread : String -> Manager msg -> Decode.Value -> msg
resolveThread key manager json =
    case Dict.get key manager.threads of
        Just { decoder, msgCtor } ->
            json
                |> decodeValue (payload decoder)
                |> msgCtor

        Nothing ->
            manager.errCtor ThreadDoesNotExist
