module mcyeti.player;

import std.file;
import std.path;
import std.json;
import std.format;

class Player {
	string   username;
	bool     banned;
	char     colour;
	string[] infractions;
	ulong    muteTime;
	bool     muted;
	string   nickname;
	uint     rank;
	string   title;
	string   ip;

	string GetDisplayName(bool includeTitle = false) {
		string ret;

		if (includeTitle && (title != "")) {
			ret ~= format("&f[%s&f] ", title);
		}

		ret ~= format("&%c%s", colour, nickname == ""? username : nickname);
		return ret;
	}

	JSONValue InfoJSON() {
		JSONValue ret = parseJSON("{}");

		ret["banned"] = banned;
		ret["colour"] = cast(string) [colour];

		JSONValue[] infractionsJSON;
		foreach (ref v ; infractions) {
			infractionsJSON ~= JSONValue(v);
		}

		ret["infractions"] = infractionsJSON;
		ret["muteTime"]    = cast(int) muteTime;
		ret["muted"]       = muted;
		ret["nickname"]    = nickname;
		ret["rank"]        = cast(int) rank;
		ret["title"]       = title;
		ret["ip"]          = ip;
		return ret;
	}

	void InfoFromJSON(JSONValue json) {
		banned = json["banned"].boolean;
		colour = json["colour"].str[0];

		infractions = [];
		foreach (ref v ; json["infractions"].array) {
			infractions ~= v.str;
		}
		
		muteTime = "muteTime" in json? json["muteTime"].integer : 1 << 31;
		muted    = json["muted"].boolean;
		nickname = json["nickname"].str;
		rank     = cast(uint) json["rank"].integer;
		title    = json["title"].str;
		ip       = "ip" in json? json["ip"].str : ip; // lol
	}

	string GetInfoPath() {
		return format("%s/players/%s.json", dirName(thisExePath()), username);
	}

	void ReloadInfo() {
		InfoFromJSON(readText(GetInfoPath()).parseJSON());
	}

	void SaveInfo() {
		std.file.write(GetInfoPath(), InfoJSON().toPrettyString());
	}
}
