import 'dart:math';

import './sheep_tile.dart';

/// 羊了个羊「牌堆布局」生成器（从 sheep_game 抽出，保持单文件精简）。
///
/// 观感目标（对齐微信小程序原版）：所有方块**聚成一团**，层与层之间错开半格
/// 形成真实遮挡堆叠，而不是散落在大网格里、彼此留出大片空隙。
///
/// 旧实现缺陷（已修）：网格边长按 `perLayer * overlap` 推算出 9×9=81 格，
/// 每层只随机取 8 格 → 方块被稀疏地撒在大范围内，中间空隙极大。
/// 新实现改为「格子数 ≈ 块数 × 1.3」的紧凑网格，并优先取靠近中心的格子。
class SheepLayout {
  /// 层数
  final int layers;

  /// 层间错位比例（0.55~0.95）：越接近 0.5 的倍数，上层越均匀地压住下层四块交界
  final double overlap;

  final Random rng;

  const SheepLayout({
    required this.layers,
    required this.overlap,
    required this.rng,
  });

  /// 生成 [total] 个方块的位置：返回 (层号, x, y)，坐标以「块宽 = 1」为单位。
  ///
  /// 布局策略：
  /// 1. 每层块数自底向上递减（金字塔堆叠观感），底层最厚。
  /// 2. 每层用边长 ≈ sqrt(块数 × 1.3) 的**紧凑正方网格**，格心间距 1.0（同层紧贴不重叠）。
  /// 3. 候选格按「到该层中心的距离」升序取用 → 团簇成形，不会散落到四角。
  /// 4. 层与层整体错位 (l × overlap × 0.5) mod 1.0，且各层居中对齐 →
  ///    上层方块压住下层交界处，产生原版的遮挡关系。
  List<(int, double, double)> generate(int total) {
    final counts = _splitByLayer(total);
    // 以最厚一层的网格边长为基准，让各层居中叠放（否则上层会偏到左上角）
    final baseSide = _sideFor(counts.isEmpty ? total : counts.first);
    final shift = overlap * 0.5;

    final positions = <(int, double, double)>[];
    for (var l = 0; l < layers; l++) {
      final n = counts[l];
      if (n <= 0) continue;
      final side = _sideFor(n);
      final off = (l * shift) % 1.0; // 层错位，取模避免层数多时整体漂移
      final pad = (baseSide - side) / 2.0; // 居中对齐到基准层
      final center = (side - 1) / 2.0;

      // (到中心距离², x, y)
      final cells = <(double, double, double)>[];
      for (var cx = 0; cx < side; cx++) {
        for (var cy = 0; cy < side; cy++) {
          final dx = cx - center;
          final dy = cy - center;
          cells.add((dx * dx + dy * dy, cx + off + pad, cy + off + pad));
        }
      }
      cells.sort((a, b) => a.$1.compareTo(b.$1));

      // 取最靠中心的 n+2 个格子后打乱，保证「成团」同时保留随机性
      final pool = cells.take(min(cells.length, n + 2)).toList()
        ..shuffle(rng);
      for (var k = 0; k < n && k < pool.length; k++) {
        positions.add((l, pool[k].$2, pool[k].$3));
      }
    }

    // 数量兜底：多则截断，少则补在底层中心附近（极端配置下才会走到）
    while (positions.length > total) {
      positions.removeLast();
    }
    while (positions.length < total) {
      positions.add((
        0,
        (baseSide - 1) / 2.0 + rng.nextDouble() - 0.5,
        (baseSide - 1) / 2.0 + rng.nextDouble() - 0.5,
      ));
    }

    positions.sort((a, b) => a.$1.compareTo(b.$1));
    return positions;
  }

  /// 紧凑网格边长：格子数约为块数的 1.3 倍（留少量空位产生自然的不规则边缘）
  int _sideFor(int n) => max(2, sqrt(n * 1.3).ceil());

  /// 每层块数分配：自底向上递减，底层权重最大
  List<int> _splitByLayer(int total) {
    final weights = <double>[
      for (var l = 0; l < layers; l++) 1.0 + (layers - 1 - l) * 0.35,
    ];
    final sum = weights.reduce((a, b) => a + b);
    final counts = <int>[];
    var assigned = 0;
    for (var l = 0; l < layers; l++) {
      final n = l == layers - 1
          ? total - assigned
          : (total * weights[l] / sum).round();
      counts.add(max(0, n));
      assigned += counts[l];
    }
    return counts;
  }
}

/// 遮挡与可解性判定（纯函数集合，供生成期校验与运行期共用）。
class SheepSolver {
  /// 槽位容量
  final int slotCapacity;

  const SheepSolver({this.slotCapacity = 7});

  /// 两块是否在平面上相交（块宽 = 1）
  static bool rectsOverlap(SheepTile a, SheepTile b) =>
      a.x < b.x + 1 && a.x + 1 > b.x && a.y < b.y + 1 && a.y + 1 > b.y;

  /// 重算遮挡：仅当存在**更高层**且相交的在场方块时，该块被遮挡（不可点）。
  static void computeCoverage(List<SheepTile> list) {
    for (final t in list) {
      if (t.state == SheepTileState.board) t.covered = false;
    }
    for (final a in list) {
      if (a.state != SheepTileState.board) continue;
      for (final b in list) {
        if (b.layer > a.layer &&
            b.state == SheepTileState.board &&
            rectsOverlap(a, b)) {
          a.covered = true;
          break;
        }
      }
    }
  }

  /// 贪心模拟校验可解性（优先补齐三连，其次拿新类型），槽位溢出即判不可解。
  bool solvable(List<SheepTile> src) {
    final board =
        src.map((t) => SheepTile(t.id, t.type, t.layer, t.x, t.y)).toList();
    computeCoverage(board);
    final slots = <SheepTile>[];
    var guard = 0;
    while (guard++ < 10000) {
      final counts = <int, int>{};
      for (final s in slots) {
        counts[s.type] = (counts[s.type] ?? 0) + 1;
      }
      int? triple;
      for (final e in counts.entries) {
        if (e.value >= 3) {
          triple = e.key;
          break;
        }
      }
      if (triple != null) {
        var r = 0;
        slots.removeWhere((s) {
          if (s.type == triple && r < 3) {
            r++;
            return true;
          }
          return false;
        });
        continue;
      }
      final uncovered = board
          .where((t) => t.state == SheepTileState.board && !t.covered)
          .toList();
      if (uncovered.isEmpty) break;
      SheepTile? pick;
      for (final t in uncovered) {
        if ((counts[t.type] ?? 0) == 2) {
          pick = t;
          break;
        }
      }
      pick ??= uncovered.firstWhere(
        (t) => (counts[t.type] ?? 0) == 1,
        orElse: () => uncovered.first,
      );
      slots.add(pick);
      pick.state = SheepTileState.slot;
      computeCoverage(board);
      if (slots.length > slotCapacity) return false;
    }
    return slots.isEmpty;
  }
}
