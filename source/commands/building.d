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
		category          = CommandCategory.World;
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
		auto blockdb = new BlockDB(client.world.GetName());

		for (ushort y = start.y; y <= end.y; ++ y) {
			for (ushort z = start.z; z <= end.z; ++ z) {
				for (ushort x = start.x; x <= end.x; ++ x) {
					auto oldBlock = client.world.GetBlock(x, y, z);
				
					client.world.SetBlock(
						x, y, z, cast(ubyte) client.markBlock
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
					blockdb.AppendEntry(entry);
				}
			}
		}

		auto size = Vec3!ushort(
			cast(ushort) (end.x - start.x),
			cast(ushort) (end.y - start.y),
			cast(ushort) (end.z - start.z)
		);

		auto volume = size.x * size.y * size.z;

		client.SendMessage(format("&eFilled %d blocks", volume));
	}

	override void Run(Server server, Client client, string[] args) {
		if (client.world is null) {
			return;
		}

		client.Mark(2, &MarkCallback, null);
	}
}
