module Home exposing
    ( Model
    , Msg
    , init
    , update
    , view
    )

import Browser.Mail as Mail exposing (Mail)
import Browser.Navigation as Nav
import Html exposing (Html)
import Html.Attributes as Attrs
import Html.Events as Events
import Json.Decode as Decode
import Json.Encode as Encode



-- TYPES --


type alias Model =
    { field : String
    , number : Int
    , result : Maybe ( Int, Int )
    , user : String
    , navKey : Nav.Key
    }


type Msg
    = FieldUpdated String
    | SquareClicked
    | SquareReceived (Result Decode.Error Int)


init : Nav.Key -> { user : String } -> Model
init navKey { user } =
    { field = ""
    , number = 0
    , result = Nothing
    , user = user
    , navKey = navKey
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
                        Just number ->
                            number

                        Nothing ->
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


view : Model -> List (Html Msg)
view model =
    [ Html.p
        []
        [ welcomeText model.user ]
    , Html.p
        []
        [ """
                Type the number you would like to
                square in the field below, click
                "square" and watch the magic happen.
              """
            |> Html.text
        ]
    , Html.input
        [ Events.onInput FieldUpdated
        , Attrs.value model.field
        ]
        []
    , Html.button
        [ Events.onClick SquareClicked ]
        [ Html.text "square" ]
    , squareView model
    ]


squareView : Model -> Html Msg
squareView model =
    case model.result of
        Just ( number, square ) ->
            Html.div
                []
                [ squareText number square ]

        Nothing ->
            Html.text ""


squareText : Int -> Int -> Html Msg
squareText number square =
    [ String.fromInt number
    , "squared is"
    , String.fromInt square ++ "!"
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
