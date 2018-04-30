# Mail

Heres a common story: you are working on an Elm project, but you really need some value thats only obtainable from the JavaScript side of things. Im talking about values from..
- The api client you use to make http requests, maybe to firebase or aws, or your old in-house api client written in JavaScript.
- That one weird JavaScript package that is super useful and stable but also hard to port into Elm given your project constraints.
- The application your Elm code is embedded into.

The answer to all these problems is ports. Your Elm app should send a message out to the JS-side of things through a port, telling the JavaScript to do such-and-such behavior, 
whereafter the JavaScript sends the resulting value back into Elm through another port.

My estimation is that about 75% of the time people use ports in Elm projects, they are doing so in a request-response kind of way: they are requesting a value, and they are waiting for a value in response. The problem is Elm ports arent really built in a request-response kind of way. Outgoing and incoming ports are completely de-coupled without any assumption of a value coming back. Since Elm developers often need response values, they are often deliberately coupling outgoing and incoming ports manually. Here is a step by step of what code you would have to write to build a complete circuit from Elm to JS and back:

1. Build an outgoing port for your request that routes your outgoing value to the right JavaScript function
2. Write the code that builds a payload and passes it through that outgoing port
3. Listen for the outgoing port on the JS side of your app, consume the payload, and return the value
4. Build the incoimng port that routes your incoming value to the right place

To add a single port you are necessarily touching four parts of your code base, merely to add really tedious lines of code like `"incomingMsg" -> IncomingMsg`. This doesnt scale very well.

`Chadtech/mail` eliminates steps 1 and 4 in that process. `Mail` treats Elm ports like http requests and handles all the routing internally. Heres how the code in practice looks

```elm
-- Login.elm
import Ports.Mail as Mail exposing (Mail)


mailLogin : Model -> Mail Msg
mailLogin model =
    [ ( "username", Encode.string model.username )
    , ( "password", Encode.string model.password )
    ]
        |> Encode.object
        |> Mail.letter "login"
        |> Mail.expectResponse loginDecoder LoginResult
        |> Mail.send

    -- ..

    SubmitClicked ->
        ( model, mailLogin model )

    LoginResult (Ok login) ->
        -- ..
```
```js
// app.js
var PortsMail = require("ports-mail");
var app = Elm.Main.fullscreen();

PortsMail(app, { login: apiClient.login });
```

In the code above `Mail.letter "login" json` says mail this json to the address `"login"`. `Mail.expectResponse` says we expect json in reply in the shape of `loginDecoder`, and we want it routed to come in via the `Msg` `LoginResult`. The entire specification of what is going on is handled in these few lines of code with no ports or subscriptions.

On the JavaScript side of things `PortsMail` initializes the elm app. The address is really just the key in a javascript object. The value of that key is a function, whos first argument is the payload from Elm, and whos second argument is the call back to send the value back into Elm. Something like..

```js
PortsMail(app, { 
    getCurrentTime: function(payload, reply){
        reply(new Date().getTime());
    }
});
```

# Getting Started

Please study the code in the example folder so you know what you are in for. To install everything, type..

```
elm package install Chadtech/mail --yes
npm install chadtech-mail --save
```

Then, in your main Elm file, copy and paste in these ports..

```elm
port fromJs : (Value -> msg) -> Sub msg


port toJs : Value -> Cmd msg
```

..make sure your main module is a ports module..

```elm
port module Main exposing (..)
```

..And finally import and initialize a `Mail.program`..

```elm
import Ports.Mail as Mail exposing (Mail)

main : Mail.Program Never Model Msg
main =
    { init = init
    , update = update
    , view = view
    , subscriptions = always Sub.none
    , toJs = toJs
    , fromJs = fromJs
    }
        |> Mail.program
```

Please note, `Mail.Program` update and init functions dont return `(Model, Cmd Msg)`, they return `(Model, Mail Msg)` instead. Dont worry, you can still use `Cmd`s, just do `Mail.cmd yourCmd`, which is `Mail.cmd : Cmd Msg -> Mail Msg`.

Finally, in your javascript, initialize your app like this

```js
var PortsMail = require("chadtech-mail");
var app = Elm.Main.fullscreen();

function address0(payload, reply){
    // ..
    reply(valueForElm);
}

function address1(payload, reply){
    // ..
    reply(4);
}

PortsMail(app, { 
    address0,
    address1
});
```


