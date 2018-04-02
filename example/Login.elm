module Login
    exposing
        ( Model
        , Msg
        , init
        , update
        , view
        )

-- TYPES --


type alias Model =
    { username : String
    , password : String
    }


type Msg
    = FieldUpdated Field String
    | SubmitClicked
    | LoginFinished (Result String String)


type Field
    = Username
    | Password



-- INIT --


init : Model
init =
    { username = ""
    , password = ""
    }



-- UPDATE --


update : Msg -> Model -> ( Model, Maybe (Request a Msg), Reply )
update msg model =
    case msg of
        FieldUpdated Username str ->
            ( { model | username = str }
            , Nothing
            , NoReply
            )

        FieldUpdated Password str ->
            ( { model | password = str }
            , Nothing
            , NoReply
            )

        SubmitClicked ->
            ( model
            , Just <| submitRequest model
            , NoReply
            )


submitRequest : Model -> Request String Msg
submitRequest model =
    Ports.Manager.request
        Decode.string
        LoginFinished
        (loginMsg model)


loginMsg : Model -> ( String, Encode.Value )
loginMsg model =
    ( "login"
    , [ ( "username", Encode.string model.username )
      , ( "password", Encode.string model.password )
      ]
        |> Encode.object
    )
