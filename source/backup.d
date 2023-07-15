module mcyeti.backup;

import mcyeti.server;
import mcyeti.util;

private static ulong minutesPassed;

void BackupTask(Server server) {
    if ((minutesPassed ++) == 0) return;

    foreach (i, ref world ; server.worlds) {
        uint interval = world.GetBackupIntervalMinutes();
        if (interval == world.dontBackup) continue;

        if (minutesPassed % interval == 0) {
            world.Save(server, true);
        }
    }
}
