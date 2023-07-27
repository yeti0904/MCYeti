module mcyeti.types;

import std.format;
import std.math.exponential;

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

	double DistanceToNoSqrt(Vec3!T vec) {
		double x1 = cast(double) x;
		double y1 = cast(double) y;
		double z1 = cast(double) z;

		double x2 = cast(double) vec.x;
		double y2 = cast(double) vec.y;
		double z2 = cast(double) vec.z;

		return pow(x2 - x1, 2) + pow(y2 - y1, 2) + pow(z2 - z1, 2);
	}

	string toString() {
		return format("(%s, %s, %s)", x, y, z);
	}
}

struct Dir3D {
	ubyte yaw, heading;
}
