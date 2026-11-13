part of 'journey_progress_service.dart';

/// 西行·角色专属天赋树逻辑拆分（part 同 library：访问宿主私有状态）。
///
/// v4 分支树制：点亮的前置校验与双消耗扣费入账。每角色一棵五行树
/// （5 系 × 16 层 = core 8/growth 5/sig 3 三分支 + 第 81 点加强点）。
/// 前置规则（生态循环）：
/// · 分支内按层序点亮；
/// · 枝间顺序：growth 开亮需本系 core≥3；sig 开亮需本系 core 修满 8；
/// · 相生阶梯锁：每系自第 2 层起，需「生我者」系总层数 ≥ 本系
///   点亮后总层数 − 1（即任一系最多比其生源系深 1 层；金→水→木→火→土→金，
///   借此打破五系闭环、避免循环死锁，仍保留按相生顺序节制的设计意图）；
/// · 相克制衡：sig 点亮需「克我者」系 ≥4 层；
/// · 加强点：五系修满 80 层后消耗第 81 点，解锁角色特殊能力。
extension JourneyProgressTalent on JourneyProgressService {
  /// 某角色全部分支行（配置快照优先，种子兜底）。
  List<JourneyTalentBranchModel> _branchesOf(String char) =>
      JourneyConfigService.instance.cached?.branchesOf(char) ??
      buildJourneyTalentBranchSeed()
          .where((row) => row['character_code'] == char)
          .map(JourneyTalentBranchModel.fromJson)
          .toList();

  /// 某角色某系某分支（快照缺失时按内置种子兜底，防消费侧死局）。
  JourneyTalentBranchModel _branchOf(
      String char, String element, String branch) {
    return JourneyConfigService.instance.cached?.branchOf(char, element, branch) ??
        _branchesOf(char).firstWhere(
          (x) => x.element == element && x.branchType == branch,
          orElse: () => JourneyTalentBranchModel(
              id: '',
              characterCode: char,
              element: element,
              branchType: branch,
              branchCode: journeyBranchCode(char, element, branch),
              name: branch,
              attrKey: branch),
        );
  }

  /// 点亮功德价：第 n 层 = cost_base × n（n=该分支已亮层数+1，分支内
  /// 线性递增）；加强点取固定封顶价。cost_base 远端缺失回落 30。
  int talentMeritCost(String char, String element, String branch) {
    if (branch == kJourneyTalentEnhanceKey) {
      // 加强点为里程碑式封顶价，与分支层数解耦
      return kJourneyTalentEnhanceCost;
    }
    final b = _branchOf(char, element, branch);
    final n = _state.talentLevelOf(char, b.branchCode) + 1;
    return b.costBase * n;
  }

  /// 点亮前置判定：[branch] = 分支类型（core/growth/sig）或加强点
  /// （'enhance'）。返回 null=可点亮，否则不可点亮原因文案。
  String? talentBlockReason(String char, String element, String branch) {
    final cost = talentMeritCost(char, element, branch);
    if (branch == kJourneyTalentEnhanceKey) {
      if (_state.talentEnhanceLit(char)) return '加强点已点亮';
      for (final e in kJourneyTalentElements) {
        if (_state.talentElementLv(char, e) < 16) return '需五系各修满 16 层';
      }
      return _poolOrMeritBlock(char, cost);
    }
    final b = _branchOf(char, element, branch);
    final lv = _state.talentLevelOf(char, b.branchCode);
    if (lv >= b.maxLv) return '该分支已修满';

    // 枝间顺序：growth 需本系 core≥3；sig 需本系 core 修满 8
    final coreLv = _state.talentLevelOf(
        char, journeyBranchCode(char, element, 'core'));
    if (branch == 'growth' && coreLv < 3) return '需本源枝点亮 3 层';
    if (branch == 'sig' && coreLv < kJourneyBranchMaxLv['core']!) {
      return '需本源枝修满 8 层';
    }
    // 相克制衡：sig 需「克我者」系 ≥4 层
    if (branch == 'sig') {
      final restrainer = JourneyProgressService.restrainerOf[element]!;
      final rLv = _state.talentElementLv(char, restrainer);
      if (rLv < 4) return '需「${_elementName(restrainer)}」系 ≥4 层';
    }
    // 相生阶梯锁：自第 2 层起需「生我者」系总层数 ≥ 点亮后本系总层数 − 1
    // （任一系最多比其生源系深 1 层；原 1:1 等深约束在五系闭环上会循环死锁）
    final myTotalNew = _state.talentElementLv(char, element) + 1;
    if (myTotalNew >= 2) {
      final generator = JourneyProgressService.generatorOf[element]!;
      final gLv = _state.talentElementLv(char, generator);
      if (gLv < myTotalNew - 1) {
        return '需「${_elementName(generator)}」系 ≥${myTotalNew - 1} 层';
      }
    }
    return _poolOrMeritBlock(char, cost);
  }

  /// 点数池与功德余额校验（共用尾巴）。
  String? _poolOrMeritBlock(String char, int cost) {
    if (_state.talentPool <= 0) {
      return '天赋点不足（关卡首通/击败妖王获取）';
    }
    if (_state.meritBalance < cost) return '功德不足（需 $cost 功德）';
    return null;
  }

  String _elementName(String element) => switch (element) {
        'metal' => '锐金',
        'wood' => '青木',
        'water' => '玄水',
        'fire' => '离火',
        'earth' => '厚土',
        _ => element,
      };

  /// 点亮一层（或加强点）：扣该角色 1 天赋点 + 功德（双消耗），落功德
  /// 流水并 best-effort 远端同步。前置未满足返回 false（原因见
  /// [talentBlockReason]）。
  Future<bool> spendTalent(
      String char, String element, String branch) async {
    await ensureLoaded();
    if (talentBlockReason(char, element, branch) != null) return false;
    final cost = talentMeritCost(char, element, branch);
    final newBalance = _state.meritBalance - cost;
    final levels = Map<String, Map<String, int>>.of(_state.talentLevels);
    final tree = Map<String, int>.of(levels[char] ?? const <String, int>{});
    if (branch == kJourneyTalentEnhanceKey) {
      tree[branch] = 1;
    } else {
      final code = journeyBranchCode(char, element, branch);
      final maxLv = kJourneyBranchMaxLv[branch] ?? 8;
      tree[code] = ((tree[code] ?? 0) + 1).clamp(0, maxLv);
    }
    levels[char] = tree;
    final pool = _state.talentPool - 1;
    final b = _branchOf(char, element, branch);
    final record = JourneyMeritRecordModel(
      id: const Uuid().v4(),
      delta: -cost,
      balanceAfter: newBalance,
      sourceType: 'talent_spend',
      refType: 'talent_branch',
      refId: branch == kJourneyTalentEnhanceKey
          ? '${char}_enhance'
          : b.branchCode,
      remark: branch == kJourneyTalentEnhanceKey
          ? '点亮加强点·${kJourneyCharAbilities[char]?.$1 ?? ''}'
          : '点亮${b.name} 第${tree[b.branchCode] ?? 0} 层',
      createdAt: journeyBjNow(),
    );
    _state = _copyState(
      meritBalance: newBalance,
      talentPool: pool,
      talentLevels: levels,
      meritRecords: <JourneyMeritRecordModel>[
        record,
        ..._state.meritRecords,
      ].take(JourneyProgressService._recordLimit).toList(),
    );
    await _persist();
    JourneyProgressSync.syncMeritRecord(record);
    return true;
  }
}
