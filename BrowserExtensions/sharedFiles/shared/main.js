
const DELAY_TIMEOUT = 500; // milleseconds
const RECONNECT_NATIVE_TIMEOUT = 10000; //milleseconds

var nativePort = null;
var timeoutObject = null;
var previousTab = null;
var previousTabOnNewWindow = null;
var wasActivated = false;


var callbackTargets = {};
var targetsCounter = 0;
function idForTarget(target){
    targetsCounter = targetsCounter == Number.MAX_SAFE_INTEGER ? 0 : targetsCounter++;
    var id = targetsCounter.toString();
    callbackTargets[id] = target;
    return id;
}

var _clean = function() {
    if (nativePort) {
        nativePort.disconnect();
    }
    nativePort = null;
    targetsCounter = 0;
    callbackTargets = {};

    if (timeoutObject) {
        clearTimeout(timeoutObject);
    }
    timeoutObject = null;
}

var logError = function(ex) {
    if (typeof console !== 'undefined' && console.error) {
        BSError('Error in BeardedSpice Control script');
        BSError(ex);
    }
};

function reconnectToNative(event) {
    BSLog("(Beardie Control) Attempt to reconnecting.");

    _clean();
    connectToNative();
};


function connectToNative() {
    if (typeof chrome !== "undefined" && chrome && chrome.storage) {
        //CHROME
        if (BSConstants) {
            nativePort = chrome.runtime.connectNative(BSConstants.BS_B_NATIVE_MESSAGING_CONNECTOR_BUNDLE_ID);
            nativePort.onMessage.addListener(respondToNativeMessage);
            nativePort.onDisconnect.addListener(function() {
                BSLog('(Beardie Control) onSocketDisconnet');
                _clean();
                timeoutObject = setTimeout(reconnectToNative, RECONNECT_NATIVE_TIMEOUT);
            });
        }
    }
}

function respondToNativeMessage(msg){
    BSLog('(Beardie Control) received from native: %o', msg);
    var targetId = msg["id"];
    if (targetId.length > 0) {
        var target = callbackTargets[targetId];
        if (target) {
            switch (msg["msg"]) {
                case "bundleId":
                    BSUtils.sendMessageToTab(target, "bundleId", { 'result': msg["body"]});
                    break;
            
                case "logLevel":
                    let body =  msg["body"];
                    BSUtils.setLogLevel(body.debug);
                    BSUtils.sendMessageToTab(target, "logLevel", { 'result': body});
                    break;
                    case "accepters":
                    BSUtils.sendMessageToTab(target, "accepters", msg["body"]);
                    break;
                case "port":
                    BSUtils.sendMessageToTab(target, "port", { 'result': msg["body"]});
                    break;
                case "serverIsAlive":
                    BSUtils.sendMessageToTab(target, "serverIsAlive", { 'result': msg["body"] });
                    break;
                default:
                    break;
            }
            delete callbackTargets[targetId];
        }
    } 
}

function respondToMessage(theMessageEvent) {
    var activated = function(callback) {
        BSUtils.frontmostTab(theMessageEvent.target, val => {
            callback(wasActivated && val);
        });
    };
    if (BSUtils.checkThatTabIsReal(theMessageEvent.target)) {
        BSLog('(Beardie Control) respondToMessage event: ' + theMessageEvent.name + ' target: ' + theMessageEvent.target.title);
        try {

            switch (theMessageEvent.name) {
                // request log level
                case "logLevel":
                    nativePort.postMessage({ 'msg': 'logLevel', 'id': idForTarget(theMessageEvent.target) });
                    break;
                //request accepters
                case "accepters":
                    nativePort.postMessage({ 'msg': 'accepters', 'id': idForTarget(theMessageEvent.target) });
                    break;
                case "port":
                    // request port
                    nativePort.postMessage({ 'msg': 'port', 'id': idForTarget(theMessageEvent.target) });
                    break;
                case "frontmost":
                    BSUtils.frontmostTab(theMessageEvent.target, val => {
                        BSUtils.sendMessageToTab(theMessageEvent.target, "frontmost", { 'result': val });
                    });
                    break;
                case "isActivated":
                    activated(val => {
                        BSUtils.sendMessageToTab(theMessageEvent.target, "isActivated", { 'result': val });
                    });
                    break;
                case "bundleId":
                    nativePort.postMessage({ 'msg': 'bundleId', 'id': idForTarget(theMessageEvent.target) });
                    break;
                case "serverIsAlive":
                    nativePort.postMessage({ 'msg': 'serverIsAlive', 'id': idForTarget(theMessageEvent.target) });
                    break;
                case "activate":
                    BSUtils.getActiveTab(tab => {
                        previousTab = tab;
                        BSUtils.getActiveTab(tab => {
                            previousTabOnNewWindow = tab;
                            if (!previousTabOnNewWindow || previousTab === previousTabOnNewWindow) {
                                previousTabOnNewWindow = null;
                            }
                            BSUtils.setActiveTab(theMessageEvent.target, true, () => {
                                wasActivated = true;
                                BSUtils.sendMessageToTab(theMessageEvent.target, "activate", { 'result': true });
                            });
                        }, theMessageEvent.target);
                    });
                    break;
                case "hide":
                    activated(val => {
                        if (val) {
                            if (previousTabOnNewWindow) {
                                BSUtils.setActiveTab(previousTabOnNewWindow, false);
                            }
                            if (previousTab) {
                                BSUtils.setActiveTab(previousTab, true);
                            }
                        }
                        previousTab = null;
                        wasActivated = false;
                        BSUtils.sendMessageToTab(theMessageEvent.target, "hide", { 'result': true });
                    });
                    break;

                default:

            }
        } catch (ex) {
            logError(ex);
            socket.close();
        }
    }
}

// Add listeners

BSUtils.handleMessageFromTabs(respondToMessage);

// Start connection to Beardie app
connectToNative();
