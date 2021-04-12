var BSEventClient = {
    noEventsController: (document.querySelector("script.x_Beardie_InjectScript") == null),
    sendRequest: function(data, callback) {
        
        if (BSEventClient.noEventsController) {
            if (callback) {
                callback({result: false});
            }
        }

        var request = document.createTextNode("");

        request.addEventListener("BSEventClient-response", function(event) {

            request.parentNode.removeChild(request);

            if (callback) {
                callback(event.detail);
            }
        }, false);

        (document.head || document.documentElement).appendChild(request);

        var event = new CustomEvent("BSEventClient-query", {
            detail: data,
            "bubbles": true,
            "cancelable": false
        });

        request.dispatchEvent(event);
    },

    //callback function example
    callback: function(response) {

        // return alert("response: " + (response ? response.toSource() : response));
    }
}
