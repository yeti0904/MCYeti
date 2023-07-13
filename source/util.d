module mcyeti.util;

import std.conv;
import std.file;
import std.path;
import std.ascii;
import std.stdio;
import std.format;
import std.datetime;

class UtilException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

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
	auto str = format(fmt, args);

	writeln(str);

	version (Windows) {
		stdout.flush();
	}

	auto logsPath = dirName(thisExePath()) ~ "/logs/" ~ DateToday(true) ~ ".log";
	auto logFile  = File(logsPath, "a");

	logFile.writeln(str);
}

void Log(string str) {
	writeln(str);

	version (Windows) {
		stdout.flush();
	}

	auto logsPath = dirName(thisExePath()) ~ "/logs/" ~ DateToday(true) ~ ".log";
	auto logFile  = File(logsPath, "a");

	logFile.writeln(str);
}

long StringAsTimespan(string str) {
	if (str.length == 0) {
		throw new UtilException("Invalid timespan");
	}

	long ret;
	string num = str[0 .. $ - 1];

	try {
		ret = num.parse!int();
	}
	catch (ConvException) {
		throw new UtilException("Invalid timespan");
	}

	switch (str[$ - 1]) {
		case 's': break;
		case 'm': {
			ret *= 60;
			break;
		}
		case 'h': {
			ret *= 3600;
			break;
		}
		case 'd': {
			ret *= 86400;
			break;
		}
		default: {
			throw new UtilException("Invalid timespan");
		}
	}

	return ret;
}

string DateToday(bool dashes = false) {
	auto time = Clock.currTime();

	if (dashes) {
		return format("%d-%d-%d", time.day, time.month, time.year);
	}
	else {
		return format("%d/%d/%d", time.day, time.month, time.year);
	}
}

// ported from Helper.java of https://github.com/minecraft8997/BanAllShadBot
public static string DiffTime(ulong deltaSeconds) {
	ulong days = deltaSeconds / 86400;
	deltaSeconds -= days * 86400;
	ulong hours = deltaSeconds / 3600;
	deltaSeconds -= hours * 3600;
	ulong minutes = deltaSeconds / 60;
	deltaSeconds -= minutes * 60;
	ulong seconds = deltaSeconds;

	string result = "";
	bool needToAppendSpace = false;
	if (days > 0) {
		result ~= to!string(days) ~ "d";
		needToAppendSpace = true;
	}
	if (hours > 0) {
		result ~= (needToAppendSpace ? " " : "") ~ to!string(hours) ~ "h";
		needToAppendSpace = true;
	}
	if (minutes > 0) {
		result ~= (needToAppendSpace ? " " : "") ~ to!string(minutes) ~ "m";
		needToAppendSpace = true;
	}
	if (seconds > 0) {
		result ~= (needToAppendSpace ? " " : "") ~ to!string(seconds) ~ "s";
	}
	if (result.length == 0) result = "0s";

	return result;
}
