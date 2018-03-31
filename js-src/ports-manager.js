function handleMsg(app, model, msg) {
    var sub = model.subscriptions[msg.type];
    if (typeof sub === "undefined") {
        app.ports[model.fromJsPort].send({
            subDoesNotExist: msg.id
        });
        return;
    }
    sub(msg.paylaod, function(response){
        app.ports[model.fromJsPort].send({
            id: msg.id,
            payload: response
        });
    });
}

function subscribe(app, model) {
    return function(msg) {
        handleMsg(app, model, msg);
    };
}

module.exports = function(app, model) {
    app.ports[model.toJsPort].subscribe(app, model);
};
