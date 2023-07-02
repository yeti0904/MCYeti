module mcyeti.commands;

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

class HelpCommand : Command {
	this() {
		name = "help";
		help = [
			"&a/help",
			"&eShows all loaded commands",
			"&a/help [command]",
			"&eShows info about how to use that command"
		];
		argumentsRequired = 0;
		permission = 0;
	}

	override void Run(Server server, Client client, string[] args) {
		if (args.length == 0) {
			client.SendMessage("&eAll commands:");

			foreach (ref command ; server.commands.commands) {
				client.SendMessage(format("  &a%s", command.name));
			}

			client.SendMessage(
				format(
					"&e%d commands available", server.commands.commands.length
				)
			);
		}
		else {
			Command command;

			try {
				command = server.commands.GetCommand(args[0]);
			}
			catch (CommandException e) {
				client.SendMessage(format("&c%s", e.msg));
				return;
			}

			foreach (ref line ; command.help) {
				client.SendMessage(line);
			}

			string aliases;

			foreach (key, value ; server.commands.aliases) {
				if (value == command.name) {
					aliases ~= format("%s, ", key);
				}
			}

			aliases = aliases[0 .. $ - 2];

			client.SendMessage(format("&eAliases: &f%s", aliases));
		}
	}
}

class ShutdownCommand : Command {
	this() {
		name = "shutdown";
		help = [
			"&a/shutdown",
			"&eSaves all levels and then shuts down"
		];
		argumentsRequired = 0;
		permission = 0xF0;
	}

	override void Run(Server server, Client client, string[] args) {
		server.SaveAll();
		
		foreach (ref clienti ; server.clients) {
			server.Kick(clienti, "Server shutdown");
		}
		
		exit(0);
	}
}

class InfoCommand : Command {
	this() {
		name = "info";
		help = [
			"&a/info <player>",
			"&eShows info for the given player",
			"&eIf player not given, shows your info"
		];
		argumentsRequired = 0;
		permission = 0x00;
	}

	override void Run(Server server, Client client, string[] args) {
		string username;
	
		if (args.length == 0) {
			username = client.username;
		}
		else {
			username = args[0];
		}

		JSONValue info;

		try {
			info = server.GetPlayerInfo(username);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", username));
			return;
		}

		client.SendMessage(format("&aInfo for &e%s", username));
		client.SendMessage(
			format(
				"  &aRank:&e %s",
				server.GetRankName(cast(ubyte) info["rank"].integer)
			)
		);

		if (info["banned"].boolean) {
			client.SendMessage("  &aPlayer is banned");
		}

		if (server.config.owner == username) {
			client.SendMessage("  &aPlayer is the server owner");
		}
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
		permission = 0xD0;
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
		permission = 0xD0;
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
		permission = 0xD0;
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
		permission = 0xD0;
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

class ServerInfoCommand : Command {
	this() {
		name = "serverinfo";
		help = [
			"&a/serverinfo",
			"&eShows info about the server"
		];
		argumentsRequired = 0;
		permission = 0x00;
	}

	override void Run(Server server, Client client, string[] args) {
		client.SendMessage(format("&eAbout &a%s", server.config.name));
		client.SendMessage("  &eRunning &aMCYeti");
		client.SendMessage(format("  &eOwner: &a%s", server.config.owner));
	}
}

class RanksCommand : Command {
	this() {
		name = "ranks";
		help = [
			"&a/ranks",
			"&eShows all ranks"
		];
		argumentsRequired = 0;
		permission = 0x00;
	}

	override void Run(Server server, Client client, string[] args) {
		client.SendMessage("&aRanks:");
		
		foreach (key, value ; server.ranks.object) {
			client.SendMessage(format("  &e%s", key));
		}
	}
}

class PerbuildCommand : Command {
	this() {
		name = "perbuild";
		help = [
			"&a/perbuild [rank]",
			"&eSets the minimum rank needed to build on a map"
		];
		argumentsRequired = 1;
		permission = 0xE0;
	}

	override void Run(Server server, Client client, string[] args) {
		// todo no longer needed?
		if (args.length != 1) {
			client.SendMessage("&c1 parameter required");
			return;
		}

		ubyte rank;

		try {
			rank = server.GetRank(args[0]);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", e.msg));
		}

		client.world.permissionBuild = rank;
		client.world.Save();

		client.SendMessage("&aPerbuild changed");
	}
}

class PervisitCommand : Command {
	this() {
		name = "pervisit";
		help = [
			"&a/pervisit [rank]",
			"&eSets the minimum rank needed to visit a map"
		];
		argumentsRequired = 1;
		permission = 0xE0;
	}

	override void Run(Server server, Client client, string[] args) {
		// todo no longer needed?
		if (args.length != 1) {
			client.SendMessage("&c1 parameter required");
			return;
		}

		ubyte rank;

		try {
			rank = server.GetRank(args[0]);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", e.msg));
		}

		client.world.permissionVisit = rank;
		client.world.Save();

		client.SendMessage("&aPervisit changed");
	}
}

class GotoCommand : Command {
	this() {
		name = "goto";
		help = [
			"&a/goto [level name]",
			"&eSends you to the given level"
		];
		argumentsRequired = 1;
		permission = 0x00;
	}

	override void Run(Server server, Client client, string[] args) {
		// todo no longer needed?
		if (args.length != 1) {
			client.SendMessage("&c1 parameter required");
			return;
		}

		if (!server.WorldLoaded(args[0])) {
			try {
				server.LoadWorld(args[0]);
			}
			catch (ServerException e) {
				client.SendMessage(format("&c%s", e.msg));
				return;
			}
		}

		auto world = server.GetWorld(args[0]);

		if (world.permissionVisit > client.info["rank"].integer) {
			client.SendMessage("&cYou can't go to this map");
			return;
		}

		server.SendPlayerToWorld(client, args[0]);

		server.SendGlobalMessage(
			format("&f%s &ewent to &a%s", client.username, args[0])
		);
	}
}

class NewLevelCommand : Command {
	this() {
		name = "newlevel";
		help = [
			"&a/newlevel [name] [x size] [y size] [z size] [type]",
			"&eCreates a new level",
			"&eTypes: flat"
		];
		argumentsRequired = 5;
		permission = 0xD0;
	}

	override void Run(Server server, Client client, string[] args) {
		World world;

		if (
			(!isNumeric(args[1])) ||
			(!isNumeric(args[2])) ||
			(!isNumeric(args[3]))
		) {
			client.SendMessage("&cNon-numeric size parameters");
			return;
		}

		auto size = Vec3!ushort(
			parse!ushort(args[1]),
			parse!ushort(args[2]),
			parse!ushort(args[3])
		);

		try {
			world = new World(size, args[0], args[4]);
		}
		catch (WorldException e) {
			client.SendMessage(format("&c%s", e.msg));
			return;
		}
		world.Save();

		server.worlds ~= world;

		client.SendMessage("&aCreated level");
	}
}

class LevelsCommand : Command {
	this() {
		name = "levels";
		help = [
			"&a/levels",
			"&eShows all levels"
		];
		argumentsRequired = 0;
		permission = 0x00;
	}

	override void Run(Server server, Client client, string[] args) {
		string folder = dirName(thisExePath()) ~ "/worlds";

		uint amount;

		client.SendMessage("&eAvailable levels:");

		foreach (entry ; dirEntries(folder, SpanMode.shallow)) {
			string name = baseName(entry.name).stripExtension();

			client.SendMessage(format("  &a%s", name));

			++ amount;
		}

		client.SendMessage(format("&a%d&e levels", amount));
	}
}

class PlayersCommand : Command {
	this() {
		name = "players";
		help = [
			"&a/players",
			"&eShows all online players"
		];
		argumentsRequired = 0;
		permission = 0x00;
	}

	override void Run(Server server, Client client, string[] args) {
		client.SendMessage("&ePlayers online:");

		foreach (ref clienti ; server.clients) {
			if (clienti.authenticated) {
				if (clienti.world) {
					client.SendMessage(
						format(
							"  &a%s (%s)", clienti.username,
							clienti.world.GetName()
						)
					);
				}
				else {
					client.SendMessage(format("  &a%s", clienti.username));
				}
			}
		}

		client.SendMessage(
			format("&a%d&e players online", server.clients.length)
		);
	}
}

class AddAliasCommand : Command {
	this() {
		name = "addalias";
		help = [
			"&a/addalias [alias name] [command]",
			"&eAdds a new alias"
		];
		argumentsRequired = 2;
		permission        = 0xE0;
	}

	override void Run(Server server, Client client, string[] args) {
		server.commands.aliases[args[0]] = args[1];

		string aliasesPath = dirName(thisExePath()) ~ "/properties/aliases.json";
		std.file.write(
			aliasesPath,
			server.commands.SerialiseAliases().toPrettyString()
		);
	}
}
