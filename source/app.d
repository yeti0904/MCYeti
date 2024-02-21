module mcyeti.app;

import std.file;
import std.stdio;
import core.thread;
import std.datetime.stopwatch;
import mcyeti.server;

void main() {
	string[] appFolders = [
		"./logs"
	];

	foreach (ref dir ; appFolders) {
		if (!exists(dir)) {
			mkdir(dir);
		}
	}

	auto server = Server.Instance();
	server.Init();

	double tickTimeGoal = 1000.0 / 100.0;

	while (server.running) {
		auto sw = StopWatch(AutoStart.yes);
		server.Update();
		sw.stop();
		
		double tickTime = sw.peek.total!("msecs");
		if (tickTimeGoal > tickTime) {
			Thread.sleep(dur!("msecs")(cast(long) (tickTimeGoal - tickTime)));
		}
	}
}
