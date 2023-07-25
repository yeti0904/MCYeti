module mcyeti.commands.chat;

import std.conv;
import std.file;
import std.json;
import std.path;
import std.array;
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
import mcyeti.protocol;
import mcyeti.commandManager;

class ColourCommand : Command {
	this() {
		name = "colour";
		help = [
			"&a/colour [username] [colour]",
			"&eSets the given user's colour to the given colour"
		];
		argumentsRequired = 2;
		permission        = 0xD0;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		JSONValue info;

		try {
			info = server.GetPlayerInfo(args[0]);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", e.msg));
			return;
		}

		auto colours = server.GetChatColours();

		if (args[1] !in colours) {
			client.SendMessage("&cNo such colour");
			return;
		}

		info["colour"] = cast(string) [colours[args[1]]];

		server.SavePlayerInfo(args[0], info);

		server.SendGlobalMessage(
			format(
				"%s&e's colour was changed to %s",
				Client.GetDisplayName(args[0], info),
				args[1]
			)
		);

		if (server.PlayerOnline(args[0])) {
			auto player = server.GetPlayer(args[0]);

			player.info = info;
		}
	}
}

class MyColourCommand : Command {
	this() {
		name = "mycolour";
		help = [
			"&a/mycolour [colour]",
			"&eSets your colour to the given colour"
		];
		argumentsRequired = 1;
		permission        = 0x00;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		auto cmd = new ColourCommand();

		cmd.Run(server, client, [client.username] ~ args[0]);
	}
}

class TitleCommand : Command {
	this() {
		name = "title";
		help = [
			"&a/title [player] [title]",
			"&eSets the given user's title to the given title"
		];
		argumentsRequired = 1;
		permission        = 0xD0;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		JSONValue info;

		try {
			info = server.GetPlayerInfo(args[0]);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", e.msg));
			return;
		}

		string title;

		if (args.length > 1) {
			foreach (word ; args[1 .. $]) {
				title ~= word ~ ' ';
			}

			title = title.strip();
		}
		else {
			title = "";
		}

		if (title.length > 10) {
			client.SendMessage("&eTitle must be 10 or less letters");
			return;
		}

		info["title"] = title;

		server.SavePlayerInfo(args[0], info);

		server.SendGlobalMessage(
			format(
				"%s&e's title was changed to %s",
				Client.GetDisplayName(args[0], info),
				title
			)
		);

		if (server.PlayerOnline(args[0])) {
			auto player = server.GetPlayer(args[0]);

			player.info = info;
		}
	}
}

class MyTitleCommand : Command {
	this() {
		name = "mytitle";
		help = [
			"&a/mytitle [title]",
			"&eSets your title to the given title"
		];
		argumentsRequired = 1;
		permission        = 0x00;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		auto cmd = new TitleCommand();

		cmd.Run(server, client, [client.username] ~ args);
	}
}

class NickCommand : Command {
	this() {
		name = "nick";
		help = [
			"&a/nick [player] [title]",
			"&eSets the given user's nickname to the given nickname"
		];
		argumentsRequired = 2;
		permission        = 0xD0;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		JSONValue info;

		try {
			info = server.GetPlayerInfo(args[0]);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", e.msg));
			return;
		}

		string nick;

		foreach (word ; args[1 .. $]) {
			nick ~= word ~ ' ';
		}

		nick = nick.strip();

		if (nick.length > 30) {
			client.SendMessage("&eNickname must be 30 or less letters");
			return;
		}

		auto oldNick = info["nickname"].str;
		if (oldNick == "") {
			oldNick = client.username;
		}

		info["nickname"] = nick;

		server.SavePlayerInfo(args[0], info);

		server.SendGlobalMessage(
			format(
				"%s&e's nickname was changed to %s",
				oldNick, nick
			)
		);

		if (server.PlayerOnline(args[0])) {
			auto player = server.GetPlayer(args[0]);

			player.info = info;
		}
	}
}

class MyNickCommand : Command {
	this() {
		name = "mynick";
		help = [
			"&a/mynick [nickname]",
			"&eSets your nickname to the given nickname"
		];
		argumentsRequired = 1;
		permission        = 0xE0;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		auto cmd = new NickCommand();

		cmd.Run(server, client, [client.username] ~ args);
	}
}

class ShortNameCommand : Command {
	this() {
		name = "shortname";
		help = [
			"&a/shortname [nickname]",
			"&eSets your nickname to the given nickname as long",
			"&eas your username contains the given nickname"
		];
		argumentsRequired = 1;
		permission        = 0x00;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		if (!client.username.LowerString().canFind(args[0].CleanString().LowerString())) {
			client.SendMessage("&cYour shortname must be a part of your original name");
			return;
		}

		if (args[0].length < 3) {
			client.SendMessage("&cYour shortname must be at least 3 letters long");
			return;
		}

		auto cmd = new NickCommand();
		cmd.Run(server, client, [client.username, args[0]]);
	}
}

class ColoursCommand : Command {
	this() {
		name = "colours";
		help = [
			"&a/colours",
			"&eShows all colours"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		auto colours = server.GetChatColours();

		client.SendMessage("&eAvailable colours:");

		foreach (key, value ; colours) {
			client.SendMessage(format("  &%c%s&f = %c", value, key, value));
		}
	}
}

class SayCommand : Command {
	this() {
		name = "say";
		help = [
			"&a/say [message]",
			"&eBroadcasts a global message to everyone in the server"
		];
		argumentsRequired = 1;
		permission        = 0xD0;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		string msg = args.join(" ").strip();
		server.SendGlobalMessage(msg);
	}
}

class HighFiveCommand : Command {
	this() {
		name = "highfive";
		help = [
			"&a/highfive [player]",
			"&eHighfives a player"
		];
		argumentsRequired = 1;
		permission        = 0x00;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		if (!server.PlayerOnline(args[0])) {
			client.SendMessage("&cPlayer not online");
			return;
		}

		auto player = server.GetPlayer(args[0]);
		server.SendGlobalMessage(
			format("%s&e highfived %s", client.GetDisplayName(), player.GetDisplayName())
		);
	}
}
class HugCommand : Command {
	this() {
		name = "hug";
		help = [
			"&a/hug [player]",
			"&eHugs a player"
		];
		argumentsRequired = 1;
		permission        = 0x00;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		if (!server.PlayerOnline(args[0])) {
			client.SendMessage("&cPlayer not online");
			return;
		}

		auto player = server.GetPlayer(args[0]);
		server.SendGlobalMessage(
			format("%s&e hugged %s", client.GetDisplayName(), player.GetDisplayName())
		);
	}
}
class KissCommand : Command {
	this() {
		name = "kiss";
		help = [
			"&a/kiss [player]",
			"&eKisses a player"
		];
		argumentsRequired = 1;
		permission        = 0x00;
		category          = CommandCategory.Chat;
	}

	override void Run(Server server, Client client, string[] args) {
		if (!server.PlayerOnline(args[0])) {
			client.SendMessage("&cPlayer not online");
			return;
		}

		auto player = server.GetPlayer(args[0]);
		server.SendGlobalMessage(
			format("%s&e kissed %s", client.GetDisplayName(), player.GetDisplayName())
		);
	}
}
