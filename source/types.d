module mcyeti.types;

import std.format;

struct Vec3(T) {
	T x, y, z;

	this(T px, T py, T pz) {
		x = px;
		y = py;
		z = pz;
	}

	Vec3!T2 CastTo(T2)() {
		return Vec3!T2(
			cast(T2) x,
			cast(T2) y,
			cast(T2) z
		);
	}

	string toString() {
		return format("(%s, %s, %s)", x, y, z);
	}
}

struct Dir3D {
	ubyte yaw, heading;
}
