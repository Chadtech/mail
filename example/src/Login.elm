module Login exposing
    ( Model
    , Msg
    , init
    , update
    , view
    )

import Browser.Mail as Mail exposing (Mail)
import Browser.Navigation as Nav
import Html exposing (Html)
import Html.Attributes exposing (type_, value)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode
import Json.Encode as Encode
import Route



-- TYPES --


type alias Model =
    { username : String
    , password : String
    , wrongPassword : Bool
    , user : Maybe String
    , navKey : Nav.Key
    }


type Msg
    = FieldUpdated Field String
    | SubmitClicked
    | LoginFinished (Result Decode.Error String)


type Field
    = Username
    | Password



-- INIT --


init : Nav.Key -> Model
init navKey =
    { username = ""
    , password = ""
    , wrongPassword = False
    , user = Nothing
    , navKey = navKey
    }



-- UPDATE --


update : Msg -> Model -> ( Model, Mail Msg )
update msg model =
    case msg of
        FieldUpdated Username str ->
            ( { model | username = str }
            , Mail.none
            )

        FieldUpdated Password str ->
            ( { model | password = str }
            , Mail.none
            )

        SubmitClicked ->
            ( model
            , mailLogin model
            )

        LoginFinished (Ok user) ->
            ( { model | user = Just user }
            , Route.goTo model.navKey Route.Home
            )

        LoginFinished (Err _) ->
            ( { model | wrongPassword = True }
            , Mail.none
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


view : Model -> List (Html Msg)
view model =
    [ Html.p
        []
        [ Html.text "username" ]
    , Html.input
        [ value model.username
        , onInput (FieldUpdated Username)
        ]
        []
    , Html.p
        []
        [ Html.text "password (hint: its \"password\")" ]
    , Html.input
        [ value model.password
        , onInput (FieldUpdated Password)
        , type_ "password"
        ]
        []
    , wrongPasswordView model
    , Html.button
        [ onClick SubmitClicked ]
        [ Html.text "Submit" ]
    ]


wrongPasswordView : Model -> Html Msg
wrongPasswordView model =
    if model.wrongPassword then
        Html.p
            []
            [ Html.text "You entered the wrong password!" ]

    else
        Html.br [] []
