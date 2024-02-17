module mcyeti.client;

import std.socket;
import std.concurrency;
import mcyeti.server;
import mcyeti.protocol;

struct ClientSendMessage {
	S2C_Packet packet;
}

struct ClientEndMessage {
	Tid tid;
}

class Client {
	bool   active;
	Socket socket;

	this(Socket psocket) {
		socket = psocket;
		active = true;
	}

	static void ThreadWorker(Tid parentTid, Socket socket) {
		auto client = new Client(socket);

		while (client.active) {
			receive(
				(ServerTickMessage) {
					client.Update();
				},
				(ClientSendMessage msg) {
					SendData(msg.packet.CreateData());
				},
				(ClientEndMessage) {
					return;
				}
			);
		}

		send(parentTid, ClientEndMessage(thisTid));
	}

	void SendData(ubyte[] pdata) {
		ubyte[] data = pdata.dup; // NOTE: might cause slowdown, try removing this if slow
		if (data.length == 0) return;

		socket.blocking = true;

		while (data.length > 0) {
			auto len = socket.send(cast(void[]) data);

			if (len == Socket.ERROR) {
				active = false;
				return;
			}

			data = data[len .. $];
		}

		socket.blocking = false;
	}

	void Update() {
		if (!socket.isAlive) {
			active = false;
			return;
		}
	}
}
