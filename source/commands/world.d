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
			"&a/perbuild [rank]",
			"&eSets the minimum rank needed to build on a map"
		];
		argumentsRequired = 1;
		permission        = 0xE0;
		category          = CommandCategory.World;
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

		client.world.SetPermissionBuild(rank);
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
		permission        = 0xE0;
		category          = CommandCategory.World;
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

		client.world.SetPermissionVisit(rank);
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
		permission        = 0x00;
		category          = CommandCategory.World;
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
			"&a/newlevel [name] [x size] [y size] [z size] [type]",
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
		world.Save();

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

		for (ulong i = 0; i < blockdb.GetEntryAmount(); ++ i) {
			auto entry    = blockdb.GetEntry(i);
			auto entryPos = Vec3!ushort(entry.x, entry.y, entry.z);

			if (entryPos != pos) {
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
				"  &e%s ago: ", time.toString
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
	
		client.Mark(1, &MarkCallback);
	}
}
