module mcyeti.util;

import std.ascii;
import std.stdio;
import std.format;

string LowerString(string str) {
	string ret;

	foreach (ref ch ; str) {
		ret ~= ch.toLower();
	}

	return ret;
}

string BytesToString(ubyte[] bytes) {
	string ret;
	string hex = "0123456789abcdef";

	foreach (ref b ; bytes) {
		ret ~= hex[b / 16];
		ret ~= hex[b % 16];
	}

	return ret;
}

void Log(Char, A...)(in Char[] fmt, A args) {
	writefln(fmt, args);

	version (Windows) {
		stdout.flush();
	}
}

void Log(string str) {
	writeln(str);

	version (Windows) {
		stdout.flush();
	}
}
