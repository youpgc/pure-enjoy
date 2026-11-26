part of 'journey_flame_game.dart';

/// 掉落与拾取：击杀产出（香火=经验/功德铜钱/蟠桃/宝箱 + 后期分档
/// 妖丹=大经验/灵珠=大治疗/功德金锭=大额功德），磁吸拾取。
enum JourneyPickupKind {
  exp,
  meritCoin,
  peach,
  chest,
  yaodan,
  lingzhu,
  jinding,
  shield,
}

class JourneyPickupComponent extends PositionComponent {
  JourneyPickupComponent({
    required this.game,
    required this.kind,
    required super.position,
    required this.value,
    String? spriteKey,
  })  : spriteKey = spriteKey ?? _defaultSpriteKey(kind);

  final JourneyFlameGame game;
  final JourneyPickupKind kind;

  /// 图标资源键：优先取后台拾取物 code 的专属资源，缺省按结算类别回落。
  /// 对象池复用时同步重置（见 JourneyLootMixin._spawnPickup）。
  String spriteKey;

  /// 拾取价值（可变：对象池复用时重置，见 JourneyLootMixin._spawnPickup）。
  int value;

  /// 渲染/碰撞半径：按当前 kind 与图标键动态计算，对象池复用时随 spriteKey 同步刷新。
  double get _radius => kind == JourneyPickupKind.chest ||
          kind == JourneyPickupKind.jinding ||
          spriteKey == 'jinding'
      ? 13
      : 8;

  @override
  void update(double dt) {
    super.update(dt);
    if (game._ended) return;
    final player = game.player;
    final to = player.position - position;
    final dist = to.length;

    // 磁吸：进入拾取范围后飞向玩家
    if (dist < player.pickupRange) {
      final speed = 180 + (player.pickupRange - dist) * 3;
      if (dist > 1) {
        position += to.normalized() * speed * dt;
      }
    }
    if (dist < 20) {
      _collect();
    }
  }

  /// 拾取结算（对象池，节点12）：效果入账后移出父级并入池（复用时 reset）。
  void _collect() {
    switch (kind) {
      case JourneyPickupKind.exp:
        game.gainExp(value.toDouble());
        break;
      case JourneyPickupKind.meritCoin:
        game.addMeritCoins(value);
        break;
      case JourneyPickupKind.peach:
        game.player.heal(value.toDouble());
        break;
      case JourneyPickupKind.chest:
        // 宝箱流水线（§6 炼化/额外三选一/功德兜底）
        game.handleChestCollected();
        break;
      case JourneyPickupKind.yaodan:
        game.gainExp(value.toDouble());
        break;
      case JourneyPickupKind.lingzhu:
        game.player.heal(value.toDouble());
        break;
      case JourneyPickupKind.jinding:
        game.addMeritCoins(value);
        break;
      case JourneyPickupKind.shield:
        game.player.gainShield(value.toDouble());
        break;
    }
    game._recyclePickup(this);
  }

  @override
  void render(Canvas canvas) {
    // 精灵优先（pickup_<spriteKey>.svg，48 视箱）；失败回落色块
    final pic = JourneySprites.get(JourneySprites.pickup(spriteKey));
    if (pic != null) {
      final size = _radius * 2.4;
      JourneySprites.draw(
        canvas,
        pic,
        dstRect: Rect.fromCenter(
          center: Offset.zero,
          width: size,
          height: size,
        ),
        srcWidth: 48,
        srcHeight: 48,
      );
      return;
    }
    final paint = Paint()
      ..color = switch (kind) {
        JourneyPickupKind.exp => const Color(0xFF9C7BD5),
        JourneyPickupKind.meritCoin => const Color(0xFFE8C470),
        JourneyPickupKind.peach => const Color(0xFFD4593F),
        JourneyPickupKind.chest => const Color(0xFFB98F3E),
        JourneyPickupKind.yaodan => const Color(0xFF6C4BD5),
        JourneyPickupKind.lingzhu => const Color(0xFF5BC4B0),
        JourneyPickupKind.jinding => const Color(0xFFE8A83E),
        JourneyPickupKind.shield => const Color(0xFF6FA8DC),
      };
    canvas.drawCircle(Offset.zero, _radius, paint);
    if (kind == JourneyPickupKind.chest) {
      canvas.drawCircle(
        Offset.zero,
        _radius + 3,
        Paint()
          ..color = const Color(0xFFE8C470)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }
}

mixin JourneyLootMixin {
  /// 拾取物对象池（节点12 性能）：按 kind 回收复用，避免高频掉落实例化
  /// 抖动。池随对局实例存在（game 引用绑定单局，跨局不串）。
  final Map<JourneyPickupKind, List<JourneyPickupComponent>> _pickupPool =
      <JourneyPickupKind, List<JourneyPickupComponent>>{};

  /// 统一生成入口：池空新建，池非空取尾复用（reset 位置/数值后重新挂载）。
  void _spawnPickup(
    JourneyFlameGame game,
    JourneyPickupKind kind,
    Vector2 pos,
    int value, {
    String? spriteKey,
  }) {
    final pool =
        (_pickupPool[kind] ??= <JourneyPickupComponent>[]);
    final reused = pool.isNotEmpty ? pool.removeLast() : null;
    final resolvedSprite = spriteKey ?? _defaultSpriteKey(kind);
    final p = reused
      ?? JourneyPickupComponent(
          game: game,
          kind: kind,
          position: pos,
          value: value,
          spriteKey: resolvedSprite,
        );
    if (reused != null) {
      p
        ..position = pos
        ..value = value
        ..spriteKey = resolvedSprite;
    }
    game.pickups.add(p);
    game.world.add(p);
  }

  /// 回收入池：移出父级（主 update 的未挂载过滤会将其移出 pickups 列表）。
  void _recyclePickup(JourneyPickupComponent p) {
    p.removeFromParent();
    (_pickupPool[p.kind] ??= <JourneyPickupComponent>[]).add(p);
  }

  /// 击杀掉落（journey_drops 表驱动）：boss/精英/普通分表加权随机；
  /// 空表回落内置硬编码概率口径（香火必掉/铜钱 35%/蟠桃 4%）。
  ///
  /// - 经验单源=怪物经验基准，按生成时强度乘区缩放×(1+乘区×exp_mult_k)，
  ///   再乘无尽波次成长乘区（普通/精英/妖王统一参与，让整池随波扩张）；
  ///   妖王基准走独立值 exp_override，脱离「限血选怪」锁死的 exp_drop
  ///   低血档，其余怪用自身 exp_drop；drops 表 xianghuo 行 qty 不参与经验；
  /// - 精英掉落以经验为主，宝箱为低概率惊喜彩蛋
  ///   （elite_chest_rate 缺省 1%）：
  ///   drops 表的精英固定 baoxiang 行在此屏蔽（兜住种子/旧配置）；
  /// - 妖王宝箱：主线据点首杀必掉；无尽妖潮改波内首杀掷概率
  ///   （endless_boss_chest_rate 缺省 10%，后场妖王不掷）。
  void spawnLoot(JourneyFlameGame game, JourneyMonsterComponent m) {
    // 经验值：怪物行 exp_drop × 强度缩放（乘区=生成时钳制值，非当前值）
    // 发育期（妖潮起点前的无尽波次）再乘集中配置的经验倍率，撑起角色
    // 经验池，让妖王波前即可获得足够强化；妖潮期不加成。
    final expK = game.config?.expMultK ?? kJourneyExpMultK;
    final tideStart = _endlessTideStartWave(game);
    final developExp =
        game.level.kind == 'endless' &&
                tideStart != null &&
                m.endlessWave > 0 &&
                m.endlessWave < tideStart
            ? math.max(0.0, game.battleNum('endless', 'develop_exp_mult', 1.0))
            : 1.0;
    // 经验基准：妖王用降临写入的独立基准（脱离限血选怪表值），其余怪
    // 用自身 exp_drop；三类怪共用同一个无尽波次成长乘区，一起撑起经验池。
    final expBasis = m.expOverride > 0 ? m.expOverride : m.model.expDrop;
    final waveGain = game.level.kind == 'endless' && m.endlessWave > 0
        ? game.battleNum('endless', 'exp_wave_gain', kJourneyExpWaveGain)
        : 0.0;
    // 经验独立成长通道（仅主线/每日）：等级项随角色等级增长，时间项
    // 放大等级增量而非整条乘区，使成长从 1 连续起步、每级击杀需求缓慢
    // 上调；与强度乘区解耦，不改变怪物血量/速度/接触伤害。
    // 无尽需求走 lv^1.75 专属曲线、产出靠 waveGain 与发育期倍率成长，
    // 不叠加本通道，避免两套成长叠乘。
    final lvPow = game.config?.expLvPow ?? kJourneyExpLvPow;
    final baseLv = game.config?.expLvBaseLv ?? kJourneyExpLvBaseLv;
    final timeGain = game.config?.expTimeGain ?? kJourneyExpTimeGain;
    final gainCap = game.config?.expGainCap ?? kJourneyExpGainCap;
    // 等级项下限钳 1：基准等级及以下整条通道恒 1，前期产出与旧口径一致。
    final lvTerm = math.max(
      1.0,
      math.min(
        math.pow(math.max(1, game._charLv) / baseLv, lvPow).toDouble(),
        gainCap,
      ),
    );
    final expGrowth = game.level.kind == 'endless'
        ? 1.0
        : math.min(
            1 + (lvTerm - 1) * (1 + (game._elapsed / 60.0) * timeGain),
            gainCap,
          );
    final expValue = (expBasis *
            (1 + m.buffMult * expK) *
            expGrowth *
            developExp *
            (1 + waveGain * (m.endlessWave - 1)))
        .round();

    // 掉落分档：21+ 难切换 late 表（高价值拾取物权重上调）；
    // late 表缺行回落基础表（老配置不炸）。
    final base = m.model.isBoss
        ? 'monster_boss'
        : m.model.isElite
            ? 'monster_elite'
            : 'monster_normal';
    final isLateTier = game.level.levelNo > 20;
    final table = game.config?.dropTableOf(isLateTier ? '${base}_late' : base) ??
        const <JourneyDropModel>[];
    final effective =
        table.isNotEmpty ? table : game.config?.dropTableOf(base) ?? const <JourneyDropModel>[];
    // 宝箱口径迁移：精英行恒屏蔽（彩蛋化）；妖王行主线保持首杀必掉，
    // 无尽妖潮改**波内首杀掷概率**（endless_boss_chest_rate，全程期望
    // 约 9 箱）——波内击杀计数在本次结算内完成「判首杀→掷→递增」。
    final isEndless = game.level.kind == 'endless';
    final tideBossFirst =
        isEndless && m.model.isBoss && game._endlessBossKilled == 0;
    if (isEndless && m.model.isBoss) game._endlessBossKilled++;
    final tideChestHit = tideBossFirst &&
        game.rng.nextDouble() <
            (game.config?.endlessBossChestRate ??
                kJourneyEndlessBossChestRate);
    final bossFirstKill = m.model.isBoss && !isEndless && game._bossStage == 0;
    final keepBossChest = m.model.isBoss &&
        (isEndless ? tideChestHit : bossFirstKill);
    // 妖王表剔除香火行：经验走 expValue 单源在保底路径生成，避免
    // _rollDropTable 命中香火行造成经验双份（exp_drop 为唯一经验入口）。
    final rollTable = effective
        .where((d) =>
            (d.pickupCode != 'baoxiang' || keepBossChest) &&
            (!m.model.isBoss || d.pickupCode != 'xianghuo'))
        .toList();

    // 兜底口径（掉落表未就绪时保持可玩）
    void drop(JourneyPickupKind kind, int value) {
      _spawnPickup(
        game,
        kind,
        m.position.clone() +
            Vector2(
              (game.rng.nextDouble() - 0.5) * 24,
              (game.rng.nextDouble() - 0.5) * 24,
            ),
        value,
      );
    }

    if (rollTable.isNotEmpty) {
      _rollDropTable(game, rollTable, m.position.clone(), expValue: expValue);
      // 妖王保底经验：表内已剔除香火行，独立补一份 exp_drop 单源经验。
      if (m.model.isBoss && expValue > 0) {
        drop(JourneyPickupKind.exp, expValue);
      }
    } else {
      // 空表兜底已含 expValue 经验，妖王无需再补
      drop(JourneyPickupKind.exp, expValue);
      if (game.rng.nextDouble() <
          game.battleNum('economy', 'drop_coin_fallback', 0.35)) {
        drop(JourneyPickupKind.meritCoin, 3 + game.level.levelNo ~/ 2);
      }
      if (game.rng.nextDouble() <
          game.battleNum('economy', 'drop_peach_fallback', 0.04)) {
        drop(JourneyPickupKind.peach, 25);
      }
      if (keepBossChest) {
        drop(JourneyPickupKind.chest, 15);
      }
    }
    // 精英惊喜彩蛋：宝箱低概率掉落
    // （journey_battle_params.economy.elite_chest_rate，缺省 1%）
    if (m.model.isElite &&
        game.rng.nextDouble() <
            game.battleNum(
                'economy', 'elite_chest_rate', kJourneyEliteChestRate)) {
      drop(JourneyPickupKind.chest, 15);
    }
  }
}

/// 掉落表加权随机：weight=0 行跳过；pickup_code 空=什么都不掉；
/// 命中后按 pickup 编码映射生成拾取物（值=单价×随机数量）。
/// [expValue] 非空时覆盖 xianghuo 行的经验值（exp_drop 单源 × 强度缩放）。
void _rollDropTable(
  JourneyFlameGame game,
  List<JourneyDropModel> table,
  Vector2 pos, {
  int? expValue,
}) {
  var total = 0;
  for (final d in table) {
    if (d.weight > 0) total += d.weight;
  }
  if (total <= 0) return;
  var roll = game.rng.nextInt(total);
  JourneyDropModel? hit;
  for (final d in table) {
    if (d.weight <= 0) continue;
    if (roll < d.weight) {
      hit = d;
      break;
    }
    roll -= d.weight;
  }
  final code = hit?.pickupCode;
  if (code == null || code.isEmpty) return;
  final qtyMin = hit!.qtyMin < 0 ? 0 : hit.qtyMin;
  final qtyMax = hit.qtyMax < qtyMin ? qtyMin : hit.qtyMax;
  final qty = qtyMin + game.rng.nextInt(qtyMax - qtyMin + 1);
  if (qty <= 0) return; // 误配 0/0 行：不生成 0 价值拾取物
  // 香火经验走 expValue 单源（exp_drop × 强度缩放），表内 qty 不参与
  if (code == 'xianghuo' && expValue != null) {
    _spawnPickupByCode(game, code, pos, expValue);
    return;
  }
  _spawnPickupByCode(game, code, pos, qty);
}

/// 结算类别由后台拾取物 effect 驱动（exp/merit/heal/chest/shield），
/// 后台未配置该行时才回落到内置 code 映射；新增任意 code 只要后台配了
/// effect 即可生效，无需改引擎。图标优先取 code 专属资源，缺省按类别回落。
JourneyPickupKind? _kindOfEffect(String effect) => switch (effect) {
      'exp' => JourneyPickupKind.exp,
      'merit' => JourneyPickupKind.meritCoin,
      'heal' => JourneyPickupKind.peach,
      'chest' => JourneyPickupKind.chest,
      'shield' => JourneyPickupKind.shield,
      _ => null,
    };

JourneyPickupKind? _kindOfCode(String code) => switch (code) {
      'xianghuo' => JourneyPickupKind.exp,
      'gongde_tongqian' => JourneyPickupKind.meritCoin,
      'pantao_pickup' => JourneyPickupKind.peach,
      'baoxiang' => JourneyPickupKind.chest,
      'yaodan' => JourneyPickupKind.yaodan,
      'lingzhu' => JourneyPickupKind.lingzhu,
      'jinding' => JourneyPickupKind.jinding,
      'huxin_dan' => JourneyPickupKind.shield,
      _ => null,
    };

String _defaultSpriteKey(JourneyPickupKind kind) => switch (kind) {
      JourneyPickupKind.exp => 'xianghuo',
      JourneyPickupKind.meritCoin => 'coin',
      JourneyPickupKind.peach => 'peach',
      JourneyPickupKind.chest => 'chest',
      JourneyPickupKind.yaodan => 'yaodan',
      JourneyPickupKind.lingzhu => 'lingzhu',
      JourneyPickupKind.jinding => 'jinding',
      JourneyPickupKind.shield => 'huxin',
    };

/// code 专属图标键（保留妖丹/灵珠/金锭等大份拾取物的独立外观）。
String? _spriteKeyOfCode(String code) => switch (code) {
      'xianghuo' => 'xianghuo',
      'gongde_tongqian' => 'coin',
      'pantao_pickup' => 'peach',
      'baoxiang' => 'chest',
      'yaodan' => 'yaodan',
      'lingzhu' => 'lingzhu',
      'jinding' => 'jinding',
      'huxin_dan' => 'huxin',
      _ => null,
    };

void _spawnPickupByCode(
  JourneyFlameGame game,
  String code,
  Vector2 pos,
  int qty,
) {
  final config = game.config?.pickupConfigOf(code);
  // 结算类别：后台 effect 优先，未配置该行才回落内置 code 映射
  final kind = (config != null ? _kindOfEffect(config.effect) : null) ??
      _kindOfCode(code);
  if (kind == null) return;
  // 值=单价×数量；单价优先 pickupConfigOf（>0 生效，0 视为漏配），否则回落内置值
  final configured = config?.value ?? 0;
  final unit = configured > 0
      ? configured
      : switch (kind) {
        JourneyPickupKind.exp => 1,
        JourneyPickupKind.meritCoin => 3,
        JourneyPickupKind.peach => 15,
        JourneyPickupKind.chest => 0,
        JourneyPickupKind.yaodan => 30,
        JourneyPickupKind.lingzhu => 80,
        JourneyPickupKind.jinding => 30,
        JourneyPickupKind.shield => 40,
      };
  game._spawnPickup(
    game,
    kind,
    pos +
        Vector2(
          (game.rng.nextDouble() - 0.5) * 24,
          (game.rng.nextDouble() - 0.5) * 24,
        ),
    unit * qty,
    spriteKey: _spriteKeyOfCode(code),
  );
}
