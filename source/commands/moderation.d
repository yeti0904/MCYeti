module mcyeti.commands.moderation;

import std.conv;
import std.file;
import std.json;
import std.path;
import std.array;
import std.range;
import std.format;
import std.string;
import std.datetime;
import std.algorithm;
import core.stdc.stdlib;
import mcyeti.util;
import mcyeti.types;
import mcyeti.world;
import mcyeti.client;
import mcyeti.server;
import mcyeti.blockdb;
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

class CmdSetCommand : Command {
	this() {
		name = "cmdset";
		help = [
			"&a/cmdset [command] [permission]",
			"&eSets the given command's permission to the given permission"
		];
		argumentsRequired = 2;
		permission        = 0xE0;
		category          = CommandCategory.Moderation;
	}

	override void Run(Server server, Client client, string[] args) {
		if (!server.commands.CommandExists(args[0])) {
			client.SendMessage("&cNo such command");
			return;
		}
	
		if (!server.RankExists(args[1])) {
			client.SendMessage("&cNo such rank");
			return;
		}

		auto cmd = server.commands.GetCommand(args[0]);
		server.SetCmdPermission(cmd, server.GetRank(args[1]));

		client.SendMessage(
			format("&f%s &eis now usable by &f%s+", args[0], args[1])
		);
	}
}

class UndoPlayerCommand : Command {
	this() {
		name = "undoplayer";
		help = [
			"&a/undoplayer [username] <timespan>",
			"&eUndos all of the given player's changes on this map"
		];
		argumentsRequired = 1;
		permission        = 0xD0;
		category          = CommandCategory.Moderation;
	}

	override void Run(Server server, Client client, string[] args) {
		if (client.world is null) {
			return;
		}

		auto blockdb = new BlockDB(client.world.GetName());
		auto time    = Clock.currTime().toUnixTime();
		long timespan;
		bool doTimespan;

		if (args.length > 1) {
			doTimespan = true;
			
			try {
				timespan = StringAsTimespan(args[1]);
			}
			catch (UtilException e) {
				client.SendMessage(format("&c%s", e.msg));
				return;
			}
		}

		foreach (i ; iota(0, blockdb.GetEntryAmount()).retro()) {
			auto entry = blockdb.GetEntry(i);

			if (entry.player != args[0]) {
				continue;
			}

			long timeDifference = time - entry.time;

			if (doTimespan && (timeDifference > timespan)) {
				continue;
			}

			client.world.SetBlock(
				entry.x, entry.y, entry.z, cast(ubyte) entry.previousBlock
			);

			auto undoEntry = BlockEntry(
				client.username,
				entry.x,
				entry.y,
				entry.z,
				client.world.GetBlock(entry.x, entry.y, entry.z),
				entry.blockType,
				time,
				"(Undone Other)"
			);
			blockdb.AppendEntry(undoEntry);
		}

		client.SendMessage("&cUndone player changes");
	}
}
