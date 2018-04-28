module.exports = function(app, model) {
    app.ports.toJs.subscribe(function(msg) {
        var sub = model[msg.address];
        if (typeof sub === "undefined") {
            console.log("Sub doesnt exist");
            return;
        }
        sub(msg.payload, function(response){
            app.ports.fromJs.send({
                thread: msg.thread,
                payload: response
            });
        });
    });
};