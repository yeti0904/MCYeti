module mcyeti.client;

import std.file;
import std.json;
import std.path;
import std.zlib;
import std.ascii;
import std.array;
import std.stdio;
import std.format;
import std.socket;
import std.bitmanip;
import std.datetime;
import std.algorithm;
import std.digest.md;
import mcyeti.util;
import mcyeti.types;
import mcyeti.world;
import mcyeti.server;
import mcyeti.blockdb;
import mcyeti.protocol;
import mcyeti.commandManager;

alias MarkCallback = void function(Client, Server, void*);

class Client {
	Socket        socket;
	string        ip;
	string        username;
	bool          authenticated;
	ubyte[]       inBuffer;
	ubyte[]       outBuffer;
	World         world;
	JSONValue     info;
	Vec3!ushort[] marks;
	uint          marksWaiting;
	MarkCallback  markCallback;
	ushort        markBlock;
	void*         markInfo;
	
	private Vec3!float pos;
	private Dir3D      direction;    

	this(Socket psocket) {
		socket = psocket;
		ip     = socket.remoteAddress.toAddrString();
	}

	string GetDisplayName(bool includeTitle = false) {
		/*string ret;

		if (includeTitle && (info["title"].str != "")) {
			ret ~= format("[%s] ", info["title"].str);
		}
		
		ret ~= format(
			"&%s%s",
			info["colour"].str,
			info["nickname"].str == ""? username : info["nickname"].str
		);

		return ret;*/

		return Client.GetDisplayName(username, info, includeTitle);
	}

	static string GetDisplayName(string username, JSONValue pinfo, bool includeTitle = false) {
		string ret;

		if (includeTitle && (pinfo["title"].str != "")) {
			ret ~= format("&f[%s&f] ", pinfo["title"].str);
		}
		
		ret ~= format(
			"&%s%s",
			pinfo["colour"].str,
			pinfo["nickname"].str == ""? username : pinfo["nickname"].str
		);

		return ret;
	}

	Vec3!float GetPosition() {
		return pos;
	}

	Dir3D GetDirection() {
		return direction;
	}

	void SendMessage(string msg) {
		bool firstSend = true;
		while (msg.length > 0) {
			auto message = new S2C_Message();

			message.id       = cast(byte) 0;
			message.message  = msg[0 .. (min(64, msg.length))];
			outBuffer       ~= message.CreateData();

			msg = msg[min(64, msg.length) .. $];

			firstSend = false;
		}
	}

	bool SendData(Server server) {
		if (outBuffer.length == 0) {
			return true;
		}
	
		socket.blocking = true;

		while (outBuffer.length > 0) {
			auto len = socket.send(cast(void[]) outBuffer);

			if (len == Socket.ERROR) {
				return false;
			}

			outBuffer = outBuffer[len .. $];
		}

		socket.blocking = false;
		return true;
	}

	void SaveInfo() {
		string infoPath = format(
			"%s/players/%s.json",
			dirName(thisExePath()), username
		);

		std.file.write(infoPath, info.toPrettyString());
	}

	void SendWorld(World world, Server server) {
		auto serialised = world.PackXZY();

		outBuffer ~= (new S2C_LevelInit()).CreateData();

		// add world size
		serialised = nativeToBigEndian(world.GetVolume()) ~ serialised;

		auto compressor  = new Compress(HeaderFormat.gzip);
		auto compressed  = compressor.compress(serialised);
		compressed      ~= compressor.flush();

		serialised = cast(ubyte[]) compressed;

		while (serialised.length > 0) {
			auto packet = new S2C_LevelChunk();

			packet.length = cast(short) min(serialised.length, 1024);
			packet.data   = new ubyte[1024];
			
			packet.data[0 .. packet.length] = serialised[0 .. packet.length];

			serialised = serialised[packet.length .. $];

			// get percentage
			float floatVolume = cast(float) world.GetVolume();
			float floatSent   = floatVolume - cast(float) serialised.length;
			packet.percent = cast(ubyte) ((floatSent / floatVolume) * 100.0);

			outBuffer ~= packet.CreateData();
		}

		auto endPacket = new S2C_LevelFinalise();
		endPacket.x    = world.GetSize().x;
		endPacket.y    = world.GetSize().y;
		endPacket.z    = world.GetSize().z;
		outBuffer     ~= endPacket.CreateData();

		pos = world.spawn.CastTo!float();

		world.NewClient(this, server);
	}

	void Mark(uint amount, MarkCallback callback, void* info) {
		marksWaiting = amount;
		markCallback = callback;
		markInfo     = info;
		SendMessage("&eMark a block");
	}

	void Update(Server server) {
		if (inBuffer.length == 0) {
			return;
		}

		switch (inBuffer[0]) {
			case C2S_Identification.pid: {
				auto packet = new C2S_Identification();
				
				if (inBuffer.length < packet.GetSize() + 1) {
					break;
				}

				inBuffer = inBuffer[1 .. $];

				packet.FromData(inBuffer);
				inBuffer = inBuffer[packet.GetSize() .. $];

				auto correctMppass = md5Of(
					server.salt ~ packet.username
				).BytesToString();

				if ((correctMppass == packet.mppass) || (ip == "127.0.0.1")) {
					username = packet.username;
				}
				else {
					server.Kick(this, "Incorrect mppass");
					return;
				}

				if (server.PlayerOnline(packet.username)) {
					server.Kick(packet.username, "Connected from another client");
					return;
				}

				if (packet.protocolVersion != 0x07) {
					server.Kick(this, "Server only supports protocol version 7");
					return;
				}

				authenticated = true;

				// set up info
				info = parseJSON("{}");
				info["rank"]   = 0x00;
				info["banned"] = false;

				string infoPath = format(
					"%s/players/%s.json",
					dirName(thisExePath()), username
				);

				if (exists(infoPath)) {
					info = parseJSON(readText(infoPath));
				}
				else {
					SaveInfo();
				}

				// new player info stuff
				if ("colour" !in info) {
					info["colour"] = "f";
				}
				if ("title" !in info) {
					info["title"] = "";
				}
				if ("nickname" !in info) {
					info["nickname"] = "";
				}
				if ("infractions" !in info) {
					info["infractions"] = cast(JSONValue[]) [];
				}
				SaveInfo();

				if (info["banned"].boolean) {
					server.Kick(this, "You're banned!");
					return;
				}

				server.SendGlobalMessage(
					format("&a+&f %s &fhas connected", GetDisplayName(true))
				);

				if (server.config.owner == username) {
					info["rank"] = 0xF0;
					SaveInfo();
				}

				auto identification = new S2C_Identification();

				identification.protocolVersion = 0x07;
				identification.serverName      = server.config.name;
				identification.motd            = server.config.motd;
				identification.userType        = 0x64;

				outBuffer ~= identification.CreateData();

				// send world
				server.SendPlayerToWorld(this, server.config.mainLevel);
				break;
			}
			case C2S_SetBlock.pid: {
				auto packet = new C2S_SetBlock();
				
				if (inBuffer.length < packet.GetSize() + 1) {
					break;
				}

				inBuffer = inBuffer[1 .. $];

				packet.FromData(inBuffer);
				inBuffer = inBuffer[packet.GetSize() .. $];

				if (world is null) {
					break;
				}
				
				auto pos = Vec3!ushort(packet.x, packet.y, packet.z);

				bool resetBlock = false;

				if (info["rank"].integer < world.GetPermissionBuild()) {
					SendMessage("&cYou can't build here");
					resetBlock = true;
				}

				if (marksWaiting > 0) {
					-- marksWaiting;

					marks      ~= pos;
					resetBlock  = true;
					markBlock   = packet.blockType;

					if (marksWaiting > 0) {
						SendMessage("&eMark a block");
					}
					else {
						if (markCallback) {
							markCallback(this, server, markInfo);
							marksWaiting = 0;
							markCallback = null;
							markBlock    = 0;
							marks        = [];
						}
						else {
							SendMessage("&eWarning: no mark callback set");
						}
					}
				}

				if (resetBlock) {
					auto resetPacket  = new S2C_SetBlock();
					resetPacket.x     = packet.x;
					resetPacket.y     = packet.y;
					resetPacket.z     = packet.z;
					resetPacket.block = world.GetBlock(packet.x, packet.y, packet.z);

					outBuffer ~= resetPacket.CreateData();
					break;
				}

				auto oldBlock = world.GetBlock(packet.x, packet.y, packet.z);

				ubyte blockType;
				if (packet.mode == 0x01) { // created
					blockType = packet.blockType;
				}
				else { // destroyed
					blockType = Block.Air;
				}
				world.SetBlock(packet.x, packet.y, packet.z, blockType);

				// save to BlockDB
				auto blockdb = new BlockDB(world.GetName());

				auto entry = BlockEntry(
					username,
					packet.x,
					packet.y,
					packet.z,
					blockType,
					oldBlock,
					Clock.currTime().toUnixTime(),
					""
				);

				blockdb.AppendEntry(entry);
				break;
			}
			case C2S_Position.pid: {
				auto packet = new C2S_Position();
				
				if (inBuffer.length < packet.GetSize() + 1) {
					break;
				}

				inBuffer = inBuffer[1 .. $];

				if (world is null) {
					break;
				}

				packet.FromData(inBuffer);
				inBuffer = inBuffer[packet.GetSize() .. $];

				pos.x             = packet.x;
				pos.y             = packet.y;
				pos.z             = packet.z;
				direction.yaw     = packet.yaw;
				direction.heading = packet.heading;

				auto packetOut = new S2C_SetPosOr();

				packetOut.id      = world.GetClientID(this);
				packetOut.x       = pos.x;
				packetOut.y       = pos.y;
				packetOut.z       = pos.z;
				packetOut.yaw     = direction.yaw;
				packetOut.heading = direction.heading;

				foreach (key, value ; world.clients) {
					if ((value is null) || (value is this)) {
						continue;
					}

					value.outBuffer ~= packetOut.CreateData();
				}
				break;
			}
			case C2S_Message.pid: {
				auto packet = new C2S_Message();

				if (inBuffer.length < packet.GetSize() + 1) {
					break;
				}

				inBuffer = inBuffer[1 .. $];

				packet.FromData(inBuffer);
				inBuffer = inBuffer[packet.GetSize() .. $];

				string colourCodes = "0123456789abcdef";
				char[] msg         = cast(char[]) packet.message;
				for (size_t i = 0; i < msg.length - 1; ++ i) {
					if (
						(msg[i] == '%') &&
						colourCodes.canFind(msg[i + 1])
					) {
						msg[i] = '&';
					}
				}
				packet.message = cast(string) msg;

				if (!authenticated) {
					break;
				}

				if (packet.message[0] == '/') {
					auto parts = packet.message[1 .. $].split!isWhite();

					if (parts.length == 0) {
						break;
					}

					if (!server.commands.CommandExists(parts[0])) {
						SendMessage("&cNo such command");
						return;
					}

					if (!server.commands.CanRunCommand(parts[0], this)) {
						SendMessage("&cYou can't run this command");
						break;
					}

					try {
						server.commands.RunCommand(
							parts[0], server, this, parts[1 .. $]
						);
					}
					catch (CommandException e) {
						SendMessage(format("&c%s", e.msg));
					}
					break;
				}

				
				auto message = format(
					"%s: &f%s", GetDisplayName(true), packet.message
				);
				server.SendGlobalMessage(message);
				break;
			}
			default: {
				server.Kick(this, format("Bad packet ID %X", inBuffer[0]));
				return;
			}
		}
	}
}
