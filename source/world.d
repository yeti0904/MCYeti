module mcyeti.world;

import std.file;
import std.path;
import std.stdio;
import std.bitmanip;
import mcyeti.types;
import mcyeti.client;
import mcyeti.server;
import mcyeti.protocol;

enum Block {
	Air              = 0,
	Stone            = 1,
	Grass            = 2,
	Dirt             = 3,
	Cobblestone      = 4,
	Wood             = 5,
	Sapling          = 6,
	Bedrock          = 7,
	Water            = 8,
	StillWater       = 9,
	Lava             = 10,
	StillLava        = 11,
	Sand             = 12,
	Gravel           = 13,
	GoldOre          = 14,
	IronOre          = 15,
	CoalOre          = 16,
	Log              = 17,
	Leaves           = 18,
	Sponge           = 19,
	Glass            = 20,
	RedWool          = 21,
	OrangeWool       = 22,
	YellowWool       = 23,
	LimeWool         = 24,
	GreenWool        = 25,
	TealWool         = 26,
	AquaWool         = 27,
	CyanWool         = 28,
	BlueWool         = 29,
	IndigoWool       = 30,
	VioletWool       = 31,
	MagentaWool      = 32,
	PinkWool         = 33,
	BlackWool        = 34,
	GreyWool         = 35,
	WhiteWool        = 36,
	Dandelion        = 37,
	Rose             = 38,
	BrownMushroom    = 39,
	RedMushroom      = 40,
	Gold             = 41,
	Iron             = 42,
	DoubleSlab       = 43,
	Slab             = 44,
	Brick            = 45,
	TNT              = 46,
	Bookshelf        = 47,
	MossyCobblestone = 48,
	Obsidian         = 49	
}

class WorldException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class World {  
	Vec3!ushort spawn;
	Client[256] clients;
	ubyte       permissionBuild;
	ubyte       permissionVisit;

	private string name;
	private ubyte[] blocks;
	private Vec3!ushort size;

	this(Vec3!ushort psize, string pname) {
		size   = psize;
		blocks = CreateBlockArray();
		name   = pname;
		
		spawn  = Vec3!ushort(
			size.x / 2,
			(size.y / 2) + 2,
			size.z / 2
		);

		for (uint i = 0; i < 256; ++ i) {
			clients[i] = null;
		}
	}

	this(string fileName) {
		if (baseName(fileName) != fileName) {
			throw new WorldException("Bad world name");
		}

		name = fileName;
	
		string worldPath = dirName(thisExePath()) ~ "/worlds/" ~ name ~ ".ylv";

		if (!exists(worldPath)) {
			throw new WorldException("No such world");
		}

		auto data = cast(ubyte[]) read(worldPath);

		size.x          = data[0 .. 2].bigEndianToNative!ushort();
		size.y          = data[2 .. 4].bigEndianToNative!ushort();
		size.z          = data[4 .. 6].bigEndianToNative!ushort();
		spawn.x         = data[6 .. 8].bigEndianToNative!ushort();
		spawn.y         = data[8 .. 10].bigEndianToNative!ushort();
		spawn.z         = data[10 .. 12].bigEndianToNative!ushort();
		permissionBuild = data[12];
		permissionVisit = data[13];

		blocks = data[512 .. $];
	}

	void Save() {
		string worldPath = dirName(thisExePath()) ~ "/worlds/" ~ name ~ ".ylv";

		auto file = File(worldPath, "wb");

		ubyte[] metadata =
			size.x.nativeToBigEndian() ~
			size.y.nativeToBigEndian() ~
			size.z.nativeToBigEndian() ~
			spawn.x.nativeToBigEndian() ~
			spawn.y.nativeToBigEndian() ~
			spawn.z.nativeToBigEndian() ~
		[
			permissionBuild,
			permissionVisit
		];

		while (metadata.length < 512) {
			metadata ~= 0;
		}

		file.rawWrite(metadata);
		file.rawWrite(blocks);

		file.flush();
		file.close();
	}

	void GenerateFlat() {
		blocks = CreateBlockArray();

		for (short y = 0; y < size.y; ++y) {
			for (short z = 0; z < size.z; ++z) {
				for (short x = 0; x < size.x; ++x) {
					ubyte type;
					if (y > size.y / 2) {
						type = Block.Air;
					}
					else if (y == size.y / 2) {
						type = Block.Grass;
					}
					else {
						type = Block.Dirt;
					}

					SetBlock(x, y, z, type, false);
				}
			}
		}
	}

	private size_t GetIndex(ushort x, ushort y, ushort z) {
		return (z * size.x * size.y) + (y * size.y) + x;
	}

	ubyte GetBlock(ushort x, ushort y, ushort z) {
		return blocks[GetIndex(x, y, z)];
	}

	void SetBlock(ushort x, ushort y, ushort z, ubyte block) {
		SetBlock(x, y, z, block, true);
	}

	void SetBlock(ushort x, ushort y, ushort z, ubyte block, bool sendPacket) {
		blocks[GetIndex(x, y, z)] = block;

		if (!sendPacket) return;

		auto packet  = new S2C_SetBlock();
		packet.x     = index.x;
		packet.y     = index.y;
		packet.z     = index.z;
		packet.block = block;
		
		foreach (i, client ; clients) {
			if (client is null) {
				continue;
			}

			client.outBuffer ~= packet.CreateData();
		}
	}

	string GetName() {
		return name;
	}

	uint GetVolume() {
		return cast(uint) blocks.length;
	}
	
	Vec3!ushort GetSize() {
		return size;
	}

	ubyte[] Serialise() {	
		ubyte[] ret = CreateBlockArray();
	        
		size_t i = 0;
		for (short y = 0; y < size.y; ++ y) {
			for (short z = 0; z < size.z; ++ z) {
				for (short x = 0; x < size.x; ++ x) {
					ret[i ++] = GetBlock(x, y, z);
				}
			}
		}

		return ret;
	}

	void NewClient(Client client, Server server) {
		// allocate an ID
		ubyte id;
		bool  gotID;
		for (ubyte i = 0; i < 256; ++ i) {
			if (clients[i] is null) {
				id    = i;
				gotID = true;
				break;
			}
		}

		if (!gotID) {
			assert(0);
		}

		clients[id] = client;

		foreach (i, clienti ; clients) {
			if (clienti is null) {
				continue;
			}
		
			auto packet = new S2C_SpawnPlayer();

			packet.id      = clienti is client? 255 : cast(ubyte) i;
			packet.name    = clienti.username;
			packet.x       = clienti.GetPosition().x;
			packet.y       = clienti.GetPosition().y;
			packet.z       = clienti.GetPosition().z;
			packet.yaw     = clienti.GetDirection().yaw;
			packet.heading = clienti.GetDirection().heading;

			client.outBuffer ~= packet.CreateData();
			client.SendData(server);

			if (clienti is client) {
				continue;
			}

			packet         = new S2C_SpawnPlayer();
			packet.id      = id;
			packet.name    = client.username;
			packet.x       = (client.GetPosition()).x;
			packet.y       = (client.GetPosition()).y;
			packet.z       = (client.GetPosition()).z;
			packet.yaw     = client.GetDirection().yaw;
			packet.heading = client.GetDirection().heading;

			clienti.outBuffer ~= packet.CreateData();
			clienti.SendData(server);
		}
	}

	void RemoveClient(Client client) {
		byte id;

		foreach (i, clienti ; clients) {
			if (clienti is client) {
				id = cast(byte) i;
			}
		}
	
		foreach (i, clienti ; clients) {
			if (clienti is null) {
				continue;
			}
		
			if (clienti is client) {
				clients[i] = null;
			}
			else {
				auto packet = new S2C_Despawn();

				packet.id = id;

				clienti.outBuffer ~= packet.CreateData();
			}
		}
	}

	ubyte GetClientID(Client client) {
		foreach (i, clienti ; clients) {
			if (clienti is client) {
				return cast(ubyte) i;
			}
		}

		assert(0);
	}

	ubyte[] CreateBlockArray() {
		return new ubyte[](size.y * size.z * size.x);
	}
}
