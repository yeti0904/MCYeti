module mcyeti.heartbeat;

import std.uri;
import std.format;
import std.net.curl;
import std.algorithm;
import mcyeti.app;
import mcyeti.util;
import mcyeti.server;

void HeartbeatTask(Server server) {
	string url = format(
	    "%s?name=%s&port=%d&users=%d&max=%d&salt=%s&public=%s&software=%s",
	    server.config.heartbeatURL,
	    encodeComponent(server.config.name),
	    server.config.port,
	    server.GetConnectedIPs(),
	    server.config.maxPlayers,
	    server.salt,
	    server.config.publicServer? "true" : "false",
	    appVersion
	);

	static string oldServerURL;
	string        serverURL;

	try {
		serverURL = cast(string) get(url);
	}
	catch (CurlException e) {
		Log("Error in heartbeat: %s", e.msg);
	}

	if (serverURL != oldServerURL) {
		Log("Server URL: %s", serverURL);
	}

	if (!serverURL.startsWith("http")) {
		Log("Heartbeat error: %s", serverURL);
	}

	oldServerURL = serverURL;
}
