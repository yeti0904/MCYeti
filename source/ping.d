module mcyeti.ping;

import mcyeti.server;
import mcyeti.protocol;

void PingTask(Server server) {
	foreach (i, ref client ; server.clients) {
		auto packet = new S2C_Ping();

		client.outBuffer ~= packet.CreateData();
		if (!client.SendData(server)) {
			server.Kick(client, "");
		}
	}
}
