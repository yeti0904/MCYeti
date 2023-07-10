module mcyeti.autosave;

import mcyeti.server;

void AutosaveTask(Server server) {
	server.SaveAll();
}
