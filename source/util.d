module mcyeti.util;

import std.file;
import std.stdio;
import std.format;
import std.datetime;

string DateToday(bool dashes = false) {
	auto time = Clock.currTime();

	if (dashes) {
		return format("%d-%d-%d", time.day, time.month, time.year);
	}
	else {
		return format("%d/%d/%d", time.day, time.month, time.year);
	}
}

string CurrentTimeString() {
	auto time = Clock.currTime();
	return format("%.2d:%.2d:%.2d", time.hour, time.minute, time.second);
}

void Log(Char, A...)(in Char[] fmt, A args) {
	auto str = format("[%s] %s", CurrentTimeString(), format(fmt, args));

	printTo.writeln(str);

	version (Windows) {
		stdout.flush();
	}

	auto logsPath = "./logs/" ~ DateToday(true) ~ ".log";
	auto logFile  = File(logsPath, "a");

	logFile.writeln(str);
}

void Log(string str) {
	Log("%s", str);
}
