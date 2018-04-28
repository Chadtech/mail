var PortsManager = require("ports-manager");

var app = Elm.Main.fullscreen();

function square(payload, reply) {
    reply(payload * payload);
}

function login(payload, reply) {
    console.log("WHAT?", payload);
    if (payload.password === "password") {
        reply(payload.username);
    } else {
        reply(null);
    }
}

PortsManager(app, {
    config: {
        toJsPort: "toJs",
        fromJsPort: "fromJs"
    },
    subscriptions: {
        square: square,
        login: login
    }
});

