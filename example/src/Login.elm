module Login
    exposing
        ( Model
        , Msg
        , Reply(..)
        , init
        , update
        , view
        )

import Html exposing (Html, br, button, div, input, p)
import Html.Attributes exposing (type_, value)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports.Mail as Mail exposing (Mail)


-- TYPES --


type alias Model =
    { username : String
    , password : String
    , wrongPassword : Bool
    }


type Msg
    = FieldUpdated Field String
    | SubmitClicked
    | LoginFinished (Result String String)


type Field
    = Username
    | Password


type Reply
    = NoReply
    | SetUser String



-- INIT --


init : Model
init =
    { username = ""
    , password = ""
    , wrongPassword = False
    }



-- UPDATE --


update : Msg -> Model -> ( Model, Mail Msg, Reply )
update msg model =
    case msg of
        FieldUpdated Username str ->
            ( { model | username = str }
            , Mail.none
            , NoReply
            )

        FieldUpdated Password str ->
            ( { model | password = str }
            , Mail.none
            , NoReply
            )

        SubmitClicked ->
            ( model
            , mailLogin model
            , NoReply
            )

        LoginFinished (Ok username) ->
            ( model
            , Mail.none
            , SetUser username
            )

        LoginFinished (Err _) ->
            ( { model | wrongPassword = True }
            , Mail.none
            , NoReply
            )


mailLogin : Model -> Mail Msg
mailLogin model =
    model
        |> loginPayload
        |> Mail.letter "login"
        |> Mail.expectResponse Decode.string LoginFinished
        |> Mail.send


loginPayload : Model -> Encode.Value
loginPayload model =
    [ ( "username", Encode.string model.username )
    , ( "password", Encode.string model.password )
    ]
        |> Encode.object



-- VIEW --


view : Model -> Html Msg
view model =
    div
        []
        [ p
            []
            [ Html.text "username" ]
        , input
            [ value model.username
            , onInput (FieldUpdated Username)
            ]
            []
        , p
            []
            [ Html.text "password (hint: its \"password\")" ]
        , input
            [ value model.password
            , onInput (FieldUpdated Password)
            , type_ "password"
            ]
            []
        , wrongPasswordView model
        , button
            [ onClick SubmitClicked ]
            [ Html.text "Submit" ]
        ]


wrongPasswordView : Model -> Html Msg
wrongPasswordView model =
    if model.wrongPassword then
        p
            []
            [ Html.text "You entered the wrong password!" ]
    else
        br [] []
