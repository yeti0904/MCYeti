module mcyeti.app;

import std.file;
import std.path;
import std.stdio;
import core.thread;
import mcyeti.server;

void main() {
	string[] folders = [
		"worlds",
		"players",
		"properties"
	];
	string[] files = [
		"banned_ips.txt"
	];

	foreach (ref folder ; folders) {
		if (!exists(folder)) {
			mkdir(dirName(thisExePath()) ~ '/' ~ folder);
		}
	}

	foreach (ref file ; files) {
		if (!exists(file)) {
			std.file.write(dirName(thisExePath()) ~ '/' ~ file, "");
		}
	}

	Server server = new Server();

	server.Init();

	while (server.running) {
		server.Update();

		Thread.sleep(dur!"msecs"(1000 / 50));
	}
}
