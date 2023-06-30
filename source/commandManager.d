module mcyeti.commandManager;

import std.format;
import mcyeti.util;
import mcyeti.client;
import mcyeti.server;
import mcyeti.commands;

class Command {
	string   name;
	string[] help;
	ubyte    argumentsRequired;
	ubyte    permission;
	abstract void Run(Server server, Client client, string[] args);
}

class CommandException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class CommandManager {
	Command[] commands;

	this() {
		LoadCommand(new HelpCommand());
		LoadCommand(new ShutdownCommand());
		LoadCommand(new InfoCommand());
		LoadCommand(new BanCommand());
		LoadCommand(new UnbanCommand());
		LoadCommand(new IPBanCommand());
		LoadCommand(new IPUnbanCommand());
		LoadCommand(new ServerInfoCommand());
		LoadCommand(new RanksCommand());
		LoadCommand(new PerbuildCommand());
		LoadCommand(new PervisitCommand());
		LoadCommand(new GotoCommand());
		LoadCommand(new NewLevelCommand());
		LoadCommand(new LevelsCommand());
		LoadCommand(new PlayersCommand());
	}

	void LoadCommand(Command command) {
		commands ~= command;
	}

	Command GetCommand(string name) {
		foreach (ref command ; commands) {
			if (command.name.LowerString() == name.LowerString()) {
				return command;
			}
		}

		throw new CommandException("No such command");
	}

	bool CommandExists(string name) {
		foreach (ref command ; commands) {
			if (command.name.LowerString() == name.LowerString()) {
				return true;
			}
		}

		return false;
	}
	
	bool CanRunCommand(string name, Client client) {
		auto command = GetCommand(name);

		return client.info["rank"].integer >= command.permission;
	}

	void RunCommand(string name, Server server, Client client, string[] args) {
		foreach (ref command ; commands) {
			if (command.name.LowerString() == name.LowerString()) {
				if (args.length < command.argumentsRequired) {
					throw new CommandException(format(
						"&cExpected at least %d arguments, found %d", command.argumentsRequired, args.length));
				}
				command.Run(server, client, args);

				return;
			}
		}

		throw new CommandException("No such command");
	}
}
