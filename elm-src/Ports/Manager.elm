module Ports.Manager
    exposing
        ( Error(..)
        , Manager
        , Request
        , decode
        , encode
        , init
        , jsonRequest
        , map
        , request
        , update
        )

import Dict exposing (Dict)
import Json.Decode exposing (Decoder, decodeValue)
import Json.Encode as Encode


-- TYPES --


type alias Manager msg =
    { threads : Dict String (Decoder msg)
    , threadCount : Int
    , namespace : String
    , errCtor : Error -> msg
    , send : Value -> Cmd msg
    }


type Error
    = IdDecoderFailed String
    | ThreadDoesNotExist
    | SubscriptionDoesNotExist
    | MsgDecoderFailed String


type alias Request a msg =
    { decoder : Decoder a
    , msgCtor : a -> msg
    , outgoingMsg : ( String, Encode.Value )
    }


init : String -> (String -> msg) -> Manager msg
init namespace errCtor =
    { threads = Dict.empty
    , threadCount = 0
    , namespace = namespace
    , errCtor = errCtor
    }


request : Decoder a -> (a -> msg) -> ( String, Encode.Value ) -> Request
request =
    Request


jsonRequest : (Decode.Value -> msg) -> ( String, Encode.Value ) -> Request
jsonRequest =
    Request Decode.value


map : (a -> b) -> Request a -> Request b
map ctor request =
    { request | msgCtor = ctor << request.msgCtor }


update : Request a msg -> Manager msg -> ( Manager msg, Cmd msg )
update request manager =
    let
        threadKey =
            manager.namespace ++ toString manager.threadCount
    in
    ( { manager
        | threads =
            Dict.set
                threadKey
                (Decode.map request.msgCtor request.decoder)
                manager.threads
        , threadCount = manager.threadCount + 1
      }
    , request.jsMsg
        |> encode threadKey
        |> manager.send
    )


encode : String -> ( String, Encode.Value ) -> Encode.Value
encode id ( type_, pmayload ) =
    [ ( "id", Encode.string id )
    , ( "type", Encode.string type_ )
    , ( "payload", payload )
    ]
        |> Encode.object


idDecoder : Decoder String
idDecoder =
    Decode.field "id" Decode.string


payload : Decoder a -> Decoder a
payload decoder =
    Decode.field "payload"


decode : Manager msg -> Decode.Value -> ( Manager msg, msg )
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
                        |> manager.errCtoro


resolveThread : String -> Manager msg -> Decode.Value -> ( Manager msg, msg )
resolveThread key manager json =
    case Dict.get key manager.threads of
        Just decoder ->
            case decodeValue (payload decoder) json of
                Ok msg ->
                    ( { manager
                        | threads =
                            Dict.remove key manager.threads
                      }
                    , msg
                    )

                Err err ->
                    ( manager
                    , err
                        |> MsgDecoderFailed
                        |> manager.errCtor
                    )

        Nothing ->
            ( manager, manager.errCtor ThreadDoesNotExist )
