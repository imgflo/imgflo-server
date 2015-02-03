var hasClassName = function(el, name) {
    return new RegExp("(?:^|\\s+)" + name + "(?:\\s+|$)").test(el.className);
};

var addClassName = function(el, name) {
    if (!hasClassName(el, name)) {
        el.className = el.className ? [el.className, name].join(' ') : name;
    }
};

var removeClassName = function(el, name) {
    if (hasClassName(el, name)) {
        var c = this.className;
        el.className = c.replace(new RegExp("(?:^|\\s+)" + name + "(?:\\s+|$)", "g"), "");
    }
};

/* TODO:
 * - allow to select input image from URL
 * - fix placement of execution button
 *
 * - add thumbnail/preview images to graph selector
 * - add selected/deselected indicator to graph list
 * - add invalidated/working/completed indicator on processed image
 * - add API/authentication status element to header, shows when authed correctly
 * - make images use up available space vertically, centered
 *
 * - use slider for number/integer properties
 * - use color selector for color type properties
 * - use drop-down selector for enum type properties
 *
 * Later:
 * - add progress bar for request processing.
 * - add persisted history, with prev/next buttons in pictureSection
 */

var getDemoData = function(callback) {
    var req=new XMLHttpRequest();
    req.onreadystatechange = function() {
        if (req.readyState === 4) {
            if (req.status === 200) {
                var d = JSON.parse(req.responseText);
                return callback(null, d);
            } else {
                var e = new Error(req.status);
                return callback(e, null);
            }
        }
    }
    req.open("GET", "/demo", true);
    req.send();
}

var getVersionInfo = function(callback) {
    var req=new XMLHttpRequest();
    req.onreadystatechange = function() {
        if (req.readyState === 4) {
            if (req.status === 200) {
                var d = JSON.parse(req.responseText);
                return callback(null, d);
            } else {
                var e = new Error(req.status);
                return callback(e, null);
            }
        }
    }
    req.open("GET", "/version", true);
    req.send();
}

var createGraphProperties = function(container, name, graph) {
    if (typeof graph.inports === 'undefined') {
        return null;
    }

    var inports = Object.keys(graph.inports);
    inports.forEach(function (name) {
        var port = inports[name];
        if (name === "input") {
            return;
        }

        var portInfo = document.createElement('li');
        portInfo.className = 'line';

        var portName = document.createElement('label');
        portName.className = "portLabel";
        var portInput = document.createElement('input');
        portName.innerHTML = "<span>"+name+"</span>";
        portInput.name = name;
        portInput.className = "portInput";

        // TODO: show information about type,value ranges, default value, description etc
        portInfo.appendChild(portName);
        portName.appendChild(portInput);
        container.appendChild(portInfo);
    });

    return container;
}

var createGraphList = function(container, graphs, onClicked) {
    container.onclick = onClicked;

    Object.keys(graphs).forEach(function(name) {
        if (typeof graphs[name].inports !== 'undefined') {
            var e = document.createElement('li');
            e.className = "graphEntry";
            e.innerHTML = name.replace("_", " ");
            e.setAttribute('data-graph-id', name);
            container.appendChild(e);
        }
    });
    return graphs;
}

var createLogEntry = function(url) {
    var img = document.createElement("img");
    img.className = "image";
    img.src = url;

    var req = document.createElement("p");
    req.innerHTML = "GET " + url.replace('&', '\n&')
    req.className = "request";

    var div = document.createElement("div");
    div.className = "logEntry";
    div.appendChild(req);
    div.appendChild(img);
    return div;
}

var createRequestUrl = function(graphname, parameters, apiKey, apiSecret) {
    var hasQuery = Object.keys(parameters).length > 0;
    var search = graphname + (hasQuery ? '?' : '');
    for (var key in parameters) {
        var value = encodeURIComponent(parameters[key]);
        search += key+'='+value+'&';
    }
    if (hasQuery) {
        search = search.substring(0, search.length-1); // strip trailing &
    }

    var url = '/graph/'+search;
    if (apiKey || apiSecret) {
        // FIXME: implement md5 hashing of search
        var base = search+apiSecret;
        var token = CryptoJS.MD5(base);
        url = '/graph/'+apiKey+'/'+token+'/'+search;
    }

    return url;
}

var getGraphProperties = function(container, name, graphdef) {
    var props = {};
    var inputs = container.getElementsByTagName('input');
    for (var i=0; i<inputs.length; i++) {
        var input = inputs[i];
        if (input.value !== '') {
            props[input.name] = input.value;
        }
    }
    return props;
}

var main = function() {

    var id = function(n) {
        return document.getElementById(n);
    }

    var addEntry = function(url) {
        var e = createLogEntry(url);
        id('historySection').insertBefore(e, id('historySection').firstChild);
    }

    var activeGraphName = null;
    var availableGraphs = null;

    var readApiInfo = function() {
        id("apiKey").value = localStorage["imgflo-server-api-key"] || "";
        id("apiSecret").value = localStorage["imgflo-server-api-secret"] || "";
    };
    readApiInfo();

    id('clearApiInfo').onclick = function () {
        localStorage["imgflo-server-api-key"] = "";
        localStorage["imgflo-server-api-secret"] = "";
        readApiInfo();
    };

    id('runButton').onclick = function () {
        var graph = activeGraphName;
        var props = getGraphProperties(id('graphProperties'), graph, availableGraphs[graph]);
        var apiKey = id("apiKey").value;
        var apiSecret = id("apiSecret").value;
        localStorage["imgflo-server-api-key"] = apiKey;
        localStorage["imgflo-server-api-secret"] = apiKey;
        var u = createRequestUrl(graph, props, apiKey, apiSecret);
        addEntry(u);
    };

    var setActiveGraph = function(name) {
        if (typeof availableGraphs[name] === 'undefined') {
            return false;
        }
        activeGraphName = name;
        var container = id('graphProperties');
        var len = container.children.length;
        //container.innerHTML = '';
        for (var i=0; i<len; i++) {
            container.removeChild(container.children[0]);
        }
        createGraphProperties(container, name, availableGraphs[name]);
        return true;
    }

    var onGraphClicked = function(event) {
        var name = event.target.getAttribute('data-graph-id');
        console.log("onGraphClicked", name, event.target);
        setActiveGraph(name);
    }

    getDemoData(function(err, demo) {
        if (err) {
            throw err;
        }

        availableGraphs = demo.graphs;
        setActiveGraph(Object.keys(availableGraphs)[0]);

        createGraphList(id('graphList'), demo.graphs, onGraphClicked);
        var images = [
            "demo/grid-toastybob.jpg"
        ];
        images.forEach(function(image) {
            addEntry(image);
        });
    });

    getVersionInfo(function(err, res) {
        var version = "Unknown";
        if (!err && res.server) {
            version = res.server.toString();
        }
        id('version').innerHTML = 'imgflo-server: ' + version;
    });

}
window.onload = main;
