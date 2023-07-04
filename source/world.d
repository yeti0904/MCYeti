module mcyeti.world;

import std.file;
import std.math;
import std.path;
import std.stdio;
import std.random;
import std.bitmanip;
import std.algorithm;
import core.thread.osthread;
import fast_noise;
import mcyeti.util;
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
	Vec3!ushort    spawn;
	Client[256]    clients;
	private ubyte  permissionBuild;
	private ubyte  permissionVisit;

	private string name;
	private ubyte[] blocks;
	private Vec3!ushort size;
	private ushort formatVersion;
	private bool changed = false;

	this(Vec3!ushort psize, string pname, string generator = "flat") {
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

		formatVersion = 1;

		switch (generator) {
			case "flat": {
				GenerateFlat();
				break;
			}
			case "normal": {
				GenerateNormal();
				break;
			}
			default: {
				throw new WorldException("Unknown generator specified!");
			}
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
		formatVersion   = data[14 .. 16].bigEndianToNative!ushort();
		
		if (formatVersion != 0 && formatVersion != 1) {
			throw new WorldException("Unsupported formatVersion");
		}

		blocks = data[512 .. $];

		if (size.x * size.y * size.z != blocks.length) {
			throw new WorldException("Block array size does not match volume of map");
		}
	}

	void Save() {
		if (!changed) return;

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
			] ~
			formatVersion.nativeToBigEndian();

		while (metadata.length < 512) {
			metadata ~= 0;
		}

		file.rawWrite(metadata);
		file.rawWrite(blocks);

		file.flush();
		file.close();

		changed = false;
	}

	void GenerateFlat() {
		for (ushort x = 0; x < size.x; ++ x) {
			for (ushort y = 0; y < size.y; ++ y) {
				for (ushort z = 0; z < size.z; ++ z) {
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

	void GenerateNormal() {
		FNLState noise = fnlCreateState(uniform(0, 0xFFFFFFFF));
		noise.noise_type = FNLNoiseType.FNL_NOISE_PERLIN;
	
		for (ushort x = 0; x < size.x; ++ x) {
			for (ushort z = 0; z < size.z; ++ z) {
				double value = fnlGetNoise3D(
					&noise,
					(cast(double) x), 0.0, (cast(double) z)
				);
				value += 1.0;

				ushort height = cast(ushort) (value * (cast(double) size.y));
				height /= 2;
				height  = cast(ushort) min(height, size.y - 1);

				foreach (i ; 0 .. height) {
					SetBlock(x, cast(ushort) i, z, Block.Dirt); // here
				}
				
				SetBlock(x, height, z, Block.Grass, false);
			}
		}
	}

	private size_t GetIndex(ushort x, ushort y, ushort z) {
		if (formatVersion == 1) {
			return (y * size.z + z) * size.x + x;
		}
		else {
			// this is deprecated and will produce a quite weird
			// generation sometimes. leaving this only for legacy levels support

			return (z * size.x * size.y) + (y * size.y) + x;
		}
	}

	ubyte GetBlock(ushort x, ushort y, ushort z) {
		return blocks[GetIndex(x, y, z)];
	}

	void SetBlock(ushort x, ushort y, ushort z, ubyte block, bool sendPacket = true) {
		blocks[GetIndex(x, y, z)] = block;
		changed = true;

		if (!sendPacket) return;

		auto packet  = new S2C_SetBlock();
		packet.x     = x;
		packet.y     = y;
		packet.z     = z;
		packet.block = block;
		
		foreach (i, client ; clients) {
			if (client is null) {
				continue;
			}
			if (client.world !is this) {
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

	ubyte[] PackXZY() {
		ubyte[] ret = CreateBlockArray();
	        
		size_t i = 0;
		for (ushort y = 0; y < size.y; ++ y) {
			for (ushort z = 0; z < size.z; ++ z) {
				for (ushort x = 0; x < size.x; ++ x) {
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

	void SetPermissionBuild(ubyte permissionBuild) {
		if (this.permissionBuild != permissionBuild) {
			this.permissionBuild = permissionBuild;
			changed = true;
		}
	}

	ubyte GetPermissionBuild() {
		return permissionBuild;
	}

	void SetPermissionVisit(ubyte permissionVisit) {
		if (this.permissionVisit != permissionVisit) {
			this.permissionVisit = permissionVisit;
			changed = true;
		}
	}

	ubyte GetPermissionVisit() {
		return permissionVisit;
	}

	private ubyte[] CreateBlockArray() {
		return new ubyte[](size.x * size.y * size.z);
	}
}
