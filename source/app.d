module mcyeti.app;

import std.file;
import std.path;
import std.stdio;
import std.format;
import core.thread;
import mcyeti.blockdb;
import mcyeti.server;

void main() {
	string[] folders = [
		"worlds",
		"players",
		"properties",
		"blockdb",
		"backups"
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

	// create blockDBs for worlds that don't have one
	string worldsFolder = dirName(thisExePath()) ~ "/worlds/";
	
	foreach (entry ; dirEntries(worldsFolder, SpanMode.shallow)) {
		if (entry.name.extension() == ".ylv") {
			string name = baseName(entry.name).stripExtension();
			string dbPath = format("%s/blockdb/%s.db", dirName(thisExePath()), name);

			if (!exists(dbPath)) {
				BlockDB.CreateBlockDB(name);
			}
		}
	}

	Server server = new Server();

	server.Init();

	while (server.running) {
		server.Update();

		Thread.sleep(dur!"msecs"(1000 / 50));
	}
}
