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
 * - make input picking a dialog "paste URL here"
 * - hide output URL, use "copy image link" instead
 * - move execute button down, change to spinner when processing (font-awesome?)
 * - move graph details to below the graph selector
 *
 * - Don't show auth input fields all the time.
 * If authed, checkmark OK. Not authed, allow to drop down to enter.
 * - Allow to register new API keys "apps"
 * - Allow to copy API keys/secret pair out.
 * - Link out to API docs
 *
 * - add selected/deselected indicator to graph list
 * - add invalidated/working/completed indicator on processed image
 * - add API/authentication status element to header, shows when authed correctly
 * -
 * - make images use up available space vertically, centered
 *
 * - use slider for number/integer properties (min, max, default)
 * - use color selector for color type properties
 * - use drop-down selector for enum type properties
 * - use checkbox for boolean
 *
 * Maybe
 * - make HEAD request to check if image is cached,
 * and then show without pressing execute?
 *
 * Later:
 *
 * - Allow sharing an URL to UI, with all image parameters included.
 * Have a standard convention?
 * - Allow to input a processing URL, get the input image+params out
 *
 * - allow to upload image
 * - allow to take picture with webcam
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
    req.open("GET", "/graphs", true);
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

var createGraphProperties = function(container, name, graph, values) {
    if (typeof graph.inports === 'undefined') {
        return null;
    }

    var inports = Object.keys(graph.inports);
    inports.forEach(function (name) {
        var port = inports[name];
        var value = values[name];
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
        if (typeof(value) !== 'undefined') {
            portInput.value = value
        }

        // TODO: show information about type,value ranges, default value, description etc
        portInfo.appendChild(portName);
        portName.appendChild(portInput);
        container.appendChild(portInfo);
    });

    return container;
}

var createGraphList = function(container, graphs, onClicked) {

    Object.keys(graphs).forEach(function(name) {
        if (typeof graphs[name].inports !== 'undefined') {
            var graph = graphs[name];
            var e = document.createElement('li');
            e.onclick = onClicked;
            var displayName = name.replace("_", " ");
            e.className = "graphEntry";
            var p = document.createElement('label');
            p.innerHTML = displayName;
            e.appendChild(p);
            var img = document.createElement('img');
            img.src = graph.thumbnailUrl;
            e.appendChild(img);
            e.setAttribute('data-graph-id', name);
            container.appendChild(e);
        }
    });
    return container;
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

var parseQuery = function(qstr) {
    var query = {};
    var a = qstr.substr(1).split('&');
    for (var i = 0; i < a.length; i++) {
        var b = a[i].split('=');
        query[decodeURIComponent(b[0])] = decodeURIComponent(b[1] || '');
    }
    return query;
}

var startsWith = function(str, sub) {
    return str.indexOf(sub) === 0;
}

var main = function() {

    var id = function(n) {
        return document.getElementById(n);
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

    var processCurrent = function() {
        var graph = activeGraphName;
        var props = getGraphProperties(id('graphProperties'), graph, availableGraphs[graph]);
        props.input = id('inputUrl').value;
        var apiKey = id("apiKey").value;
        var apiSecret = id("apiSecret").value;
        localStorage["imgflo-server-api-key"] = apiKey;
        localStorage["imgflo-server-api-secret"] = apiSecret;
        var url = createRequestUrl(graph, props, apiKey, apiSecret);
        var bg = 'url("'+url+'")';
        console.log('processing:', url, bg);
        /*
        id('processedImage').onload = function() {
            id('processedImage').className = "visible";
        };
        id('processedImage').src = u;
        */
        id('processedUrl').value = url;
        id('processedImage').style.backgroundImage = bg;
    }
    id('runButton').onclick = processCurrent;

    var setInputUrl = function(url) {
        console.log('setting input', url);
        if (!startsWith(url, 'http')) {
            // Resolve to fully qualified URL
            var loc = window.location;
            url = loc.protocol + '//' + loc.host + '/' + url;
        }
        if (id('inputUrl').value !== url) {
            id('inputUrl').value = url;
        }
        var bg = 'url("'+url+'")';
        id('originalImage').style.backgroundImage = bg;
    }

    var onInputChanged = function(event) {
        var url = id('inputUrl').value;
        setInputUrl(url);
    }
    id('inputUrl').onblur = onInputChanged;
    onInputChanged();

    var setActiveGraph = function(name, properties) {
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
        createGraphProperties(container, name, availableGraphs[name], properties);
        return true;
    }

    var onGraphClicked = function(event) {
        var name = event.currentTarget.getAttribute('data-graph-id');
        console.log("onGraphClicked", name);
        setActiveGraph(name, {});
    }

    getDemoData(function(err, demo) {
        if (err) {
            throw err;
        }

        availableGraphs = demo.graphs;

        Object.keys(availableGraphs).forEach(function(name) {
            var graph = availableGraphs[name];
            var props = { width: 150, input: id('inputUrl').value };
            var apiKey = id("apiKey").value;
            var apiSecret = id("apiSecret").value;
            localStorage["imgflo-server-api-key"] = apiKey;
            localStorage["imgflo-server-api-secret"] = apiSecret;
            graph.thumbnailUrl = createRequestUrl(name, props, apiKey, apiSecret);
        });

        if (startsWith(window.location.pathname, '/debug')) {
            // Set the UI widgets state based on what is in the URL
            var params = parseQuery(window.location.search);
            var parts = window.location.pathname.split('/');
            var graph = parts[3];
            if (parts.length >= 6) {
                graph = parts[5];
            }
            setInputUrl(params.input);
            setActiveGraph(graph, params);
        } else {
            setActiveGraph('desaturate', {});
        }

        processCurrent();
        createGraphList(id('graphList'), demo.graphs, onGraphClicked);
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
