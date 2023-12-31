module mcyeti.app;

import std.file;
import std.path;
import std.stdio;
import std.format;
import mcyeti.util;
import mcyeti.server;
import mcyeti.blockdb;

const uint tps          = 20;
const uint tickInterval = 1000 / tps;

const string   appVersion    = "MCYeti Pre-release";
const string[] appDevelopers = [
	"MESYETI",
	"deewend"
];

void main() {
	string[] folders = [
		"worlds",
		"players",
		"properties",
		"blockdb",
		"backups",
		"text",
		"logs"
	];
	string[] files = [
		"banned_ips.txt",
		"text/rules.txt"
	];

	foreach (ref folder ; folders) {
		if (!exists(folder)) {
			mkdir(dirName(thisExePath()) ~ '/' ~ folder);
		}
	}

	foreach (ref file ; files) {
		if (!exists(file)) {
			string path     = dirName(thisExePath()) ~ '/' ~ file;
			string contents = "";

			if (file == "text/rules.txt") {
				contents = "No rules entered yet";
			}
			
			std.file.write(path, contents);
		}
	}

	// create blockDBs, backup folders and properties files for worlds that
	// don't have one
	string worldsFolder = dirName(thisExePath()) ~ "/worlds/";
	
	foreach (entry ; dirEntries(worldsFolder, SpanMode.shallow)) {
		if (entry.name.extension() == ".ylv") {
			string name = baseName(entry.name).stripExtension();
			string dbPath = format(
				"%s/blockdb/%s.db", dirName(thisExePath()), name
			);

			if (!exists(dbPath)) {
				BlockDB.CreateBlockDB(name);
			}

			string properties = entry.name.stripExtension() ~ ".json";
			string defaultProperties = "
				{
					\"motd\": \"ignore\"
				}
			";

			if (!exists(properties)) {
				std.file.write(properties, defaultProperties);
			}
		}
	}

	Server server = new Server();

	server.Init();

	RunningLoop(server, tickInterval, &server.Update);
}
