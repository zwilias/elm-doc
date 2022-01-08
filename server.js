#!/usr/bin/env node

var http = require("http"),
    url = require("url"),
    fs = require("fs"),
    path = require("path"),
    os = require("os"),
    opn = require("opn"),
    minimist = require("minimist");

var args = minimist(process.argv.slice(2), {
    boolean: ["help", "closed"],
    default: { port: 4040 }
});

if (args.help) {
    console.log("Usage:");
    console.log("");
    console.log(
        "  elm-doc              Listen on port 4040 and open a browser"
    );
    console.log(
        "  elm-doc --port=4343  To listen on port 4343 and open a browser"
    );
    console.log("  elm-doc --closed     Prevent the browser from being opened");
    process.exit(0);
}

http
    .createServer(function(request, response) {
        var requestPath = url.parse(request.url).pathname;

        if (requestPath.startsWith("/~docs/")) {
            serveDocs(requestPath, response);
        } else if (requestPath == "/elm.js") {
            serveElm(response);
        } else if (requestPath == "/style.css") {
            serveStyle(response);
        } else {
            serveIndex(response);
        }
    })
    .listen(args.port)
    .on("listening", function() {
        console.log("Listening on port", args.port);
        if (!args["closed"]) {
            var url = "http://localhost:" + args.port;
            opn(url);
        }
    })
    .on("error", handleError);

function handleError(error) {
    if (error.code == "EADDRINUSE") {
        console.error(
            "That port is already in use. Please choose a different port using `--port`"
        );
        process.exit(1);
    }
}

function serveDocs(requestPath, response) {
    var parts = requestPath.split("/");
    if (parts.length != 6) {
        console.error("Invalid number of segments", parts);
        response.statusCode = 404;
        response.end("Resource not found");
        return;
    }

    var pkgAuthor = parts[2];
    var pkgName = parts[3];
    var version = parts[4];
    var file = parts[5];

    var resource = path.join(pkgsHome(), pkgAuthor, pkgName, version, file);

    fs.readFile(resource, function(err, data) {
        if (err) {
            console.error(err);
            response.statusCode = 404;
            response.end("Resource not found");
            return;
        }

        if (file.endsWith(".json")) {
            response.setHeader("content-type", "application/json");
        } else {
            response.setHeader("content-type", "text/plain");
        }

        response.end(data);
    });
}

function elmHome() {
    if (process.env.ELM_HOME) {
        return path.join(process.env.ELM_HOME);
    } else {
        return path.join(os.homedir(), ".elm");
    }
}

function pkgsHome() {
    return path.join(elmHome(), "0.19.1", "packages");
}

function serveIndex(response) {
    response.setHeader("content-type", "text/html");
    response.end(indexHtml());
}

function serveStyle(response) {
    response.setHeader("content-type", "text/css");
    var cssPath = path.join(__dirname, "style.css");
    var cssData = fs.readFileSync(cssPath);

    response.end(cssData);
}

function serveElm(response) {
    response.setHeader("content-type", "text/javascript");
    var elmJSPath = path.join(__dirname, "elm.js");
    var elmJSData = fs.readFileSync(elmJSPath);

    response.end(elmJSData);
}

function indexHtml() {
    var compactData = JSON.stringify(elmJson(), null, 0);

    return `<html>
<head><link rel="stylesheet" href="/style.css"></head>
<body>
  <script src="/elm.js"></script>
  <script>Elm.Main.init({flags: ${compactData}});</script>
</body>
</html>`;
}

function elmJson() {
    var json = fs.readFileSync("elm.json");
    return JSON.parse(json);
}
