import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'journey_flame_game.dart';
import '../widgets/journey_theme.dart';

/// 大地图上的怪物标记类型（决定点色与大小）。
enum JourneyWorldMonsterKind { normal, elite, boss }

/// 大地图快照中的单只怪物（绝对世界坐标，暂停时一次性抓取）。
class JourneyWorldMonster {
  const JourneyWorldMonster({
    required this.x,
    required this.y,
    required this.kind,
  });

  final double x;
  final double y;
  final JourneyWorldMonsterKind kind;
}

/// 大地图快照中的刷怪区域（妖穴/安全谷热区，绝对坐标+半径）。
class JourneyWorldZone {
  const JourneyWorldZone({
    required this.kind,
    required this.x,
    required this.y,
    required this.radius,
  });

  /// demon_den=妖穴（刷怪集中）/ safe_valley=安全谷（不刷怪）。
  final String kind;
  final double x;
  final double y;
  final double radius;
}

/// 西行舆图快照：打开弹窗时对局已暂停，一次性抓取全图绝对坐标，
/// 弹窗生命周期内只读快照、不回读引擎（暂停态世界静止，无需逐帧采样）。
class JourneyWorldMapSnapshot {
  const JourneyWorldMapSnapshot({
    required this.worldSize,
    required this.playerPos,
    required this.heading,
    required this.monsters,
    required this.zones,
    required this.bossHome,
  });

  /// 地图边长（世界坐标 0~worldSize）。
  final double worldSize;

  /// 玩家绝对世界坐标。
  final Offset playerPos;

  /// 玩家朝向（弧度，取渲染朝向，暂停保留最后方向）。
  final double heading;

  /// 全图存活怪物（无近距/60 只上限）。
  final List<JourneyWorldMonster> monsters;

  /// 刷怪热区（妖穴/安全谷全标）。
  final List<JourneyWorldZone> zones;

  /// 妖王据点绝对坐标（空 = 本关无据点妖王：无尽/每日游历/无妖章回）。
  final Offset? bossHome;

  /// 从引擎采集快照：怪物取全部存活实体（绝对坐标），热区取运行时配置，
  /// 玩家朝向取渲染朝向（暂停保留最后方向，不受摇杆输入清空影响）。
  static JourneyWorldMapSnapshot collect(JourneyFlameGame game) {
    final monsters = <JourneyWorldMonster>[];
    for (final m in game.monsters) {
      if (m.isDead) continue;
      monsters.add(
        JourneyWorldMonster(
          x: m.position.x,
          y: m.position.y,
          kind: m.model.isBoss
              ? JourneyWorldMonsterKind.boss
              : (m.model.isElite
                  ? JourneyWorldMonsterKind.elite
                  : JourneyWorldMonsterKind.normal),
        ),
      );
    }
    final zones = <JourneyWorldZone>[];
    for (final z in game.runtime.heatZones) {
      zones.add(
        JourneyWorldZone(
          kind: z.kind,
          x: z.x,
          y: z.y,
          radius: z.radius,
        ),
      );
    }
    // 朝向取玩家渲染朝向（暂停保留最后方向，不受摇杆清空影响）。
    final facing = game.player.facing;
    final heading = math.atan2(facing.y, facing.x);

    return JourneyWorldMapSnapshot(
      worldSize: game.worldSize,
      playerPos: Offset(game.player.position.x, game.player.position.y),
      heading: heading,
      monsters: monsters,
      zones: zones,
      // 据点只在有据点妖王的关卡标注：无妖章回/无尽/每日游历 bossModel 为
      // null（resolveBossCode 口径），此时 bossPos 仅是初始化坐标，非真实据点。
      bossHome: game.bossModel == null
          ? null
          : Offset(game.bossPos.x, game.bossPos.y),
    );
  }
}

/// 西行舆图弹窗：对局页先进入暂停态再展示，弹窗只读快照不改引擎状态。
/// 样式与属性面板统一（BottomSheet + 深墨底 + 鎏金描边 + 把手）。
abstract final class JourneyWorldMapSheet {
  static Future<void> show(
    BuildContext context, {
    required JourneyWorldMapSnapshot snapshot,
  }) async {
    final monsterCount = snapshot.monsters.length;
    final bossCount = snapshot.monsters
        .where((m) => m.kind == JourneyWorldMonsterKind.boss)
        .length;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: JourneyTheme.bgDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: JourneyTheme.panelStroke),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: JourneyTheme.gold.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('西 行 舆 图', style: JourneyTheme.titleLg),
              const SizedBox(height: 4),
              Text(
                '存活怪物 $monsterCount · 妖王 $bossCount',
                style: JourneyTheme.caption,
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(painter: _WorldMapPainter(snapshot)),
              ),
              const SizedBox(height: 10),
              const _Legend(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 图例：区域（妖穴/安全谷/妖王据点）与怪物三色点。
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: <Widget>[
        _LegendItem(color: Color(0x66D4593F), label: '妖穴(刷怪集中)'),
        _LegendItem(color: Color(0x665B9BD5), label: '安全谷(不刷怪)'),
        _LegendItem(color: JourneyTheme.gold, label: '妖王据点'),
        _LegendItem(color: Color(0xFFD4593F), label: '小妖'),
        _LegendItem(color: Color(0xFFE8A24C), label: '精英'),
        _LegendItem(color: Color(0xFF8E2F3C), label: '妖王'),
        _LegendItem(color: Colors.white, label: '我方'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: JourneyTheme.panelStroke),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: JourneyTheme.caption),
      ],
    );
  }
}

/// 舆图画笔：世界方形底 + 边界墙，热区按半径半透明填充，
/// 怪物三色点（妖王白描边），玩家白色朝向箭头，据点金色菱形。
class _WorldMapPainter extends CustomPainter {
  const _WorldMapPainter(this.snapshot);

  final JourneyWorldMapSnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    final world = snapshot.worldSize <= 0 ? 1.0 : snapshot.worldSize;
    final k = side / world;
    Offset toMap(double x, double y) => origin + Offset(x * k, y * k);

    // 地图底 + 边界墙（金色细线）
    final rect = Rect.fromLTWH(origin.dx, origin.dy, side, side);
    canvas.drawRect(
      rect,
      Paint()..color = JourneyTheme.bgBase,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = JourneyTheme.gold.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // 刷怪区域：妖穴暖红 / 安全谷青蓝，半透明填充 + 描边
    for (final z in snapshot.zones) {
      final isDen = z.kind == 'demon_den';
      final fill = isDen
          ? const Color(0x66D4593F)
          : const Color(0x665B9BD5);
      final stroke = isDen
          ? const Color(0xB3D4593F)
          : const Color(0xB35B9BD5);
      final c = toMap(z.x, z.y);
      canvas.drawCircle(
        c,
        z.radius * k,
        Paint()..color = fill,
      );
      canvas.drawCircle(
        c,
        z.radius * k,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // 妖王据点：金色菱形（无据点妖王的关卡不标）
    final home = snapshot.bossHome;
    if (home != null) {
      final c = toMap(home.dx, home.dy);
      final diamond = Path()
        ..moveTo(c.dx, c.dy - 7)
        ..lineTo(c.dx + 7, c.dy)
        ..lineTo(c.dx, c.dy + 7)
        ..lineTo(c.dx - 7, c.dy)
        ..close();
      canvas.drawPath(diamond, Paint()..color = JourneyTheme.gold);
    }

    // 怪物三色点：小妖红 / 精英橙 / 妖王深红 + 白描边
    for (final m in snapshot.monsters) {
      final c = toMap(m.x, m.y);
      switch (m.kind) {
        case JourneyWorldMonsterKind.normal:
          canvas.drawCircle(c, 2.5, Paint()..color = const Color(0xFFD4593F));
          break;
        case JourneyWorldMonsterKind.elite:
          canvas.drawCircle(c, 3.8, Paint()..color = const Color(0xFFE8A24C));
          break;
        case JourneyWorldMonsterKind.boss:
          canvas.drawCircle(c, 5.5, Paint()..color = const Color(0xFF8E2F3C));
          canvas.drawCircle(
            c,
            5.5,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
          break;
      }
    }

    // 玩家：白色朝向箭头
    final pc = toMap(snapshot.playerPos.dx, snapshot.playerPos.dy);
    canvas.save();
    canvas.translate(pc.dx, pc.dy);
    canvas.rotate(snapshot.heading + math.pi / 2);
    final arrow = Path()
      ..moveTo(0, -8)
      ..lineTo(5.5, 6)
      ..lineTo(0, 3)
      ..lineTo(-5.5, 6)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter old) =>
      old.snapshot != snapshot;
}
