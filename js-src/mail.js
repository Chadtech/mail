module.exports = function(app, model) {
    app.ports.toJs.subscribe(function(msg) {
        var sub = model[msg.address];
        switch (typeof sub) {
            case "undefined":
                console.log("Address " + msg.address + " doesnt exist");
                return;
            case "function":
                sub(msg.payload, function(response){
                    app.ports.fromJs.send({
                        thread: msg.thread,
                        payload: response
                    });
                });
                break;

            default:
                console.log("Address " + msg.address + " is not a function.");
        }
    });
};