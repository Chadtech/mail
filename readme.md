# Mail

Heres a common story: you are working on an Elm project, but you really need some value thats only obtainable from the JavaScript side of things. Im talking about values from..
- The api client you use to make http requests, maybe to firebase or aws, or your old in-house api client written in JavaScript.
- That one weird JavaScript package that is super useful and stable but also hard to port into Elm given your project constraints.
- The application your Elm code is embedded into.

The answer to all these problems is ports. Your Elm app should send a message out to the JS-side of things through a port, telling the JavaScript to do such-and-such behavior, 
whereafter the JavaScript sends the resulting value back into Elm through another port.

My estimation is that about 75% of the time people use ports in Elm projects, they are doing so in a request-response kind of way: they are requesting a value, and they are waiting for a value in response. The problem is Elm ports arent really built in a request-response kind of way. Outgoing and incoming ports are completely de-coupled without any assumption of a value coming back. Since Elm developers often need response values, they are often deliberately coupling outgoing and incoming ports manually. Here is kind of what that looks like..


```elm
-- Ports.elm
ports login : Encode.Value -> Cmd msg

tryLoggingIn : String -> String -> Cmd msg
tryLoggingIn username password =
    [ ("username", Encode.string username)
    , ("password", Encode.string password)
    ]
        |> Encode.object
        |> login

-- Login.elm

    SubmitClicked ->
        ( model
        , Ports.tryLoggingIn model.username model.password
        )
```
```js
// app.js
var app = Elm.Main.fullscreen();

app.ports.login.subscribe(function(payload) {
    apiClient.login(payload, function(result) {
        app.ports.loginResult.send(result);
    })
})
```
```elm
-- Main.elm
ports loginResult : (Value -> msg) -> Sub msg

subscriptions : Model -> Sub Msg
subscriptions model =
    [ loginResult Login.LoginResult
        |> Sub.map LoginMsg
    -- ..
    ]
        |> Sub.batch
```

A lot of that is just routing and directing values to the right places. Furthermore, adding even one request-response touches a lot of parts of your code: subscriptions, your ports, your javascript, and the module that needs the value from JavaScript. `Chadtech/Mail` streamlines this tedious work. `Mail` treats Elm ports like http requests and handles all the routing you would have to write to connect your Elm stuff with your JS stuff. Heres that same functionality written with Mail.

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
```
```js
// app.js
var PortsMail = require("ports-mail");
var app = Elm.Main.fullscreen();

PortsMail(app, { login: apiClient.login });
```

In Mail, you dont really have to routing anything, and all the business logic is compressed into the point from which you make the request. In the following snippet, the code is saying "Send this json to the addess 'login', and expect the response to look like this `Decoder a`, and route it to this `Msg`".
```elm
    json
        |> Mail.letter "login"
        |> Mail.expectResponse loginDecoder LoginResult
```
And so long as that address (`"login"`) exists on the JS side of things, and the Javascript invokes the callback provided by `PortsMail`, things will work. You dont need to add a subscription, or build another outgoing port, and all the relevant code for sending an out going message and getting a response can be packaged into one snippet of code in one module.
