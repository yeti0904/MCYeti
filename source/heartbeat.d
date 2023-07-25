module mcyeti.heartbeat;

import std.uri;
import std.stdio;
import std.format;
import std.net.curl;
import std.datetime;
import std.algorithm;
import std.functional;
import mcyeti.app;
import mcyeti.util;
import mcyeti.server;

const uint hearbeatIntervalMillis = 35000;
private static Server server;

void SendHeartbeat() {
    string url = format(
        "%s?name=%s&port=%d&users=%d&max=%d&salt=%s&public=%s&software=%s",
        server.config.heartbeatURL,
        encodeComponent(server.config.name),
        server.config.port,
        server.GetConnectedIPs(),
        server.config.maxPlayers,
        server.salt,
        server.config.publicServer? "true" : "false",
        encodeComponent(appVersion)
    );

    string        serverURL;
    static string oldServerURL;

    try {
        serverURL = cast(string) get(url);
    }
    catch (CurlException e) {
        Log("A CurlException occurred: %s", e.msg);
        return;
    }

    if (!serverURL.startsWith("http")) {
        Log("Heartbeat error: %s", serverURL);
        return;
    }

    if (serverURL != oldServerURL) {
        Log("Server URL: %s", serverURL);

        oldServerURL = serverURL;
    }
}

void HeartbeatTask(Server server_) {
    server = server_;
    RunningLoop(server, hearbeatIntervalMillis, toDelegate(&SendHeartbeat));
}
