module mcyeti.server;

import std.stdio;
import mcyeti.util;
import mcyeti.client;

shared int serverTicks;

struct ServerTickMessage {}

struct ServerConfig {
	string ip;
	ushort port;
}

class Server {
	bool         running;
	Socket       socket;
	ServerConfig config;
	Tid[]        clients; 

	this() {
		config.ip   = "0.0.0.0";
		config.port = 25565;
	}

	static Server Instance() {
		static Server instance;

		if (!instance) {
			instance = new Server();
		}

		return instance;
	}

	void Init() {
		assert(!running);

		socket = new Socket(AddressFamily.INET, SocketType.STREAM);
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
		socket.blocking = false;

		version (Posix) {
			socket.setOption(
				SocketOptionLevel.SOCKET, cast(SocketOption) SO_REUSEPORT, 1
			);
		}

		try {
			socket.bind(new InternetAddress(config.ip, config.port));
		}
		catch (SocketOSException e) {
			stderr.writefln("Failed to bind socket: %s", e.msg);
		}

		socket.listen(50);

		Log("Listening at %s:%d", config.ip, config.port);
		running = true;
	}

	void AcceptNewConnection() {
		bool   accepted = false;
		Socket newSocket;

		try {
			newSocket = socket.accept();
		}
		catch (SocketAcceptException) {
			accepted = false;
		}

		version (Windows) {
			if (!newSocket.isAlive()) {
				accepted = false;
			}
		}

		if (!accepted) return;

		Log("%s connected to the server", newSocket.remoteAddress.toAddrString());
		newSocket.socket.blocking = false;
	}

	void Update() {
		++ serverTicks;
	}
}
