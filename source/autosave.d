module mcyeti.autosave;

import mcyeti.server;

private ulong minutesPassed;

void AutosaveTask(Server server) {
    if ((minutesPassed ++) == 0) return;

    foreach (i, ref world ; server.worlds) {
        if (world.backupIntervalMinutes == world.DONT_BACKUP) continue;

        if (minutesPassed % world.backupIntervalMinutes == 0) {
            world.Save(server, true);
        }
    }
}
