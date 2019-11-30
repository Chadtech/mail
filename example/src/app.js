var app = Elm.Main.init({
    node: document.body
});

function toElm(type, payload) {
	app.ports.fromJs.send({
		type: type,
		payload: payload
	});
}

function login(payload, reply) {
    if (payload.password === "password") {
        reply(payload.username)
    } else {
        reply(null);
    }
}

function square(payload, reply) {
    reply(payload * payload);
}

var actions = {
	square: square,
	login: login
}

app.ports.toJs.subscribe(function(msg){
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

