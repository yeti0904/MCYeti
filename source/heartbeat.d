module mcyeti.heartbeat;


import std.datetime;

import std.uri;
import std.stdio;
import std.format;
import std.net.curl;
import std.algorithm;
import core.thread.osthread;
import mcyeti.app;
import mcyeti.util;
import mcyeti.server;

static string oldServerURL;

void HeartbeatTask(Server server) {
	new Thread({
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

		string serverURL;

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
	}).start();
}
