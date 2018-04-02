port module Main exposing (..)

import Home
import Html exposing (Program)
import Login
import Ports.Manager exposing (Manager)


-- MAIN --


main : Program Never Model Msg
main =
    { init = init
    , update = update
    , view = view
    , subscriptions = subscriptions
    }
        |> Html.program



-- TYPES --


type alias Model =
    { page : Page
    , user : Maybe String
    , portsManager : Manager Msg
    }


type Msg
    = LoginMsg Login.Msg
    | HomeMsg Home.Msg
    | PortsManagerError String


type Page
    = Login Login.Model
    | Home Home.Model
    | Error



-- INIT --


init : ( Model, Cmd Msg )
init =
    ( { page = Login.init
      , user = Nothing
      , portsManager =
            Ports.Manager.init "Main" PortsManagerError
      }
    , Cmd.none
    )



-- UPDATE --


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoginMsg subMsg ->
            case model.page of
                Login subModel ->
                    let
                        ( newSubModel, cmd, reply ) =
                            Login.update subMsg subModel
                    in
                    case reply of
                        NoReply ->
                            newSubModel
                                |> Tuple.mapFirst (setPage model Login)
                                |> Tuple.mapSecond (Cmd.map LoginMsg)

                _ ->
                    ( model, Cmd.none )

        HomeMsg subMsg ->
            case model.page of
                Home subModel ->
                    subModel
                        |> Home.update subMsg
                        |> Tuple.mapFirst (setPage model Home)
                        |> Tuple.mapSecond (Cmd.map LoginMsg)

                _ ->
                    ( model, Cmd.none )


setPage : Model -> (subModel -> Page) -> ( subModel, Cmd msg ) -> ( Model, Cmd msg )
setPage model pageCtor ( subModel, cmd ) =
    ( { model | page = pageCtor subModel }, cmd )



-- VIEW --


view : Model -> Html Msg
view model =
    case model.page of
        Home subModel ->
            subModel
                |> Home.view
                |> Html.map HomeMsg

        Login subModel ->
            subModel
                |> Login.view
                |> Html.map LoginMsg



-- SUBSCRIPTIONS --


subscriptions : Model -> Sub Msg
subscriptions model =
    fromJs (Ports.Manager.decode model.portsManager)



-- PORTS --


port fromJs : (Value -> Msg) -> Sub Msg


port toJs : Value -> Cmd msg
