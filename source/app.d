module mcyeti.app;

import std.file;
import std.stdio;

void main() {
	string[] appFolders = [
		"./logs"
	];

	foreach (ref dir ; appFolders) {
		if (!exists(dir)) {
			mkdir(dir);
		}
	}
}
