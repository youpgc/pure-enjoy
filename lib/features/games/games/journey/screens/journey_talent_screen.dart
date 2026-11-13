import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_load_error.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_busy.dart';

/// S5 五行天赋页（角色专属树 · v3 线性层制）。
///
/// 每角色一棵五行树（5 系 × 16 层，按序点亮）+ 第 81 点加强点：点亮
/// 纯消耗 1 天赋点（全账号共享点池，关卡首通 +1 / 击败妖王概率
/// 掉落），每层点亮即得该系属性加强；五系修满后点亮加强点，额外
/// 解锁角色特殊能力（引擎侧永久生效）。两级切换：顶部角色 pill
/// （未解锁置灰+「解锁后可修」角标，树可浏览不可点亮）→ 五行 Tab
/// → 轨迹卡 + 加强点卡。
class JourneyTalentScreen extends StatefulWidget {
  const JourneyTalentScreen({super.key});

  @override
  State<JourneyTalentScreen> createState() => _JourneyTalentScreenState();
}

class _JourneyTalentScreenState extends State<JourneyTalentScreen>
    with SingleTickerProviderStateMixin {
  /// 五行系序（Tab 顺序）。
  static const List<String> _elements = kJourneyTalentElements;

  // TabController 手动持有：升级/切角色后 setState 重建不重置所选系 Tab
  late final TabController _tabController =
      TabController(length: _elements.length, vsync: this);

  JourneyConfigSnapshot? _config;
  JourneyProgressModel _progress = const JourneyProgressModel();

  /// 点亮进行中：连点只弹一次确认窗、只扣一次天赋点与功德。
  bool _spending = false;

  /// 当前浏览的角色树（默认唐僧）。
  String _char = 'tang';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载失败标记：异常时由错误态接管，避免永久停在 loading。
  bool _loadFailed = false;

  Future<void> _load() async {
    try {
      final progress = JourneyProgressService.instance;
      await Future.wait<void>(<Future<void>>[
        JourneyConfigService.instance.ensure(JourneyConfigScope.talent),
        progress.ensureLoaded(),
      ]);
      if (!mounted) return;
      final chars = JourneyConfigService.instance.cached?.characters ??
          const <JourneyCharacterModel>[];
      setState(() {
        _config = JourneyConfigService.instance.cached;
        _progress = progress.state;
        _loadFailed = false;
        // 角色清单不含当前浏览角色（异常配置）→ 回落首角色
        if (chars.isNotEmpty && !chars.any((c) => c.code == _char)) {
          _char = chars.first.code;
        }
      });
    } catch (e, st) {
      reportJourneyLoadError(e, st);
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _retry() {
    setState(() => _loadFailed = false);
    _load();
  }

  List<JourneyCharacterModel> get _chars =>
      _config?.characters ?? const <JourneyCharacterModel>[];

  bool get _charUnlocked => _progress.characterUnlocked(_char);

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return JourneyPageScaffold(
        title: '五行天赋',
        body: JourneyLoadError(onRetry: _retry),
      );
    }
    final config = _config;
    if (config == null) {
      return const JourneyPageScaffold(
        title: '五行天赋',
        body: Center(
          child: JourneyLoading(label: '西行中…'),
        ),
      );
    }
    return JourneyPageScaffold(
      title: '五行天赋',
      body: Column(
        children: <Widget>[
          _buildCharPills(),
          TabBar(
            controller: _tabController,
            // 不画选中下划线（文案下的金色装饰线已移除），
            // 选中态由 labelColor 金字区分
            indicatorColor: Colors.transparent,
            labelColor: JourneyTheme.goldSoft,
            unselectedLabelColor: JourneyTheme.textSecondary,
            dividerColor: JourneyTheme.panelStroke,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: <Widget>[for (final e in _elements) _buildTab(e)],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                for (final e in _elements) _buildElementTab(config, e),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- 第一级：角色 pill（每角色一棵专属树） ----

  Widget _buildCharPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: <Widget>[
          for (final c in _chars) _buildCharPill(c),
        ],
      ),
    );
  }

  Widget _buildCharPill(JourneyCharacterModel c) {
    final unlocked = _progress.characterUnlocked(c.code);
    final selected = _char == c.code;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _char = c.code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? JourneyTheme.gold.withValues(alpha: 0.18)
                : JourneyTheme.panel,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? JourneyTheme.gold : JourneyTheme.panelStroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                c.name,
                style: JourneyTheme.body.copyWith(
                  color: selected
                      ? JourneyTheme.goldSoft
                      : (unlocked
                          ? JourneyTheme.textPrimary
                          : JourneyTheme.textFaint),
                ),
              ),
              // 未解锁角色：置灰 + 「解锁后可修」角标（树可浏览不可升级）
              if (!unlocked) ...<Widget>[
                const SizedBox(width: 5),
                const Icon(Icons.lock,
                    size: 11, color: JourneyTheme.locked),
                const SizedBox(width: 3),
                const Text(
                  '解锁后可修',
                  style: TextStyle(fontSize: 9, color: JourneyTheme.locked),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String element) {
    final color = JourneyTheme.elementColors[element] ?? JourneyTheme.gold;
    final name = JourneyTheme.elementNames[element] ?? element;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SvgPicture.asset(
            'assets/games/journey/element_$element.svg',
            width: 16,
            height: 16,
            errorBuilder: (_, __, ___) => Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(name),
        ],
      ),
    );
  }

  // ---- 第二级：单系页（头部信息 + 三分支卡 + 加强点卡） ----

  Widget _buildElementTab(JourneyConfigSnapshot config, String element) {
    final color = JourneyTheme.elementColors[element] ?? JourneyTheme.gold;
    final spent = _progress.talentSpentLayers(_char);
    final pool = _progress.talentPool;
    // 系内分支卡固定按类型序排（本源 core 8 层 → 生息 growth 5 层 →
    // 化形 sig 3 层）：seq 语义是角色五行主辅侧重（元素级 1~5），不承载
    // 系内分支序，按它排会导致各系三分支层级位次错乱不一。
    final branches = config
        .branchesOf(_char)
        .where((b) => b.element == element)
        .toList()
      ..sort((a, b) => kJourneyTalentBranchTypes
          .indexOf(a.branchType)
          .compareTo(kJourneyTalentBranchTypes.indexOf(b.branchType)));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        JourneyPanel(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '剩余 $pool 点 · 本树已修 $spent/81 层'
                      ' · 本系 ${_progress.talentElementLv(_char, element)}/16 层',
                      style: JourneyTheme.title,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _charUnlocked
                          ? '点亮消耗 1 天赋点 + 功德 · 相生循环节制点亮顺序'
                          : '解锁该角色后可修行其专属天赋树（当前可浏览）',
                      style: JourneyTheme.faint,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              JourneyCurrencyBar(merit: _progress.meritBalance),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final b in branches) ...<Widget>[
          _buildBranchCard(config, b, color),
          const SizedBox(height: 8),
        ],
        _buildEnhanceCard(),
      ],
    );
  }

  /// 分支卡（core 本源/growth 生息/sig 化形：Lv x/max + 每层效果）。
  Widget _buildBranchCard(
      JourneyConfigSnapshot config, JourneyTalentBranchModel b, Color color) {
    final service = JourneyProgressService.instance;
    final lv = _progress.talentLevelOf(_char, b.branchCode);
    final maxed = lv >= b.maxLv;
    final desc = b.effectDesc.isNotEmpty
        ? b.effectDesc
        : '每层 ${kJourneyTalentAttrLabels[b.attrKey] ?? b.attrKey}'
            ' +${b.valuePerLevel}';
    final locked = !maxed &&
        _charUnlocked &&
        service.talentBlockReason(_char, b.element, b.branchType) != null;
    return JourneyCard(
      onTap: (maxed || !_charUnlocked)
          ? null
          : () => _spend(b.element, b.branchType),
      qualityColor: lv > 0 ? color : null,
      locked: locked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(b.name, style: JourneyTheme.title.copyWith(color: color)),
              const Spacer(),
              Text('Lv $lv/${b.maxLv}', style: JourneyTheme.caption),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: JourneyTheme.faint),
          const SizedBox(height: 6),
          Text(
            '●' * lv +
                '○' *
                    (b.maxLv - lv).clamp(0, b.maxLv).toInt(),
            style: TextStyle(fontSize: 10, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            !_charUnlocked
                ? '解锁角色后可修'
                : (maxed
                    ? '已修满'
                    : '消耗 1 天赋点 + '
                        '${service.talentMeritCost(_char, b.element, b.branchType)} 功德'),
            style: JourneyTheme.caption.copyWith(
              color: maxed ? JourneyTheme.jade : JourneyTheme.gold,
            ),
          ),
        ],
      ),
    );
  }

  /// 加强点卡（第 81 点：五系修满后点亮，解锁角色特殊能力）。
  Widget _buildEnhanceCard() {
    final ability = kJourneyCharAbilities[_char];
    if (ability == null) {
      // 扩展角色暂无特殊能力映射：占位说明（避免 81 点池滞留无解释）
      return const JourneyCard(
        locked: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('第 81 点 · 加强点', style: JourneyTheme.title),
            SizedBox(height: 4),
            Text('特殊能力研发中，点亮通道暂未开放', style: JourneyTheme.faint),
          ],
        ),
      );
    }
    final service = JourneyProgressService.instance;
    final lit = _progress.talentEnhanceLit(_char);
    final ready = kJourneyTalentElements.every(
      (e) => _progress.talentElementLv(_char, e) >= 16,
    );
    final locked = !lit &&
        _charUnlocked &&
        service.talentBlockReason(
                _char, kJourneyTalentEnhanceKey, kJourneyTalentEnhanceKey) !=
            null;
    return JourneyCard(
      onTap: (lit || !_charUnlocked || !ready)
          ? null
          : () => _spend(
              kJourneyTalentEnhanceKey, kJourneyTalentEnhanceKey),
      qualityColor: lit ? JourneyTheme.gold : null,
      locked: locked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '加强点·${ability.$1}',
                style: JourneyTheme.title.copyWith(color: JourneyTheme.gold),
              ),
              const Spacer(),
              Text(lit ? '已点亮' : '未点亮', style: JourneyTheme.caption),
            ],
          ),
          const SizedBox(height: 4),
          Text(ability.$2, style: JourneyTheme.faint),
          const SizedBox(height: 6),
          Text(
            lit
                ? '特殊能力生效中'
                : (!_charUnlocked
                    ? '解锁角色后可修'
                    : (ready
                        ? '消耗 1 天赋点 + '
                            '${service.talentMeritCost(_char, kJourneyTalentEnhanceKey, kJourneyTalentEnhanceKey)} 功德'
                        : '五系修满 80 层后可点亮')),
            style: JourneyTheme.caption.copyWith(
              color: lit
                  ? JourneyTheme.jade
                  : (ready ? JourneyTheme.gold : JourneyTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _spend(String element, String branch) async {
    final service = JourneyProgressService.instance;
    if (!_charUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('解锁该角色后可修行其专属天赋树')),
      );
      return;
    }
    final reason = service.talentBlockReason(_char, element, branch);
    if (reason != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(reason)));
      return;
    }
    if (_spending) return;
    _spending = true;
    try {
      // 二次确认：天赋点亮双消耗（1 天赋点 + 功德，价随层数递增），误触代价大
      final cost = service.talentMeritCost(_char, element, branch);
      final balance = service.state.meritBalance;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: JourneyTheme.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
            side: const BorderSide(color: JourneyTheme.panelStroke),
          ),
          title: const Text('点亮天赋？', style: JourneyTheme.title),
          content: Text(
            '将消耗 1 天赋点 + $cost 功德点亮该层。\n'
            '当前功德余额 $balance，确认后即时扣除。',
            style: JourneyTheme.body,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('再想想', style: JourneyTheme.body),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                '确认点亮',
                style: JourneyTheme.body.copyWith(color: JourneyTheme.gold),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
      final ok = await JourneyBusy.run(
        context,
        () async {
          final lit = await service.spendTalent(_char, element, branch);
          if (lit) await _load();
          return lit;
        },
        label: '点亮中…',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '已点亮' : '点亮未成功')),
      );
    } finally {
      _spending = false;
    }
  }
}
