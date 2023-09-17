module mcyeti.commands.info;

import std.conv;
import std.file;
import std.json;
import std.path;
import std.array;
import std.format;
import std.string;
import std.algorithm;
import core.stdc.stdlib;
import mcyeti.app;
import mcyeti.types;
import mcyeti.world;
import mcyeti.client;
import mcyeti.player;
import mcyeti.server;
import mcyeti.commandManager;

class HelpCommand : Command {
	this() {
		name = "help";
		help = [
			"&a/help",
			"&eShows all command categories",
			"&a/help category <category>",
			"&eShows all commands from that category",
			"&a/help <command>",
			"&eShows info about how to use that command"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.Info;
	}

	override void Run(Server server, Client client, string[] args) {
		if (args.length == 0) {
			/*client.SendMessage("&eAll commands:");

			foreach (ref command ; server.commands.commands) {
				client.SendMessage(format("  &a%s", command.name));
			}

			client.SendMessage(
				format(
					"&e%d commands available", server.commands.commands.length
				)
			);*/
			client.SendMessage("&eAll categories:");

			for (auto i = CommandCategory.Info; i < CommandCategory.End; ++ i) {
				client.SendMessage(format("  %s", cast(CommandCategory) i));
			}

			client.SendMessage("&eUse /help category <category> for more info");
			client.SendMessage("&eAlso use /help help");
		}
		else if (args[0] == "category") {
			if (args.length < 2) {
				client.SendMessage("&cCommand category required");
				return;
			}

			CommandCategory category;

			try {
				category = server.commands.ToCategory(args[1]);
			}
			catch (CommandException e) {
				client.SendMessage(format("&c%s", e.msg));
				return;
			}

			uint amount;

			client.SendMessage(format("&eAll %s commands:", category));

			foreach (ref command ; server.commands.commands) {
				if (command.category == category) {
					client.SendMessage(format("  &a%s", command.name));
					++ amount;
				}
			}

			client.SendMessage(format("&eTotal: &a%d", amount));
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

			client.SendMessage(
				format(
					"&eUsable by: &f%s+",
					server.GetRankName(command.permission)
				)
			);

			if (aliases.length > 0) {
				aliases = aliases[0 .. $ - 2];

				client.SendMessage(format("&eAliases: &f%s", aliases));
			}
		}
	}
}

class InfoCommand : Command {
	this() {
		name = "info";
		help = [
			"&a/info [player]",
			"&eShows info for the given player",
			"&eIf player not given, shows your info"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.Info;
	}

	override void Run(Server server, Client client, string[] args) {
		string username;
	
		if (args.length == 0) {
			username = client.username;
		}
		else {
			username = args[0];
		}

		Player player;

		try {
			player = server.GetPlayerInfo(args[0]);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", e.msg));
			return;
		}

		string displayName = player.GetDisplayName();

		client.SendMessage(format("&aInfo for &e%s", displayName));
		client.SendMessage(
			format(
				"  &aRank:&e %s",
				server.GetRankName(cast(ubyte) player.rank)
			)
		);

		if (player.banned) {
			client.SendMessage("  &aPlayer is banned");
		}

		if (server.config.owner == username) {
			client.SendMessage("  &aPlayer is the server owner");
		}

		if (appDevelopers.canFind(username)) {
			client.SendMessage("  &aPlayer is an MCYeti developer");
		}
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
		permission        = 0x00;
		category          = CommandCategory.Info;
	}

	override void Run(Server server, Client client, string[] args) {
		client.SendMessage(format("&eAbout &a%s", server.config.name));
		// do not display the exact version for security reasons
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
		permission        = 0x00;
		category          = CommandCategory.Info;
	}

	override void Run(Server server, Client client, string[] args) {
		client.SendMessage("&aRanks:");
		
		foreach (key, value ; server.ranks.object) {
			client.SendMessage(format("  &e%s", key));
		}
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
		permission        = 0x00;
		category          = CommandCategory.Info;
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
		permission        = 0x00;
		category          = CommandCategory.Info;
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

class RulesCommand : Command {
	this() {
		name = "rules";
		help = [
			"&a/rules",
			"&eShows you the server rules"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.Info;
	}

	override void Run(Server server, Client client, string[] args) {
		string rulesPath = dirName(thisExePath()) ~ "/text/rules.txt";

		client.SendMessage("&eServer rules:");

		foreach (ref line ; readText(rulesPath).split("\n")) {
			client.SendMessage(format("&e%s", line));
		}
	}
}
class RickRollCommand : Command {
	this() {
		name = "rickroll";
		help = [
			"&a/rickroll",
			"&eShows you the rickroll link"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.Info;
	}

	override void Run(Server server, Client client, string[] args) {
		client.SendMessage("&ehttps://youtube.com/watch?v=dQw4w9WgXcQ");
	}
}

class ClientsCommand : Command {
	this() {
		name = "clients";
		help = [
			"&a/clients",
			"&eShows what client everyone is using"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.Info;
	}

	override void Run(Server server, Client client, string[] args) {
		string[][string] clients;

		foreach (ref iclient ; server.clients) {
			if (!iclient.authenticated) {
				continue;
			}
			
			if (iclient.GetClientName() !in clients) {
				clients[iclient.GetClientName()] = [];
			}
			
			clients[iclient.GetClientName()] ~= iclient.username;
		}

		client.SendMessage("&ePlayers using:");
		foreach (clientName, users ; clients) {
			string msg = format("&e  %s:&f ", clientName);

			foreach (i, ref user ; users) {
				msg ~= user;

				if (i < users.length - 1) {
					msg ~= ", ";
				}
			}

			client.SendMessage(msg);
		}
	}
}

class CPEExtensionsCommand : Command {
	this() {
		name = "cpeextensions";
		help = [
			"&a/cpeextensions",
			"&eShows all the extensions that both you and the server have"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.Info;
	}

	override void Run(Server server, Client client, string[] args) {
		if (!client.cpeSupported) {
			client.SendMessage("&cYou don't have CPE");
			return;
		}

		client.SendMessage("&cExtensions:");

		foreach (ref ext ; client.cpeExtensions) {
			client.SendMessage(format("  &b%s", ext));
		}
	}
}
