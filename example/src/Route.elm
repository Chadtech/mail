module Route exposing
    ( Route(..)
    , fromUrl
    , goTo
    )

import Browser.Mail as Mail exposing (Mail)
import Browser.Navigation as Nav
import Url
import Url.Parser as Parser exposing (Parser)



-- TYPES --


type Route
    = Login
    | Home



-- HELPERS --


parser : Parser (Route -> a) a
parser =
    Parser.oneOf
        [ Parser.map Home Parser.top
        , Parser.map Login (Parser.s "login")
        ]


fromUrl : Url.Url -> Maybe Route
fromUrl =
    Parser.parse parser


toUrlString : Route -> String
toUrlString route =
    case route of
        Login ->
            "login"

        Home ->
            "home"


goTo : Nav.Key -> Route -> Mail msg
goTo navKey route =
    Nav.pushUrl navKey (toUrlString route)
        |> Mail.cmd
