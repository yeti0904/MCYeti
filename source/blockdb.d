module mcyeti.blockdb;

import std.file;
import std.path;
import std.stdio;
import std.bitmanip;
import mcyeti.protocol;
import mcyeti.util;

struct BlockEntry {
	string  player;
	ushort  x;
	ushort  y;
	ushort  z;
	ushort  blockType;
	ushort  previousBlock;
	ulong   time;
	string  extra;
} // 50 bytes

class BlockDBException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class BlockDB {
	private string path;

	static size_t blockEntrySize = 50;
	static ushort latestVersion  = 0x00;
	
	this(string name) {
		path = dirName(thisExePath()) ~ "/blockdb/" ~ name ~ ".db";
		
		auto file = File(path, "rb");

		if ((file.size < 2) || (((file.size() - 2) % blockEntrySize) != 0)) {
			throw new BlockDBException("Invalid BlockDB");
		}
	}

	static void CreateBlockDB(string name) {
		string path = dirName(thisExePath()) ~ "/blockdb/" ~ name ~ ".db";

		ubyte[] metadata = cast(ubyte[]) latestVersion.nativeToBigEndian().idup;
		std.file.write(path, metadata);
	}

	File Open(string mode) {
		return File(path, mode);
	}

	BlockEntry GetEntry(size_t index) {
		auto file = Open("rb");
	
		file.seek(2 + index * blockEntrySize);
		
		auto data = file.rawRead(new ubyte[blockEntrySize]);

		BlockEntry ret;
		ret.player        = data[0 .. 16].FromClassicString(16);
		ret.x             = data[16 .. 18].bigEndianToNative!ushort();
		ret.y             = data[18 .. 20].bigEndianToNative!ushort();
		ret.z             = data[20 .. 22].bigEndianToNative!ushort();
		ret.blockType     = data[22 .. 24].bigEndianToNative!ushort();
		ret.previousBlock = data[24 .. 26].bigEndianToNative!ushort();
		ret.time          = data[26 .. 34].bigEndianToNative!ulong();
		ret.extra         = data[34 .. 50].FromClassicString(16);

		return ret;
	}

	ubyte[] SerialiseEntry(BlockEntry entry) {
		ubyte[] ret = new ubyte[](blockEntrySize);

		assert(entry.player.ToClassicString().length == 64);

		ret[0 .. 16]  = entry.player.ToClassicString(16);
		ret[16 .. 18] = entry.x.nativeToBigEndian();
		ret[18 .. 20] = entry.y.nativeToBigEndian();
		ret[20 .. 22] = entry.z.nativeToBigEndian();
		ret[22 .. 24] = entry.blockType.nativeToBigEndian();
		ret[24 .. 26] = entry.previousBlock.nativeToBigEndian();
		ret[26 .. 34] = entry.time.nativeToBigEndian();
		ret[34 .. 50] = entry.extra.ToClassicString(16);


		return ret;
	}

	void AppendEntry(BlockEntry entry) {
		auto file = Open("ab");
		file.rawWrite(SerialiseEntry(entry));
		file.flush();
	}

	ulong GetEntryAmount() {
		return getSize(path) / blockEntrySize;
	}
}
