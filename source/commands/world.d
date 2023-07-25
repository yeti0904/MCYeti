module mcyeti.commands.world;

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
import undead.stream;
import mcyeti.util;
import mcyeti.types;
import mcyeti.world;
import mcyeti.client;
import mcyeti.server;
import mcyeti.blockdb;
import mcyeti.commandManager;

class PerbuildCommand : Command {
	this() {
		name = "perbuild";
		help = [
			"&a/perbuild <rank>",
			"&eSets the minimum rank needed to build on a map"
		];
		argumentsRequired = 1;
		permission        = 0xE0;
		category          = CommandCategory.World;
	}

	override void Run(Server server, Client client, string[] args) {
		ubyte rank;

		try {
			rank = server.GetRank(args[0]);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", e.msg));
		}

		client.world.SetPermissionBuild(rank);
		client.world.Save(server);

		client.SendMessage("&aPerbuild changed");
	}
}

class PervisitCommand : Command {
	this() {
		name = "pervisit";
		help = [
			"&a/pervisit <rank>",
			"&eSets the minimum rank needed to visit a map"
		];
		argumentsRequired = 1;
		permission        = 0xE0;
		category          = CommandCategory.World;
	}

	override void Run(Server server, Client client, string[] args) {
		ubyte rank;

		try {
			rank = server.GetRank(args[0]);
		}
		catch (ServerException e) {
			client.SendMessage(format("&c%s", e.msg));
		}

		client.world.SetPermissionVisit(rank);
		client.world.Save(server);

		client.SendMessage("&aPervisit changed");
	}
}

class GotoCommand : Command {
	this() {
		name = "goto";
		help = [
			"&a/goto <level name>",
			"&eSends you to the given level"
		];
		argumentsRequired = 1;
		permission        = 0x00;
		category          = CommandCategory.World;
	}

	override void Run(Server server, Client client, string[] args) {
		if (client.marksWaiting > 0) {
			client.SendMessage("&cCannot move levels while marking");
			return;
		}

		if (!server.WorldLoaded(args[0])) {
			try {
				server.LoadWorld(args[0]);
			}
			catch (WorldException e) {
				client.SendMessage(format("&c%s", e.msg));
				return;
			}
			catch (ServerException e) {
				client.SendMessage(format("&c%s", e.msg));
				return;
			}
		}

		auto world = server.GetWorld(args[0]);

		if (world.GetPermissionVisit() > client.info["rank"].integer) {
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
			"&a/newlevel <name> <x size> <y size> <z size> <type>",
			"&eCreates a new level",
			"&eTypes: flat, normal"
		];
		argumentsRequired = 5;
		permission        = 0xD0;
		category          = CommandCategory.World;
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
		world.Save(server);

		server.worlds ~= world;

		client.SendMessage("&aCreated level");
	}
}


class BlockInfoCommand : Command {
	this() {
		name = "blockinfo";
		help = [
			"&a/blockinfo",
			"&eShows history and type of a block"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.World;
	}
	
	static void MarkCallback(Client client, Server server, void* extra) {
		auto pos     = client.marks[0];
		auto blockdb = new BlockDB(client.world.GetName());

		client.SendMessage("&eRetrieving block change records...");

		auto stream = blockdb.OpenInputStream();
		blockdb.SkipMetadata(stream);
		auto buffer = new ubyte[blockdb.blockEntrySize];
		for (ulong i = 0; i < blockdb.GetEntryAmount(); ++ i) {
			auto entry = blockdb.NextEntry(stream, buffer);
			if (entry.x != pos.x || entry.y != pos.y || entry.z != pos.z) {
				continue;
			}

			string msg;

			SysTime currentTime = SysTime.fromUnixTime(
				Clock.currTime().toUnixTime()
			);

			SysTime entryTime = SysTime.fromUnixTime(
				SysTime.fromUnixTime(entry.time).toUnixTime()
			);

			Duration time = currentTime - entryTime;

			msg = format(
				"  &e%s ago: ", DiffTime(time.total!"seconds")
			);

			if (entry.blockType == 0) {
				msg ~= format("&f%s&e deleted this block", entry.player);
			}
			else {
				msg ~= format(
					"&f%s &eplaced &f%s", entry.player,
					cast(Block) entry.blockType
				);
			}

			if (entry.extra.length > 0) {
				msg ~= format(" %s", entry.extra);
			}

			client.SendMessage(msg);
		}

		auto block = client.world.GetBlock(pos.x, pos.y, pos.z);

		client.SendMessage(
			format(
				"&eBlock at (%d, %d, %d): &f%d = %s",
				pos.x, pos.y, pos.z, block, cast(Block) block
			)
		);
	}

	override void Run(Server server, Client client, string[] args) {
		if (client.world is null) {
			return;
		}
	
		client.Mark(1, &MarkCallback, null);
	}
}

class SetMainCommand : Command {
	this() {
		name = "setmain";
		help = [
			"&a/setmain",
			"&eSets the main level to this world",
			"&a/setmain [world name]",
			"&eSets the main level to the given world"
		];
		argumentsRequired = 0;
		permission        = 0xE0;
		category          = CommandCategory.World;
	}

	override void Run(Server server, Client client, string[] args) {
		string worldName;
	
		if (args.length == 0) {
			if (client.world is null) {
				client.SendMessage("&eYou are not in a world");
				return;
			}

			worldName = client.world.GetName();
		}
		else {
			worldName = args[0];

			if (!server.WorldExists(worldName)) {
				client.SendMessage("&eNo such world exists");
				return;
			}
		}

		server.config.mainLevel = worldName;
		server.SaveConfig();

		client.SendMessage(format("&eMain level is now &f%s", worldName));
	}
}

class MainCommand : Command {
	this() {
		name = "main";
		help = [
			"&a/main",
			"&eSends you to the main level"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.World;
	}

	override void Run(Server server, Client client, string[] args) {
		// server.SendPlayerToWorld(client, server.config.mainLevel);
		auto cmd = new GotoCommand();
		cmd.Run(server, client, [server.config.mainLevel]);
	}
}

class TpCommand : Command {
	this() {
		name = "tp";
		help = [
			"&a/tp <username>",
			"&eTeleports you to the given player",
			"&a/tp <x> <y> <z>",
			"&eTeleports you to the given coordinates"
		];
		argumentsRequired = 1;
		permission        = 0x00;
		category          = CommandCategory.World;
	}

	override void Run(Server server, Client client, string[] args) {
		if (args.length == 3) {
			Vec3!float pos;

			try {
				pos.x = parse!float(args[0]);
				pos.y = parse!float(args[1]);
				pos.z = parse!float(args[2]);
			}
			catch (ConvException) {
				client.SendMessage("&cNumeric arguments required");
				return;
			}

			client.Teleport(pos);
		}
		else if (args.length == 1) {
			if (!server.PlayerOnline(args[0])) {
				client.SendMessage("&cPlayer not online");
				return;
			}

			auto other = server.GetPlayer(args[0]);

			if (client.world is other.world) {
				client.Teleport(other.GetPosition());
			}
			else {
				auto cmd = new GotoCommand();
				cmd.Run(server, client, [other.world.GetName()]);

				if (client.world !is other.world) {
					return;
				}
				
				client.Teleport(other.GetPosition());
			}
		}
		else {
			client.SendMessage("&cInvalid parameters");
			return;
		}
	}
}

class SummonCommand : Command {
	this() {
		name = "summon";
		help = [
			"&a/summon <username>",
			"&eTeleports the given player to your position"
		];
		argumentsRequired = 1;
		permission        = 0xD0;
		category          = CommandCategory.World;
	}

	override void Run(Server server, Client client, string[] args) {
		if (!server.PlayerOnline(args[0])) {
			client.SendMessage("&cPlayer not online");
			return;
		}

		auto other = server.GetPlayer(args[0]);
		auto cmd   = new TpCommand();

		cmd.Run(server, other, [client.username]);

		other.SendMessage(format("&eYou were summoned by %s", client.username));
		client.SendMessage("&eSummoned player");
	}
}

class BackupCommand : Command {
	this() {
		name = "backup";
		help = [
			"&a/backup <info/setinterval <minutes>>",
			"&eConfigures interval of making backups for this world"
		];
		argumentsRequired = 1;
		permission        = 0xE0;
		category          = CommandCategory.World;
	}

	override void Run(Server server, Client client, string[] args) {
		World world = client.world;
		switch (args[0]) {
			case "info": {
				uint interval = world.GetBackupIntervalMinutes();
				if (interval == world.dontBackup) {
					client.SendMessage("&eThe current backup interval is &cnever");
					return;
				}
				client.SendMessage(format("&eThe current backup interval is &f%s (=%d minute(s))",
											DiffTime(interval * 60L), interval));
				break;
			}
			case "setinterval": {
				if (args.length < 2) {
					client.SendMessage("&cMissing \"minutes\" parameter");
					return;
				}
				uint minutes;
				try {
					minutes = to!uint(args[1]);
				}
				catch (ConvException) {
					client.SendMessage("&cNot an integer");
					return;
				}
				world.SetBackupIntervalMinutes(minutes);
				string message;
				if (minutes == 0) {
					message = "&aThe new interval is &cnever";
				} else {
					message = format("&aThe new interval is &f%s", DiffTime(minutes * 60L));
				}
				client.SendMessage(message);

				break;
			}
			default: {
				client.SendMessage("&cUnknown subcommand");

				break;
			}
		}
	}
}

