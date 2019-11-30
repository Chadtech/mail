(function(){function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s}return e})()({1:[function(require,module,exports){
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


},{}]},{},[1]);
