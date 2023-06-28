module mcyeti.protocol;

import std.conv;
import std.format;
import std.string;
import std.bitmanip;
import std.algorithm;

class ProtocolException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

ubyte[] ToClassicString(string str) {
	if (str.length > 64) {
		throw new ProtocolException(format("'%s' is longer than 64 chars", str));
	}

	ubyte[] ret = new ubyte[](64);
	ret[0 .. str.length] = str.representation;
	ret[str.length .. $] = ' ';

	return ret;
}

string FromClassicString(ubyte[] str) {
	string ret = cast(string) str.idup;

	return ret.stripRight();
}

string CleanString(string str) {
	string ret;

	for (size_t i = 0; i < str.length; ++ i) {
		if (str[i] == '&') {
			++ i;
		}
		else {
			ret ~= str[i];
		}
	}

	return ret;
}

class C2S_Packet {
	abstract size_t GetSize();
	abstract void   FromData(ubyte[] bytes);
}

class S2C_Packet {
	abstract ubyte[] CreateData();
}

class C2S_Identification : C2S_Packet {
	ubyte  protocolVersion;
	string username;
	string mppass;
	ubyte  unused;

	static const ubyte pid = 0x00;

	override size_t GetSize() {
		return 130;
	}

	override void FromData(ubyte[] bytes) {
		protocolVersion = bytes[0];
		username = bytes[1 .. 65].FromClassicString();
		mppass   = bytes[65 .. 129].FromClassicString();
		unused   = bytes[129];
	}
}

class C2S_SetBlock : C2S_Packet {
	short x;
	short y;
	short z;
	ubyte mode;
	ubyte blockType;

	static const ubyte pid = 0x05;

	override size_t GetSize() {
		return 8;
	}

	override void FromData(ubyte[] bytes) {
		x         = bytes[0 .. 2].bigEndianToNative!short();
		y         = bytes[2 .. 4].bigEndianToNative!short();
		z         = bytes[4 .. 6].bigEndianToNative!short();
		mode      = bytes[6];
		blockType = bytes[7];
	}
}

class C2S_Position : C2S_Packet {
	byte  id;
	float x;
	float y;
	float z;
	ubyte yaw;
	ubyte heading;

	static const ubyte pid = 0x08;

	override size_t GetSize() {
		return 9;
	}

	override void FromData(ubyte[] bytes) {
		id = bytes[0];
		x  = cast(float) (
			bytes[1 .. 3].bigEndianToNative!short()
		) / 32.0;
		y = cast(float) (
			bytes[3 .. 5].bigEndianToNative!short()
		) / 32.0;
		z = cast(float) (
			bytes[5 .. 7].bigEndianToNative!short()
		) / 32.0;
		yaw     = bytes[7];
		heading = bytes[8];
	}
}

class C2S_Message : C2S_Packet {
	byte   id;
	string message;

	static const ubyte pid = 0x0D;

	override size_t GetSize() {
		return 65;
	}

	override void FromData(ubyte[] bytes) {
		id      = bytes[0];
		message = bytes[1 .. 65].FromClassicString();
	}
}

class S2C_Identification : S2C_Packet {
	ubyte  protocolVersion;
	string serverName;
	string motd;
	ubyte  userType;

	static const ubyte pid = 0x00;

	override ubyte[] CreateData() {
		return cast(ubyte[]) [
			pid,
			protocolVersion
		] ~
			serverName.ToClassicString() ~
			motd.ToClassicString() ~
		[
			userType
		];
	}
}

class S2C_Ping : S2C_Packet {
	static const ubyte pid = 0x01;

	override ubyte[] CreateData() {
		return [
			pid
		];
	}
}

class S2C_LevelInit : S2C_Packet {
	static const ubyte pid = 0x02;

	override ubyte[] CreateData() {
		return [
			pid
		];
	}
}

class S2C_LevelChunk : S2C_Packet {
	short   length;
	ubyte[] data;
	ubyte   percent;

	static const ubyte pid = 0x03;

	override ubyte[] CreateData() {
		return [
			pid
		] ~
			length.nativeToBigEndian() ~
		data ~ [
			percent
		];
	}
}

class S2C_LevelFinalise : S2C_Packet {
	short x;
	short y;
	short z;

	static const ubyte pid = 0x04;

	override ubyte[] CreateData() {
		return [
			pid
		] ~
			x.nativeToBigEndian() ~
			y.nativeToBigEndian() ~
			z.nativeToBigEndian();
	}
}

class S2C_SetBlock : S2C_Packet {
	short x;
	short y;
	short z;
	ubyte block;

	static const ubyte pid = 0x06;

	override ubyte[] CreateData() {
		return [
			pid
		] ~
			x.nativeToBigEndian() ~
			y.nativeToBigEndian() ~
			z.nativeToBigEndian() ~
		[
			block
		];
	}
}

class S2C_SpawnPlayer : S2C_Packet {
	ubyte  id;
	string name;
	float  x;
	float  y;
	float  z;
	ubyte  yaw;
	ubyte  heading;

	static const ubyte pid = 0x07;

	override ubyte[] CreateData() {
		return cast(ubyte[]) [
			pid,
			id
		] ~
			name.ToClassicString() ~
			(cast(short) (
				x * 32.0
			)).nativeToBigEndian()
		~
			(cast(short) (
				y * 32.0
			)).nativeToBigEndian()
		~
			(cast(short) (
				z * 32.0
			)).nativeToBigEndian()
		~ [
			yaw,
			heading
		];
	}
}

class S2C_SetPosOr : S2C_Packet {
	byte  id;
	float x;
	float y;
	float z;
	ubyte yaw;
	ubyte heading;

	static const ubyte pid = 0x08;

	override ubyte[] CreateData() {
		return cast(ubyte[]) [
			pid,
			id
		] ~
			(cast(short) (
				x * 32
			)).nativeToBigEndian() ~
			(cast(short) (
				y * 32
			)).nativeToBigEndian() ~
			(cast(short) (
				z * 32
			)).nativeToBigEndian() ~
		[
			yaw,
			heading
		];
	}
}

class S2C_Despawn : S2C_Packet {
	byte id;

	static const ubyte pid = 0x0C;

	override ubyte[] CreateData() {
		return [
			pid,
			id
		];
	}
}

class S2C_Message : S2C_Packet {
	byte   id;
	string message;

	static const ubyte pid = 0x0D;

	override ubyte[] CreateData() {
		return cast(ubyte[]) [
			pid,
			id
		] ~
			message.ToClassicString();
	}
}

class S2C_Disconnect : S2C_Packet {
	string message;

	static const ubyte pid = 0x0E;

	override ubyte[] CreateData() {
		return [
			pid
		] ~
			message.ToClassicString();
	}
}
