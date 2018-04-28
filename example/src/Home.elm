module Home
    exposing
        ( Model
        , Msg
        , init
        , update
        , view
        )

import Html exposing (Html, button, div, input, p)
import Html.Attributes exposing (value)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports.Mail as Mail exposing (Mail)


-- TYPES --


type alias Model =
    { field : String
    , number : Int
    , result : Maybe ( Int, Int )
    }


type Msg
    = FieldUpdated String
    | SquareClicked
    | SquareReceived (Result String Int)


init : Model
init =
    { field = ""
    , number = 0
    , result = Nothing
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
            ( { model
                | result =
                    Just ( model.number, square )
              }
            , Mail.none
            )

        SquareReceived (Err _) ->
            ( model, Mail.none )



-- VIEW --


view : String -> Model -> Html Msg
view username model =
    div
        []
        [ p
            []
            [ welcomeText username ]
        , p
            []
            [ """
                Type the number you would like to
                square in the field below, click
                "square" and watch the magic happen.
              """
                |> Html.text
            ]
        , input
            [ onInput FieldUpdated
            , value model.field
            ]
            []
        , button
            [ onClick SquareClicked ]
            [ Html.text "square" ]
        , squareView model
        ]


squareView : Model -> Html Msg
squareView model =
    case model.result of
        Just ( number, square ) ->
            div
                []
                [ p
                    []
                    [ squareText number square ]
                ]

        Nothing ->
            Html.text ""


squareText : Int -> Int -> Html Msg
squareText number square =
    [ toString number
    , "squared is"
    , toString square ++ "!"
    ]
        |> String.join " "
        |> Html.text


welcomeText : String -> Html Msg
welcomeText username =
    [ "Welcome to Squarer"
    , username ++ "!"
    , "The ONLY app on the net that lets you square numbers"
    ]
        |> String.join " "
        |> Html.text
