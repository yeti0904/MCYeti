module mcyeti.cpe.support;

import std.bitmanip;
import mcyeti.client;
import mcyeti.server;
import mcyeti.protocol;

struct Extension {
	string name;
	int    extVersion;
	
	void function(Client, Server, bool*) handler;
}

const Extension[] supportedExtensions = [
	Extension("EmoteFix",  1, null),
	Extension("FullCP437", 1, null)
];

class Bi_ExtInfo : BiPacket {
	string appName;
	short  extensionCount;
	
	static const ubyte pid = 0x10;

	override size_t GetSize() {
		return 66;
	}

	override void FromData(ubyte[] bytes) {
		appName        = bytes[0  .. 64].FromClassicString();
		extensionCount = bytes[64 .. 66].bigEndianToNative!short();
	}

	override ubyte[] CreateData() {
		return cast(ubyte[]) [pid] ~
			appName.ToClassicString() ~ extensionCount.nativeToBigEndian();
	}
}

class Bi_ExtEntry : BiPacket {
	string name;
	int    extVersion;

	static const ubyte pid = 0x11;

	override size_t GetSize() {
		return 68;
	}

	override void FromData(ubyte[] bytes) {
		name       = bytes[0  .. 64].FromClassicString();
		extVersion = bytes[64 .. 68].bigEndianToNative!int();
	}

	override ubyte[] CreateData() {
		return cast(ubyte[]) [pid] ~
			name.ToClassicString() ~ extVersion.nativeToBigEndian();
	}
}
