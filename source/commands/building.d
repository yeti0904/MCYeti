module mcyeti.commands.building;

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

class CuboidCommand : Command {
	this() {
		name = "cuboid";
		help = [
			"&a/cuboid",
			"&eMakes a cuboid of with the block in your hand"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.Building;
	}

	static void MarkCallback(Client client, Server server, void* extra) {
		auto start = Vec3!ushort(
			min(client.marks[0].x, client.marks[1].x),
			min(client.marks[0].y, client.marks[1].y),
			min(client.marks[0].z, client.marks[1].z)
		);
		auto end = Vec3!ushort(
			max(client.marks[0].x, client.marks[1].x),
			max(client.marks[0].y, client.marks[1].y),
			max(client.marks[0].z, client.marks[1].z)
		);

		auto size = Vec3!ushort(
			cast(ushort) (end.x - start.x),
			cast(ushort) (end.y - start.y),
			cast(ushort) (end.z - start.z)
		);
		auto volume = size.x * size.y * size.z;

		auto blockdb = new BlockDB(client.world.GetName());

		auto stream = blockdb.OpenOutputStreamAppend();
		auto buffer = new ubyte[blockdb.blockEntrySize];
		auto sendPackets = volume < 10000;
		for (ushort y = start.y; y <= end.y; ++ y) {
			for (ushort z = start.z; z <= end.z; ++ z) {
				for (ushort x = start.x; x <= end.x; ++ x) {
					auto oldBlock = client.world.GetBlock(x, y, z);
				
					client.world.SetBlock(
						x, y, z, cast(ubyte) client.markBlock, sendPackets
					);

					// make blockdb entry
					BlockEntry entry;
					entry.player        = client.username;
					entry.x             = x;
					entry.y             = y;
					entry.z             = z;
					entry.blockType     = client.markBlock;
					entry.previousBlock = oldBlock;
					entry.time          = Clock.currTime().toUnixTime();
					entry.extra         = "(Drawn)";
					blockdb.AppendEntry(stream, entry, buffer);
				}
			}
		}
		stream.flush();
		stream.close();
		if (!sendPackets) {
			foreach (i, player ; client.world.clients) {
				if (player is null) {
					continue;
				}
				if (player.world !is client.world) {
					continue;
				}

				player.SendWorld(client.world, server, false);
			}
		}

		client.SendMessage(format("&eFilled %d blocks", volume));
	}

	override void Run(Server server, Client client, string[] args) {
		if (client.world is null) {
			return;
		}

		client.Mark(2, &MarkCallback, null);
	}
}

class CopyCommand : Command {
	this() {
		name = "copy";
		help = [
			"&a/copy",
			"&eCopies a cuboid of blocks into the client clipboard"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.Building;
	}

	static void MarkCallback(Client client, Server server, void* extra) {
		auto start = Vec3!ushort(
			min(client.marks[0].x, client.marks[1].x),
			min(client.marks[0].y, client.marks[1].y),
			min(client.marks[0].z, client.marks[1].z)
		);
		auto end = Vec3!ushort(
			max(client.marks[0].x, client.marks[1].x),
			max(client.marks[0].y, client.marks[1].y),
			max(client.marks[0].z, client.marks[1].z)
		);
		client.clipboard = [];

		for (ushort y = start.y; y <= end.y; ++ y) {
			for (ushort z = start.z; z <= end.z; ++ z) {
				for (ushort x = start.x; x <= end.x; ++ x) {
					client.clipboard ~= ClipboardItem(
						cast(ushort) (x - start.x),
						cast(ushort) (y - start.y),
						cast(ushort) (z - start.z),
						client.world.GetBlock(x, y, z)
					);
				}
			}
		}

		client.SendMessage("&eCopied to clipboard");
	}
	
	override void Run(Server server, Client client, string[] args) {
		if (client.world is null) {
			return;
		}

		client.Mark(2, &MarkCallback, null);
	}
}

class PasteCommand : Command {
	this() {
		name = "paste";
		help = [
			"&a/paste",
			"&eCopies the contents of the clipboard into a place you mark"
		];
		argumentsRequired = 0;
		permission        = 0x00;
		category          = CommandCategory.Building;
	}

	static void MarkCallback(Client client, Server server, void* extra) {
		foreach (ref block ; client.clipboard) {
			auto pos = Vec3!ushort(
				cast(ushort) (client.marks[0].x + block.x),
				cast(ushort) (client.marks[0].y + block.y),
				cast(ushort) (client.marks[0].z + block.z)
			);

			if (!client.world.BlockInWorld(pos.x, pos.y, pos.z)) {
				continue;
			}

			client.world.SetBlock(pos.x, pos.y, pos.z, cast(ubyte) block.block);
		}

		client.SendMessage(format("&ePasted %d blocks", client.clipboard.length));
	}

	override void Run(Server server, Client client, string[] args) {
		if (client.world is null) {
			return;
		}

		client.Mark(1, &MarkCallback, null);
	}
}
