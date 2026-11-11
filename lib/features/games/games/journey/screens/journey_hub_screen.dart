import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/game_model.dart';
import '../../../../../utils/cache_helper.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import 'journey_battle_screen.dart';
import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_seed.dart';
import '../services/journey_time.dart';
import 'journey_level_select_screen.dart';
import 'journey_daily_screen.dart';
import 'journey_character_screen.dart';
import 'journey_talent_screen.dart';
import 'journey_compendium_screen.dart';
import 'journey_records_screen.dart';
import 'journey_hub_actions.dart';
import '../widgets/journey_entry_card.dart';

/// S2 西行主界面（hub·场景舞台版）。
///
/// 布局对齐宠物主页范式：角色是唯一主角（舞台居中），信息各归其位——
/// - 全屏主题背景（bg_hub.svg 月夜山峦古道，独立画风）；
/// - 顶栏：返回 / 标题与进度（同行）/ 功德胶囊；
/// - 入口行（顶栏正下方）：取经队伍/五行天赋/法宝图鉴/西行记录/设置；
/// - 中央舞台：出战角色立绘（char_*.svg）+ 左右箭头切换已解锁角色；
/// - 底部：出战角色名牌（光环/特性法宝/基础血量）+「开始西行」主按钮。
class JourneyHubScreen extends StatefulWidget {
  final GameModel game;

  const JourneyHubScreen({super.key, required this.game});

  @override
  State<JourneyHubScreen> createState() => _JourneyHubScreenState();
}

class _JourneyHubScreenState extends State<JourneyHubScreen> {
  JourneyConfigSnapshot? _config;
  JourneyProgressModel _progress = const JourneyProgressModel();
  bool _loading = true;

  /// 每日游历 gate：今日（北京日期）已功成则按钮置灰（口径同关卡选择页）。
  bool _dailyPlayed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = JourneyProgressService.instance;
    await Future.wait<void>(<Future<void>>[
      JourneyConfigService.instance.fetch(),
      progress.ensureLoaded(),
    ]);
    final gate = await CacheHelper.instance.loadMap('journey_daily_v1');
    if (!mounted) return;
    setState(() {
      _config = JourneyConfigService.instance.cached;
      _progress = progress.state;
      _dailyPlayed = gate?['date'] == journeyBjDateKey();
      _loading = false;
    });
  }

  List<JourneyCharacterModel> get _characters =>
      _config?.characters ?? const <JourneyCharacterModel>[];

  /// 已解锁角色（切换只在这些角色间循环；唐僧为初始角色恒可用）。
  /// 统一走模型解锁口径 isCharacterUnlocked（含 tang 特判），
  /// 避免与图鉴侧各自维护特判造成口径漂移。
  List<JourneyCharacterModel> get _unlocked => _characters
      .where((c) =>
          JourneyProgressService.instance.state.characterUnlocked(c.code))
      .toList();

  JourneyCharacterModel get _currentCharacter {
    final code = JourneyProgressService.instance.selectedCharacterCode;
    // 角色池：已解锁优先；远端清单空/全禁用（异常配置）回落种子首角色，
    // 防 List.first 抛 StateError 崩整页
    final pool = _unlocked.isNotEmpty
        ? _unlocked
        : (_characters.isNotEmpty
            ? _characters
            : kJourneyCharacterSeed
                .map(JourneyCharacterModel.fromJson)
                .toList());
    for (final c in pool) {
      if (c.code == code) return c;
    }
    return pool.first;
  }

  void _switchCharacter(int delta) {
    final list = _unlocked;
    if (list.length < 2) return;
    final cur = list.indexWhere((c) => c.code == _currentCharacter.code);
    final next = list[(cur + delta + list.length) % list.length];
    JourneyProgressService.instance.selectCharacter(next.code);
    setState(() {});
  }

  String get _progressText {
    final farthest = _progress.farthestLevelNo;
    return farthest <= 0 ? '未启程' : '已行至第 $farthest 难';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: JourneyTheme.bgBase,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 主题背景（独立画风，与 App 主题解耦）
            SvgPicture.asset(
              'assets/games/journey/bg_hub.svg',
              fit: BoxFit.cover,
            ),
            if (_loading)
              const Center(child: JourneyLoading(label: '西行中…'))
            else
              SafeArea(
                bottom: false,
                child: Column(
                  children: <Widget>[
                    _topBar(),
                    _entryRow(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: _stage(),
                      ),
                    ),
                    _bottomPanel(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- 顶栏：返回 + 标题进度 + 功德 ----

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: JourneyTheme.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                const SizedBox(width: 4),
                const Text('西 行', style: JourneyTheme.titleLg),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _progressText,
                    style: JourneyTheme.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          JourneyCurrencyBar(merit: _progress.meritBalance),
        ],
      ),
    );
  }

  // ---- 入口行：顶栏正下方（功德流水/对局记录/成就独立入口） ----

  Widget _entryRow() {
    // Wrap 换行排布：窄机型自动折行，卡片定宽防文案换行/间距过窄
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        // 从左至右排列（不居中）：窄机型自动折行，卡片定宽防文案换行
        alignment: WrapAlignment.start,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          SizedBox(
            width: 68,
            child: JourneyEntryCard(
              icon: Icons.groups,
              label: '取经队伍',
              onTap: () => _push(const JourneyCharacterScreen()),
            ),
          ),
          SizedBox(
            width: 68,
            child: JourneyEntryCard(
              icon: Icons.auto_fix_high,
              label: '五行天赋',
              onTap: () => _push(const JourneyTalentScreen()),
            ),
          ),
          SizedBox(
            width: 68,
            child: JourneyEntryCard(
              icon: Icons.auto_stories,
              label: '图鉴',
              onTap: () => _push(const JourneyCompendiumScreen()),
            ),
          ),
          SizedBox(
            width: 68,
            child: JourneyEntryCard(
              icon: Icons.receipt_long,
              label: '功德流水',
              onTap: () => _push(const JourneyMeritRecordsScreen()),
            ),
          ),
          SizedBox(
            width: 68,
            child: JourneyEntryCard(
              icon: Icons.sports_esports,
              label: '对局记录',
              onTap: () => _push(const JourneyRunRecordsScreen()),
            ),
          ),
          SizedBox(
            width: 68,
            child: JourneyEntryCard(
              icon: Icons.emoji_events,
              label: '成就',
              onTap: () => _push(const JourneyAchievementsScreen()),
            ),
          ),
          SizedBox(
            width: 68,
            child: JourneyEntryCard(
              icon: Icons.leaderboard,
              label: '西行排行',
              onTap: () => openJourneyLeaderboard(context,
                  snapshotGameId: _config?.gameId ?? '',
                  fallbackGameId: widget.game.id,
                  gameCode: widget.game.code),
            ),
          ),
          SizedBox(
            width: 68,
            child: JourneyEntryCard(
              icon: Icons.settings,
              label: '设置',
              onTap: () => openJourneySettings(context),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 中央舞台：角色立绘 + 切换箭头 ----

  Widget _stage() {
    final character = _currentCharacter;
    final multi = _unlocked.length > 1;
    return LayoutBuilder(
      builder: (context, c) {
        // 两箭头内缘相距 200px：对称贴齐中缝两侧（箭头直径=26 图标+16 内边距）
        const gap = 200.0;
        const arrowSize = 42.0;
        final side = ((c.maxWidth - gap) / 2 - arrowSize).clamp(0.0, 999.0);
        // StackFit.expand：撑满 LayoutBuilder 宽度，Positioned 按屏宽定位
        // （缺省 Stack 只取非定位子级尺寸，箭头会挤到中缝重叠）
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: <Widget>[
            // 立绘
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: SvgPicture.asset(
                  'assets/games/journey/char_${character.code}.svg',
                  width: 210,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person,
                    size: 120,
                    color: JourneyTheme.gold,
                  ),
                ),
              ),
            ),
            // 左右切换（多角色才显示）：距舞台下方元素 40px
            if (multi) ...<Widget>[
              Positioned(
                left: side,
                bottom: 40,
                child:
                    _switchArrow(Icons.chevron_left, () => _switchCharacter(-1)),
              ),
              Positioned(
                right: side,
                bottom: 40,
                child: _switchArrow(
                    Icons.chevron_right, () => _switchCharacter(1)),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _switchArrow(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.28),
            border: Border.all(color: JourneyTheme.goldSoft, width: 1),
          ),
          child: Icon(icon, color: JourneyTheme.gold, size: 26),
        ),
      ),
    );
  }

  // ---- 底部：名牌 + 开始西行（按钮距屏底 100px） ----

  Widget _bottomPanel() {
    final character = _currentCharacter;
    final weaponName = _weaponNameOf(character.weaponCode);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            JourneyTheme.bgBase.withValues(alpha: 0),
            JourneyTheme.bgBase.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 名牌
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(character.name, style: JourneyTheme.titleLg),
              const SizedBox(width: 10),
              _statChip('❤ ${character.baseHp}'),
              const SizedBox(width: 6),
              _statChip('光环·${character.auraName}'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${character.auraDesc} · 特性法宝「$weaponName」',
            style: JourneyTheme.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // 模式入口行：无尽妖潮 + 每日游历（一行两钮，间距 16px）
          Row(
            children: <Widget>[
              Expanded(
                child: JourneyButton(
                  text: '无尽妖潮',
                  onTap: _startEndless,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: JourneyButton(
                  text: _dailyLabel,
                  enabled: !_dailyPlayed,
                  onTap: _startDaily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 主按钮（模式行下移一个按钮高度+8px 后落位）
          SizedBox(
            width: double.infinity,
            child: JourneyButton(
              text: '开 始 西 行',
              onTap: _openLevelSelect,
            ),
          ),
        ],
      ),
    );
  }

  String _weaponNameOf(String code) {
    for (final w in _config?.weapons ?? const <JourneyWeaponModel>[]) {
      if (w.code == code) return w.name;
    }
    return code;
  }

  Widget _statChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: JourneyTheme.panel.withValues(alpha: 0.8),
        border: Border.all(color: JourneyTheme.panelStroke),
      ),
      child: Text(text, style: JourneyTheme.caption),
    );
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  Future<void> _openLevelSelect() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JourneyLevelSelectScreen()),
    );
    if (mounted) await _load();
  }

  // ---- 模式直入（hub 快捷入口；口径与关卡选择页一致）----

  /// 每日游历按钮文案（已游历置灰提示）。
  String get _dailyLabel => _dailyPlayed ? '已游历·明日再来' : '每日游历';

  void _startEndless() {
    final config = _config;
    if (config == null) return;
    final regionCode = config.regions.isNotEmpty
        ? config.regions.first.code
        : 'wuxingshan';
    _push(JourneyBattleScreen(
      level: JourneyLevelModel(
        levelNo: 0,
        title: '无尽妖潮',
        regionCode: regionCode,
        kind: 'endless',
        bossFights: 0,
        durationTargetSec: 0,
      ),
    ));
  }

  /// 每日游历：直达地图选择页（后台 journey_daily_maps 列表任选，进入即计次）。
  Future<void> _startDaily() async {
    await _push(const JourneyDailyScreen());
  }

}
