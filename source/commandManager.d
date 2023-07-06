module mcyeti.commandManager;

import std.json;
import std.format;
import mcyeti.util;
import mcyeti.client;
import mcyeti.server;
import mcyeti.commands.info;
import mcyeti.commands.other;
import mcyeti.commands.world;
import mcyeti.commands.building;
import mcyeti.commands.moderation;

enum CommandCategory {
	Info,
	Moderation,
	Other,
	World,
	Building,

	End
}

class Command {
	string          name;
	string[]        help;
	ubyte           argumentsRequired;
	ubyte           permission;
	CommandCategory category;
	abstract void Run(Server server, Client client, string[] args);
}

class CommandException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class CommandManager {
	Command[]      commands;
	string[string] aliases;

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
		LoadCommand(new BlockInfoCommand());
		LoadCommand(new AddAliasCommand());
		LoadCommand(new CuboidCommand());
	}

	CommandCategory ToCategory(string str) {
		switch (str.LowerString()) {
			case "info": {
				return CommandCategory.Info;
			}
			case "moderation": {
				return CommandCategory.Moderation;
			}
			case "other": {
				return CommandCategory.Other;
			}
			case "world": {
				return CommandCategory.World;
			}
			default: {
				throw new CommandException("No such category");
			}
		}
	}

	void LoadCommand(Command command) {
		commands ~= command;
	}

	bool AliasExists(string name) {
		return name.LowerString() in aliases? true : false;
	}

	void LoadAliases(JSONValue json) {
		foreach (key, value ; json.object) {
			aliases[key] = value.str;
		}
	}

	JSONValue SerialiseAliases() {
		JSONValue ret = parseJSON("{}");

		foreach (key, value ; aliases) {
			ret[key] = JSONValue(value);
		}

		return ret;
	}

	Command GetCommand(string name) {
		if (AliasExists(name)) {
			name = aliases[name.LowerString()];
		}
	
		foreach (ref command ; commands) {
			if (command.name.LowerString() == name.LowerString()) {
				return command;
			}
		}

		throw new CommandException("No such command");
	}

	bool CommandExists(string name) {
		if (AliasExists(name)) {
			name = aliases[name.LowerString()];
		}
	
		foreach (ref command ; commands) {
			if (command.name.LowerString() == name.LowerString()) {
				return true;
			}
		}

		return false;
	}
	
	bool CanRunCommand(string name, Client client) {
		if (AliasExists(name)) {
			name = aliases[name.LowerString()];
		}
	
		auto command = GetCommand(name);

		return client.info["rank"].integer >= command.permission;
	}

	void RunCommand(string name, Server server, Client client, string[] args) {
		if (AliasExists(name)) {
			name = aliases[name.LowerString()];
		}
	
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
