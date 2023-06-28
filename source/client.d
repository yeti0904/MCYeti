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
import std.algorithm;
import std.digest.md;
import mcyeti.util;
import mcyeti.types;
import mcyeti.world;
import mcyeti.server;
import mcyeti.protocol;
import mcyeti.commandManager;

class Client {
	Socket    socket;
	string    ip;
	string    username;
	bool      authenticated;
	ubyte[]   inBuffer;
	ubyte[]   outBuffer;
	World     world;
	JSONValue info;
	
	private Vec3!float pos;
	private Dir3D      direction;    

	this(Socket psocket) {
		socket = psocket;
		ip     = socket.remoteAddress.toAddrString();
	}

	Vec3!float GetPosition() {
		return pos;
	}

	Dir3D GetDirection() {
		return direction;
	}

	void SendMessage(string msg) {
		auto message = new S2C_Message();

		message.id       = cast(byte) 255;
		message.message  = msg;
		outBuffer       ~= message.CreateData();
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
		auto serialised = world.Serialise();

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
					writeln(correctMppass);
					writeln(packet.mppass);
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

				server.SendGlobalMessage(
					format("&a+&f %s has connected", username)
				);

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

				if (info["banned"].boolean) {
					server.Kick(this, "You're banned!");
					return;
				}

				auto identification = new S2C_Identification();

				identification.protocolVersion = 0x07;
				identification.serverName      = server.config.name;
				identification.motd            = server.config.motd;
				identification.userType        = 0x00;

				outBuffer ~= identification.CreateData();

				// send world
				server.SendPlayerToWorld(this, "main");
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

				if (info["rank"].integer < world.permissionBuild) {
					SendMessage("&cYou can't build here");

					auto resetPacket  = new S2C_SetBlock();
					resetPacket.x     = packet.x;
					resetPacket.y     = packet.y;
					resetPacket.z     = packet.z;
					resetPacket.block = world.GetBlock(pos);

					outBuffer ~= resetPacket.CreateData();
					break;
				}

				if (packet.mode == 0x01) { // created
					world.SetBlock(pos, packet.blockType);
				}
				else { // destroyed
					world.SetBlock(pos, Block.Air);
				}
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

				if (!authenticated) {
					break;
				}

				if (packet.message[0] == '/') {
					auto parts = packet.message[1 .. $].split!isWhite();

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

				
				auto message = format("%s: %s", username, packet.message);
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
