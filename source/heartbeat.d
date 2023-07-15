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

const uint hearbeatIntervalMillis = 30000;
static Server server;

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
        auto response = byLineAsync(url);
        if (response.wait(dur!"seconds"(15))) {
            serverURL = cast(string) response.front;
        }
        else {
            throw new Exception("Timed out");
        }
    }
    catch (Exception e) {
        Log("Failed to receive response from the heartbeat server: %s", e.msg);
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
