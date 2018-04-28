module Home
    exposing
        ( Model
        , Msg
        , init
        , update
        , view
        )

import Html exposing (Html, div, input)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports.Mail as Mail exposing (Mail)


-- TYPES --


type alias Model =
    { field : String
    , number : Int
    , square : Maybe Int
    }


type Msg
    = FieldUpdated String
    | SquareClicked
    | SquareReceived (Result String Int)


init : Model
init =
    { field = ""
    , number = 0
    , square = Nothing
    }



-- UPDATE --


update : Msg -> Model -> ( Model, Mail Msg )
update msg model =
    case msg of
        FieldUpdated str ->
            ( { model
                | field = str
                , number =
                    case String.toInt str of
                        Ok number ->
                            number

                        Err _ ->
                            model.number
              }
            , Mail.none
            )

        SquareClicked ->
            ( model
            , model.number
                |> Encode.int
                |> Mail.letter "square"
                |> Mail.expectResponse Decode.int SquareReceived
                |> Mail.send
            )

        SquareReceived (Ok square) ->
            ( { model | square = Just square }
            , Mail.none
            )

        SquareReceived (Err _) ->
            ( model, Mail.none )



-- VIEW --


view : Model -> Html Msg
view model =
    div
        []
        [ Html.text "Here!" ]
