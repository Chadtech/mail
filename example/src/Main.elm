port module Main exposing (main)

import Browser exposing (UrlRequest)
import Browser.Mail as Mail exposing (Mail)
import Browser.Navigation as Nav
import Home
import Html exposing (Html)
import Json.Decode as Decode
import Json.Encode exposing (Value)
import Login
import Route exposing (Route)
import Url exposing (Url)



-- MAIN --


main : Mail.Program Decode.Value Model Msg
main =
    { init = init
    , update = update
    , view = view
    , subscriptions = always Sub.none
    , onUrlRequest = UrlRequested
    , onUrlChange = UrlChanged << Route.fromUrl
    , toJs = toJs
    , fromJs = fromJs
    }
        |> Mail.application


init : Decode.Value -> Url -> Nav.Key -> ( Model, Mail Msg )
init _ url key =
    Login (Login.init key)
        |> handleRoute (Route.fromUrl url)



-- TYPES --


type Model
    = Login Login.Model
    | Home Home.Model
    | Error Nav.Key String


type Msg
    = LoginMsg Login.Msg
    | HomeMsg Home.Msg
    | UrlRequested UrlRequest
    | UrlChanged (Maybe Route)



-- HELPERS --


getUser : Model -> Maybe String
getUser model =
    case model of
        Login subModel ->
            subModel.user

        Home subModel ->
            Just subModel.user

        Error _ _ ->
            Nothing


getNavKey : Model -> Nav.Key
getNavKey model =
    case model of
        Login subModel ->
            subModel.navKey

        Home subModel ->
            subModel.navKey

        Error navKey _ ->
            navKey



-- UPDATE --


update : Msg -> Model -> ( Model, Mail Msg )
update msg model =
    case msg of
        LoginMsg subMsg ->
            case model of
                Login subModel ->
                    Login.update subMsg subModel
                        |> Tuple.mapFirst Login
                        |> Tuple.mapSecond (Mail.map LoginMsg)

                _ ->
                    ( model, Mail.none )

        HomeMsg subMsg ->
            case model of
                Home subModel ->
                    Home.update subMsg subModel
                        |> Tuple.mapFirst Home
                        |> Tuple.mapSecond (Mail.map HomeMsg)

                _ ->
                    ( model, Mail.none )

        UrlRequested urlRequest ->
            ( model, Mail.none )

        UrlChanged maybeRoute ->
            handleRoute maybeRoute model


handleRoute : Maybe Route -> Model -> ( Model, Mail msg )
handleRoute maybeRoute model =
    let
        navKey : Nav.Key
        navKey =
            getNavKey model
    in
    case maybeRoute of
        Just Route.Home ->
            case getUser model of
                Just user ->
                    ( Home.init navKey { user = user }
                        |> Home
                    , Mail.none
                    )

                Nothing ->
                    ( model
                    , Route.goTo navKey Route.Login
                    )

        Just Route.Login ->
            ( Login.init navKey
                |> Login
            , Mail.none
            )

        Nothing ->
            ( model, Mail.none )



-- VIEW --


view : Model -> Browser.Document Msg
view model =
    { title = "Squarer"
    , body =
        case model of
            Home subModel ->
                subModel
                    |> Home.view
                    |> List.map (Html.map HomeMsg)

            Login subModel ->
                subModel
                    |> Login.view
                    |> List.map (Html.map LoginMsg)

            Error _ errorText ->
                [ Html.text errorText ]
    }



-- PORTS --


port fromJs : (Value -> msg) -> Sub msg


port toJs : Value -> Cmd msg
