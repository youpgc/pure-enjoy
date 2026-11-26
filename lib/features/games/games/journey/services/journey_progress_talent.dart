part of 'journey_progress_service.dart';

/// 相生链：生我者（下一组解锁需本系前一组与生我者系前一组均修满）。
const Map<String, String> generatorOf = <String, String>{
  'metal': 'earth', // 土生金
  'water': 'metal', // 金生水
  'wood': 'water', // 水生木
  'fire': 'wood', // 木生火
  'earth': 'fire', // 火生土
};

/// 相克链：克我者。当前天赋解锁已不设相克制衡，留存供展示/后续复用。
const Map<String, String> restrainerOf = <String, String>{
  'metal': 'fire', // 火克金
  'wood': 'metal', // 金克木
  'water': 'earth', // 土克水
  'fire': 'water', // 水克火
  'earth': 'wood', // 木克土
};

/// 西行·角色专属天赋树逻辑拆分（part 同 library：访问宿主私有状态）。
///
/// 分支树制：点亮的前置校验与双消耗扣费入账。每角色一棵五行树
/// （5 系 × 16 层 = core 8/growth 5/sig 3 三分支 + 第 81 点加强点）。
/// 前置规则（分组解锁）：
/// · 分支内按层序点亮；
/// · 本源枝 core 全系随时可修，不受其他系进度牵制；
/// · 下一组解锁看前一组是否修满：growth 需本系 core 修满且生我者系
///   core 修满；sig 需本系 growth 修满且生我者系 growth 修满；
/// · 因本源枝 8 层全自由，五系可先各自修满本源再逐级解锁下一组，
///   相生闭环不构成死锁；
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

    // 分组解锁：本源枝按层序自由修，无前置；下一组（growth/sig）需
    // 前一组在本系与生我者系都修满。前一组取 core→growth 的前一支；
    // 满级阈值统一取分支配置的 max_lv（快照优先、种子兜底），与本系
    // 修满判定、写入 clamp、UI 显示同源，后台调整层数上限不会口径分裂。
    if (branch != 'core') {
      final prevBranch = branch == 'growth' ? 'core' : 'growth';
      final prevCode = journeyBranchCode(char, element, prevBranch);
      if (_state.talentLevelOf(char, prevCode) <
          _branchOf(char, element, prevBranch).maxLv) {
        return '需本系${prevBranch == 'core' ? '本源枝' : '生息枝'}修满';
      }
      // 生我者系同组也要修满，确保相生关系成立后才开放下一组。
      final generator = generatorOf[element]!;
      final genPrevCode = journeyBranchCode(char, generator, prevBranch);
      if (_state.talentLevelOf(char, genPrevCode) <
          _branchOf(char, generator, prevBranch).maxLv) {
        return '需「${_elementName(generator)}」系'
            '${prevBranch == 'core' ? '本源枝' : '生息枝'}修满';
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
      final maxLv = _branchOf(char, element, branch).maxLv;
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
