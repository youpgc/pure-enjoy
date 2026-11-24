part of 'journey_flame_game.dart';

/// 新增妖王能力实现（承接 JourneyBossSkillCast 的 default 分支）。
/// 各自保留原著意象，机制复用弹道/预警/领域/负面态统一原语。
extension JourneyBossSkillsNew on JourneyFlameGame {
  void _dispatchNewSkill(
      JourneyMonsterComponent boss, String key, double dist) {
    final code = boss.model.code;
    final pos = boss.position;
    final p = player;
    switch (key) {
      case 'inner_core': // 黄袍怪·内丹宝珠：追踪弹命中短定身
        final aim = (p.position - pos).normalized();
        bossSkillLayer.castProjectile(pos, aim,
            speed: monsterParam(code, 'core_speed', 260),
            radius: monsterParam(code, 'core_radius', 14),
            life: monsterParam(code, 'core_life', 4),
            damage: boss.contactDamage * monsterParam(code, 'core_ratio', 0.5),
            effect: 'root',
            power: monsterParam(code, 'core_root', 1.0),
            color: const Color(0xFFE8C470),
            homing: true,
            owner: boss);
        break;
      case 'fake_body': // 狮猁怪·化形假王：召假身，本体获护罩
        _spawnDecoys(boss, monsterParam(code, 'decoy_count', 2).round());
        boss.grantWard(monsterParam(code, 'decoy_ward', 0.6));
        break;
      case 'water_prison': // 鼍龙·水牢：减速领域
        bossSkillLayer.castField(pos,
            radius: monsterParam(code, 'prison_range', 200),
            life: monsterParam(code, 'prison_sec', 5),
            tick: monsterParam(code, 'prison_tick', 0.5),
            effect: 'slow',
            power: monsterParam(code, 'prison_slow', 0.4),
            color: const Color(0xFF5E7F9A),
            owner: boss);
        break;
      case 'five_thunder': // 虎力大仙·五雷法：预警落雷，圈内眩晕
        final count = monsterParam(code, 'thunder_count', 2).round().clamp(1, 5);
        for (var i = 0; i < count; i++) {
          final target = i == 0
              ? p.position.clone()
              : p.position +
                  Vector2(
                    (rng.nextDouble() - 0.5) *
                        monsterParam(code, 'thunder_spread', 260),
                    (rng.nextDouble() - 0.5) *
                        monsterParam(code, 'thunder_spread', 260),
                  );
          bossSkillLayer.castTelegraph(target,
              radius: monsterParam(code, 'thunder_range', 90),
              delay: monsterParam(code, 'thunder_delay', 0.9) +
                  i * monsterParam(code, 'thunder_gap', 0.18),
              damage:
                  boss.contactDamage * monsterParam(code, 'thunder_ratio', 1.0),
              effect: 'hit',
              power: 0,
              color: const Color(0xFFB9C8E8),
              owner: boss);
        }
        break;
      case 'ice_seal': // 灵感大王·冰封：强化定身 + 破甲
        if (dist <= monsterParam(code, 'seal_range', 240)) {
          applyBossSkillEffect('root',
              power: monsterParam(code, 'seal_root', 1.4), owner: boss);
          applyBossSkillEffect('armor_break',
              power: monsterParam(code, 'seal_armor_break', 0.35),
              owner: boss);
        }
        break;
      case 'mirror': // 六耳猕猴·镜像：复制玩家一个已选槽为自己护罩/增伤
        final slots = weaponSlots.where((s) => s.level > 0).toList();
        if (slots.isNotEmpty) {
          final copy = slots[rng.nextInt(slots.length)];
          boss.grantWard(monsterParam(code, 'mirror_ward', 0.5) +
              copy.level * monsterParam(code, 'mirror_per_lv', 0.06));
          spawnFloatText(pos + Vector2(0, -boss.radius - 14),
              '镜像·${copy.code}', const Color(0xFFB07CD4));
        }
        break;
      case 'root_bind': // 劲节十八公·根系缠绕：定身 + 毒雾领域（战斗回血在 update）
        if (dist <= monsterParam(code, 'bind_range', 230)) {
          applyBossSkillEffect('root',
              power: monsterParam(code, 'bind_root', 1.2), owner: boss);
          bossSkillLayer.castField(pos,
              radius: monsterParam(code, 'thorn_range', 150),
              life: monsterParam(code, 'thorn_sec', 4),
              tick: monsterParam(code, 'thorn_tick', 1.0),
              effect: 'dot',
              power: monsterParam(code, 'thorn_sec', 4),
              rawDamage: boss.contactDamage *
                  monsterParam(code, 'thorn_ratio', 0.12),
              color: const Color(0xFF6E8A4A),
              owner: boss);
        }
        break;
      case 'golden_bag': // 黄眉大王·人种袋：范围吸拉 + 金铙护罩
        if (dist <= monsterParam(code, 'bag_range', 300)) {
          applyBossSkillEffect('pull',
              power: monsterParam(code, 'bag_pull', 220), owner: boss);
        }
        boss.grantWard(monsterParam(code, 'cymbal_ward', 0.8));
        break;
      case 'devour': // 红鳞大蟒·吞噬：近身强拉 + 高伤预警
        if (dist <= monsterParam(code, 'devour_range', 220)) {
          applyBossSkillEffect('pull',
              power: monsterParam(code, 'devour_pull', 260), owner: boss);
          bossSkillLayer.castTelegraph(p.position,
              radius: monsterParam(code, 'devour_radius', 100),
              delay: monsterParam(code, 'devour_delay', 0.6),
              damage: boss.contactDamage *
                  monsterParam(code, 'devour_ratio', 1.4),
              effect: 'hit',
              power: 0,
              color: const Color(0xFF8E2F3C),
              owner: boss);
        }
        break;
      case 'three_bells': // 赛太岁·紫金铃：三色轮转（灼烧/致盲/减速）
        _cycleBell(boss, code);
        break;
      case 'spear_thrust': // 白鹿精·蟠龙拐：短前摇直线突刺（预警条）
        final aim = (p.position - pos).normalized();
        bossSkillLayer.castTelegraph(
            pos + aim * monsterParam(code, 'thrust_dist', 180),
            radius: monsterParam(code, 'thrust_width', 46),
            delay: monsterParam(code, 'thrust_windup', 0.45),
            damage: boss.contactDamage *
                monsterParam(code, 'thrust_ratio', 1.1),
            effect: 'hit',
            power: 0,
            color: const Color(0xFFC9A86A),
            owner: boss);
        break;
      case 'earth_trap': // 地涌夫人·地陷：短定身 + 减速领域
        bossSkillLayer.castField(pos,
            radius: monsterParam(code, 'trap_range', 170),
            life: monsterParam(code, 'trap_sec', 4),
            tick: monsterParam(code, 'trap_tick', 0.8),
            effect: 'slow',
            power: monsterParam(code, 'trap_slow', 0.5),
            color: const Color(0xFF8A6A4A),
            owner: boss);
        if (dist <= monsterParam(code, 'trap_range', 170)) {
          applyBossSkillEffect('root',
              power: monsterParam(code, 'trap_root', 0.8), owner: boss);
        }
        break;
      case 'plum_flower': // 南山大王·分瓣梅花：多假身分兵 + 本体护罩
        _spawnDecoys(boss, monsterParam(code, 'decoy_count', 3).round());
        boss.grantWard(monsterParam(code, 'ambush_ward', 0.5));
        break;
      case 'nine_seize': // 九灵元圣·九头衔人：超长拉拽 + 群体短定身
        final reach = monsterParam(code, 'seize_range', 460);
        if (dist <= reach) {
          applyBossSkillEffect('pull',
              power: monsterParam(code, 'seize_pull', 400), owner: boss);
          applyBossSkillEffect('root',
              power: monsterParam(code, 'seize_root', 1.0), owner: boss);
        }
        break;
      case 'ice_charge': // 辟寒大王·犀角冰撞：冲撞附带冰霜减速领域
        bossSkillLayer.castField(pos,
            radius: monsterParam(code, 'frost_range', 180),
            life: monsterParam(code, 'frost_sec', 5),
            tick: monsterParam(code, 'frost_tick', 0.6),
            effect: 'slow',
            power: monsterParam(code, 'frost_slow', 0.45),
            color: const Color(0xFF9FC8D8),
            owner: boss,
            followOwner: true);
        break;
      case 'moon_guard': // 玉兔精·捣药杵：蓄力重击 + 月华护盾
        bossSkillLayer.castTelegraph(p.position,
            radius: monsterParam(code, 'slam_range', 130),
            delay: monsterParam(code, 'slam_delay', 1.0),
            damage: boss.contactDamage *
                monsterParam(code, 'slam_ratio', 1.5),
            effect: 'hit',
            power: 0,
            color: const Color(0xFFE8D9B0),
            owner: boss);
        boss.grantWard(monsterParam(code, 'moon_ward', 0.7));
        break;
      case 'tiger_pounce': // 寅将军·猛虎扑击：短前摇预警落点 + 击退
        final radius = monsterParam(code, 'pounce_range', 120);
        final delay = monsterParam(code, 'pounce_delay', 0.8);
        // 伤害与击退同落点同前摇，命中判定一致；击退方向取妖王指向玩家
        bossSkillLayer.castTelegraph(p.position,
            radius: radius,
            delay: delay,
            damage:
                boss.contactDamage * monsterParam(code, 'pounce_ratio', 1.0),
            effect: 'hit',
            power: 0,
            color: const Color(0xFFC08A5A),
            owner: boss);
        bossSkillLayer.castTelegraph(p.position,
            radius: radius,
            delay: delay,
            damage: 0,
            effect: 'push',
            power: monsterParam(code, 'pounce_knockback', 180),
            color: const Color(0xFFC08A5A),
            owner: boss);
        break;
      case 'black_wind': // 黑熊精·黑风卷：跟随领域吸拉 + 致盲 + 减速
        bossSkillLayer.castField(boss.position,
            radius: monsterParam(code, 'wind_range', 200),
            life: monsterParam(code, 'wind_sec', 4),
            tick: monsterParam(code, 'wind_tick', 0.6),
            effect: 'pull',
            power: monsterParam(code, 'wind_pull', 120),
            color: const Color(0xFF5A5A6E),
            owner: boss,
            followOwner: true);
        applyBossSkillEffect('blind',
            power: monsterParam(code, 'blind_sec', 2.5), owner: boss);
        applyBossSkillEffect('slow',
            power: monsterParam(code, 'wind_slow', 0.3), owner: boss);
        break;
      case 'deer_belly': // 鹿力大仙·剖腹剜心：预警落点真伤 + 破甲
        bossSkillLayer.castTelegraph(p.position,
            radius: monsterParam(code, 'belly_range', 180),
            delay: monsterParam(code, 'belly_delay', 0.9),
            damage:
                boss.contactDamage * monsterParam(code, 'belly_ratio', 1.1),
            effect: 'true_hit',
            power: 0,
            color: const Color(0xFFC96A5A),
            owner: boss);
        applyBossSkillEffect('armor_break',
            power: monsterParam(code, 'belly_armor_break', 0.4), owner: boss);
        break;
      case 'ram_oil': // 羊力大仙·油锅炼狱：火系持续领域 + 油烟致盲
        bossSkillLayer.castField(boss.position,
            radius: monsterParam(code, 'oil_range', 200),
            life: monsterParam(code, 'oil_sec', 4),
            tick: monsterParam(code, 'oil_tick', 0.6),
            effect: 'fire_hit',
            power: 0,
            rawDamage:
                boss.contactDamage * monsterParam(code, 'oil_ratio', 0.18),
            color: const Color(0xFFE08A3C),
            owner: boss,
            followOwner: true);
        applyBossSkillEffect('blind',
            power: monsterParam(code, 'oil_blind', 2.0), owner: boss);
        break;
    }
  }

  void _cycleBell(JourneyMonsterComponent boss, String code) {
    final phase = boss._bellPhase % 3;
    boss._bellPhase++;
    switch (phase) {
      case 0: // 火铃：灼烧领域
        bossSkillLayer.castField(boss.position,
            radius: monsterParam(code, 'bell_range', 180),
            life: monsterParam(code, 'bell_sec', 4),
            tick: monsterParam(code, 'bell_tick', 1.0),
            effect: 'dot',
            power: monsterParam(code, 'bell_sec', 4),
            rawDamage: boss.contactDamage *
                monsterParam(code, 'bell_burn_ratio', 0.15),
            color: const Color(0xFFD4593F),
            owner: boss);
        break;
      case 1: // 烟铃：致盲
        applyBossSkillEffect('blind',
            power: monsterParam(code, 'bell_blind', 2.5), owner: boss);
        break;
      case 2: // 沙铃：减速
        applyBossSkillEffect('slow',
            power: monsterParam(code, 'bell_slow', 0.4), owner: boss);
        break;
    }
  }

  void _spawnDecoys(JourneyMonsterComponent boss, int count) {
    final n = count.clamp(1, 8);
    for (var i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 +
          rng.nextDouble() * monsterParam(boss.model.code, 'decoy_angle_jitter', 0.4);
      final r = monsterParam(boss.model.code, 'decoy_ring', 90.0) +
          rng.nextDouble() * monsterParam(boss.model.code, 'decoy_ring_jitter', 70.0);
      final comp = JourneyMonsterComponent(
        game: this,
        model: boss.model,
        buffMult: boss.buffMult,
        position: boss.position + Vector2(math.cos(a), math.sin(a)) * r,
      );
      comp.isDecoy = true;
      comp.decoyLife = monsterParam(
          boss.model.code, 'decoy_sec', 6.0);
      comp.hp = comp.maxHp * monsterParam(boss.model.code, 'decoy_hp', 0.12);
      monsters.add(comp);
      world.add(comp);
    }
    spawnFloatText(boss.position + Vector2(0, -boss.radius - 14), '变化术',
        const Color(0xFFB07CD4));
  }
}
