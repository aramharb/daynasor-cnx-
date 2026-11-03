import 'dart:ui';

import 'world.dart';

enum ObstacleKind { ground, flyer, meteor }

class Flung {
  Flung(this.vx, this.vy, this.vr);
  double vx, vy, rot = 0, vr;
}

class Obstacle {
  Obstacle({
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.n = 1,
    this.seed = 0,
    this.skin = 'cactus',
    this.biome,
    this.vx = 0,
    this.vy = 0,
  });

  ObstacleKind kind;
  double x, y, w, h;
  int n;
  double seed;
  String skin;
  Biome? biome;
  double vx, vy;
  bool dead = false;
  bool claimed = false;
  Flung? flung;
}

class Coin {
  Coin(this.x, this.y, {this.vy = 0});
  double x, y, vy;
  bool taken = false;
}

class Powerup {
  Powerup(this.type, this.x, this.y);
  final String type;
  double x, y;
  bool taken = false;
}

class Bone {
  Bone(this.x, this.y);
  double x, y;
  bool taken = false;
}

class Ring {
  Ring(this.x, this.y, this.max, this.color, this.life);
  double x, y, max, life, t = 0, r = 10;
  final Color color;
}

class Particle {
  Particle({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.g = 0,
    required this.life,
    double? max,
    this.size = 2,
    this.color = const Color(0xFFFFFFFF),
    this.text,
    this.weather = false,
    this.circle = false,
    this.streak = false,
    this.rain = false,
    this.rot,
  }) : max = max ?? life;

  double x, y, vx, vy, g, life, max, size;
  Color color;
  final String? text;
  final bool weather, circle, streak, rain;
  double? rot;
}

enum ShotKind { venom, fireball }

class Shot {
  Shot.venom({required this.x, required this.y, required this.vx, required this.vy, required this.life})
      : kind = ShotKind.venom,
        sx = 0,
        sy = 0,
        tx = 0,
        ty = 0,
        dur = 1;
  Shot.fireball({required this.sx, required this.sy, required this.tx, required this.ty, required this.dur})
      : kind = ShotKind.fireball,
        x = sx,
        y = sy,
        vx = 0,
        vy = 0,
        life = 99;

  final ShotKind kind;
  double x, y, vx, vy, life;
  double sx, sy, tx, ty, dur;
  double t = 0;
}

class Bolt {
  Bolt(this.x1, this.y1, this.x2, this.y2, this.life, this.seed);
  double x1, y1, x2, y2, life, seed;
}

class Ally {
  Ally({required this.kind, required this.i, required this.x, required this.y, this.sp = 0});
  final String kind; // 'raptor' | 'tricera'
  final int i;
  double x, y, vy = 0, sp;
  Obstacle? target;
  int frame = 0;
  double frameT = 0;
}
