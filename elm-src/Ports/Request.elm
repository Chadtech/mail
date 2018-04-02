module Ports.Request
    exposing
        ( Request
        , map
        , request
        )

import Json.Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)


type alias Request a msg =
    { type_ : String
    , payload : Encode.Value
    , msgCtor : Result String a -> msg
    , decoder : Decoder a
    }


request : String -> Encode.Value -> (Result String a -> msg) -> Decoder a -> Request a msg
request =
    Request


map : (a -> b) -> Request data a -> Request data b
map ctor request =
    { request | msgCtor = ctor << request.msgCtor }
