module mcyeti.commands.moderation;

import std.conv;
import std.file;
import std.json;
import std.path;
import std.array;
import std.format;
import std.string;
import std.algorithm;
import core.stdc.stdlib;
import mcyeti.types;
import mcyeti.world;
import mcyeti.client;
import mcyeti.server;
import mcyeti.commandManager;

class ShutdownCommand : Command {
	this() {
		name = "shutdown";
		help = [
			"&a/shutdown",
			"&eSaves all levels and then shuts down"
		];
		argumentsRequired = 0;
		permission        = 0xF0;
		category          = CommandCategory.Moderation;
	}

	override void Run(Server server, Client client, string[] args) {
		server.SaveAll();
		
		foreach (ref clienti ; server.clients) {
			server.Kick(clienti, "Server shutdown");
		}
		
		exit(0);
	}
}

class BanCommand : Command {
	this() {
		name = "ban";
		help = [
			"&a/ban [username]",
			"&eBans the given player"
		];
		argumentsRequired = 1;
		permission        = 0xD0;
		category          = CommandCategory.Moderation;
	}

	override void Run(Server server, Client client, string[] args) {
		// todo no longer needed?
		if (args.length == 0) {
			client.SendMessage("&cUsername parameter required");
			return;
		}

		auto username = args[0];

		JSONValue info;

		try {
			info = server.GetPlayerInfo(username);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", username));
			return;
		}

		info["banned"] = true;

		server.SavePlayerInfo(username, info);

		try {
			server.Kick(username, "You're banned");
		}
		catch (ServerException) {
			
		}

		client.SendMessage("&aPlayer banned");
	}
}

class UnbanCommand : Command {
	this() {
		name = "unban";
		help = [
			"&a/unban [username]", // todo for an obligatory argument usually it's <username>?
			"&eUnbans the given player"
		];
		argumentsRequired = 1;
		permission        = 0xD0;
		category          = CommandCategory.Moderation;
	}

	override void Run(Server server, Client client, string[] args) {
		// todo no longer needed?
		if (args.length == 0) {
			client.SendMessage("&cUsername parameter required");
			return;
		}

		auto username = args[0];

		JSONValue info;

		try {
			info = server.GetPlayerInfo(username);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", username));
			return;
		}

		info["banned"] = false;

		server.SavePlayerInfo(username, info);

		client.SendMessage("&aPlayer unbanned");
	}
}

class IPBanCommand : Command {
	this() {
		name = "ipban";
		help = [
			"&a/banip ip [ip]",
			"&eBans the given IP",
			"&a/banip player [player]",
			"&eBans the IP of the given player"
		];
		argumentsRequired = 2;
		permission        = 0xD0;
		category          = CommandCategory.Moderation;
	}

	override void Run(Server server, Client client, string[] args) {
		// todo no longer needed?
		if (args.length != 2) {
			client.SendMessage("&c2 parameters required");
			return;
		}

		switch (args[0]) {
			case "ip": {
				server.KickIPs(args[1], "You are banned!");

				string path = dirName(thisExePath()) ~ "/banned_ips.txt";

				std.file.write(path, readText(path) ~ '\n' ~ args[1]);
				break;
			}
			case "player": {
				string path   = dirName(thisExePath()) ~ "/banned_ips.txt";
				auto   player = server.GetPlayer(args[1]);

				std.file.write(path, readText(path) ~ '\n' ~ player.ip);
			
				if (server.PlayerOnline(args[1])) {
					server.Kick(args[1], "You are banned!");
				}
				break;
			}
			default: {
				client.SendMessage(format("&cUnknown option %s", args[0]));
			}
		}
	}
}

class IPUnbanCommand : Command {
	this() {
		name = "ipunban";
		help = [
			"&a/ipunban [ip]",
			"&eUnbans the given IP"
		];
		argumentsRequired = 1;
		permission        = 0xD0;
		category          = CommandCategory.Moderation;
	}

	override void Run(Server server, Client client, string[] args) {
		string   path = dirName(thisExePath()) ~ "/banned_ips.txt";
		string[] ips  = readText(path).split('\n');

		// todo no longer needed?
		if (args.length != 1) {
			client.SendMessage("&c1 parameter required (IP)");
			return;
		}

		if (!ips.canFind(args[0])) {
			client.SendMessage("&cIP not banned");
			return;
		}

		auto index = ips.countUntil(args[0]);
		ips = ips.remove(index);
		
		std.file.write(path, ips.join("\n"));

		client.SendMessage("&aIP unbanned");
	}
}
