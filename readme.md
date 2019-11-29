# Mail

This package provides an api for Elm ports that behaves similarly to http requests. In the same code where you send a message from Elm to JS, you can write the code for how you expect the response to come in as.

To get started, just skip down to the "How do I use this?" section.

## Background
In Elm, JS interop is done through ports, and its a well known aspect of ports that they are "one way" or "fire and forget"; meaning, a message sent from Elm to JavaScript (or vice versa) is simply sent off with no awareness of how it was received and no expectation of a response. 

The trouble some people find is that their use case does in fact expect a response. For example, they want their Elm application reach out into JavaScript to get the api token from their third party authentication SDK (like Firebase, or Amazon Cognito). They expect a response in the form of the api token when they request it.

The correct way of writing this code in Elm  feels like they needing to write twice as much code. One can't just code one channel of communication for their request; one has to write code for the to-js channel and code for the from-js channel, for every communication they would like to make.

This package makes those ports communications feel "one channel" again. You write the request, and how you expect the response in one spot of your Elm code.

## Is it good idea to use this?
I dont know, probably not. You don't need this package to streamline Elm ports. This was made mostly for fun and as a demonstration.

Also, coding in an expectation of a response creates new problems. For example, theres now state inside `Browser.Mail` that remembers which requests were made and what response they expect. If a request is made with the expectation of a response and that response never comes in, then that state hangs around forever. More requests are made, some of them never complete, so now you have a memory leak in your code. That state will just balloon bigger and bigger over time and eventually consume the entire universe. Thanks.

Maybe you wont have this problem. Its very plausible that you could write flawless code where every request gets a response or at least gets pruned if it takes too long.

## How to use this module

Definitely look at the example project, first of all; it is under `example/` in the github repo.

What you will need in your Elm code are these exact two ports..
```elm
port fromJs : (Decode.Value -> msg) -> Sub msg

port toJs : Encode.Value -> Cmd msg
```
..then give them to your main `Program`..
```elm
main : Mail.Program Decode.Value Model Msg
main =
    Mail.document
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , toJs = toJs
        , fromJs = fromJs
        }
```
..and finally, in your JS code, you need something like this code snippet below; where `app` is your Elm application, and  `actions` is an object with values that are functions of type ..
```js
function square(payload, callbackToElm) {
    callbackToElm(payload * payload);
}

var actions = {
    square: square,
}

app.ports.toJs.subscribe(function(msg){
    // msg : { address : String, thread : Int, payload: json }
    var action = actions[msg.address];
    if (typeof action === "undefined") {
    	console.log("Unrecognized js msg type ->", msg.type);
        return;
    }
    action(msg.payload, function(payload) {
        app.ports.fromJs.send({
            thread: msg.thread,
            payload: payload
        });
    });
})
```
