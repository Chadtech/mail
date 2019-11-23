port module Main exposing (Model, Msg(..), Page(..), errorView, fromJs, init, main, setPage, toJs, update, view)

import Browser.Mail as Browser exposing (Mail)
import Home
import Html exposing (Html)
import Json.Encode exposing (Value)
import Login



-- MAIN --


main : Browser.Program Never Model Msg
main =
    { init = init
    , update = update
    , view = view
    , subscriptions = always Sub.none
    , toJs = toJs
    , fromJs = fromJs
    }
        |> Browser.element



-- TYPES --


type alias Model =
    { page : Page
    , user : Maybe String
    }


type Msg
    = LoginMsg Login.Msg
    | HomeMsg Home.Msg


type Page
    = Login Login.Model
    | Home Home.Model
    | Error


init : ( Model, Mail Msg )
init =
    ( { page = Login Login.init
      , user = Nothing
      }
    , Browser.none
    )



-- UPDATE --


update : Msg -> Model -> ( Model, Mail Msg )
update msg model =
    case msg of
        LoginMsg subMsg ->
            case model.page of
                Login subModel ->
                    let
                        ( newSubModel, mail, reply ) =
                            Login.update subMsg subModel
                    in
                    case reply of
                        Login.NoReply ->
                            ( setPage model Login newSubModel
                            , Browser.map LoginMsg mail
                            )

                        Login.SetUser username ->
                            ( { model
                                | user = Just username
                                , page = Home Home.init
                              }
                            , Browser.map LoginMsg mail
                            )

                _ ->
                    ( model, Browser.none )

        HomeMsg subMsg ->
            case model.page of
                Home subModel ->
                    subModel
                        |> Home.update subMsg
                        |> Tuple.mapFirst (setPage model Home)
                        |> Tuple.mapSecond (Browser.map HomeMsg)

                _ ->
                    ( model, Browser.none )


setPage : Model -> (subModel -> Page) -> subModel -> Model
setPage model pageCtor subModel =
    { model | page = pageCtor subModel }



-- VIEW --


view : Model -> Html Msg
view model =
    case model.page of
        Home subModel ->
            case model.user of
                Just user ->
                    subModel
                        |> Home.view user
                        |> Html.map HomeMsg

                Nothing ->
                    errorView

        Login subModel ->
            subModel
                |> Login.view
                |> Html.map LoginMsg

        Error ->
            errorView


errorView : Html Msg
errorView =
    Html.text "Oh no something went wrong"



-- PORTS --


port fromJs : (Value -> msg) -> Sub msg


port toJs : Value -> Cmd msg
