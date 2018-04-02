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
import Json.Decode exposing (Decoder, decodeValue)
import Json.Encode as Encode


-- TYPES --


type alias Manager msg =
    { threads : Dict Int (Decoder msg)
    , threadCount : Int
    , send : Encode.Value -> Cmd msg
    }


type Error
    = IdDecoderFailed String
    | ThreadDoesNotExist
    | SubscriptionDoesNotExist


init : (String -> msg) -> Manager msg
init errCtor =
    { threads = Dict.empty
    , threadCount = 0
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
