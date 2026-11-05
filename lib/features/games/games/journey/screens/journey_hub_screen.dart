import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/game_model.dart';
import '../../../../../utils/cache_helper.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import 'journey_level_select_screen.dart';
import 'journey_character_screen.dart';
import 'journey_talent_screen.dart';
import 'journey_compendium_screen.dart';

/// S2 西行主界面（hub·场景舞台版）。
///
/// 布局对齐宠物主页范式：角色是唯一主角（舞台居中），信息各归其位——
/// - 全屏主题背景（bg_hub.svg 月夜山峦古道，独立画风）；
/// - 顶栏：返回 / 标题与进度 / 功德胶囊；
/// - 中央舞台：出战角色立绘（char_*.svg）+ 左右箭头切换已解锁角色；
/// - 底部：出战角色名牌（光环/特性法宝/基础血量）+「开始西行」主按钮
///   + 配置页入口行（取经队伍/五行天赋/法宝图鉴/设置）。
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
    if (!mounted) return;
    setState(() {
      _config = JourneyConfigService.instance.cached;
      _progress = progress.state;
      _loading = false;
    });
  }

  List<JourneyCharacterModel> get _characters =>
      _config?.characters ?? const <JourneyCharacterModel>[];

  /// 已解锁角色（切换只在这些角色间循环；唐僧恒可用）。
  List<JourneyCharacterModel> get _unlocked => _characters
      .where((c) =>
          c.code == 'tang' || _progress.unlockedCharacters.contains(c.code))
      .toList();

  JourneyCharacterModel get _currentCharacter {
    final code = JourneyProgressService.instance.selectedCharacterCode;
    for (final c in _unlocked) {
      if (c.code == code) return c;
    }
    return _unlocked.isEmpty ? _characters.first : _unlocked.first;
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
                child: Column(
                  children: <Widget>[
                    _topBar(),
                    Expanded(child: _stage()),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('西 行', style: JourneyTheme.titleLg),
                Text(_progressText, style: JourneyTheme.caption),
              ],
            ),
          ),
          JourneyCurrencyBar(merit: _progress.meritBalance),
        ],
      ),
    );
  }

  // ---- 中央舞台：角色立绘 + 切换箭头 ----

  Widget _stage() {
    final character = _currentCharacter;
    final multi = _unlocked.length > 1;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        // 立绘
        Padding(
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
        // 左右切换（多角色才显示）
        if (multi) ...<Widget>[
          Positioned(
            left: 6,
            child: _switchArrow(Icons.chevron_left, () => _switchCharacter(-1)),
          ),
          Positioned(
            right: 6,
            child:
                _switchArrow(Icons.chevron_right, () => _switchCharacter(1)),
          ),
        ],
      ],
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

  // ---- 底部：名牌 + 开始西行 + 入口行 ----

  Widget _bottomPanel() {
    final character = _currentCharacter;
    final weaponName = _weaponNameOf(character.weaponCode);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
          // 主按钮
          SizedBox(
            width: double.infinity,
            child: JourneyButton(
              text: '开 始 西 行',
              onTap: _openLevelSelect,
            ),
          ),
          const SizedBox(height: 10),
          // 配置页入口
          Row(
            children: <Widget>[
              Expanded(
                child: _EntryCard(
                  icon: Icons.groups,
                  label: '取经队伍',
                  onTap: () => _push(const JourneyCharacterScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EntryCard(
                  icon: Icons.auto_fix_high,
                  label: '五行天赋',
                  onTap: () => _push(const JourneyTalentScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EntryCard(
                  icon: Icons.auto_stories,
                  label: '法宝图鉴',
                  onTap: () => _push(const JourneyCompendiumScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EntryCard(
                  icon: Icons.settings,
                  label: '设置',
                  onTap: _openSettings,
                ),
              ),
            ],
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

  void _openLevelSelect() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JourneyLevelSelectScreen()),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: JourneyTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(JourneyTheme.radiusPanel)),
      ),
      builder: (_) => const _SettingsSheet(),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: JourneyTheme.panelDecoration(),
          child: Column(
            children: <Widget>[
              Icon(icon, color: JourneyTheme.gold, size: 22),
              const SizedBox(height: 4),
              Text(label, style: JourneyTheme.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  static const String _storeKey = 'journey_settings_v1';
  bool _music = true;
  bool _sfx = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw =
        await CacheHelper.instance.loadMap(_storeKey);
    if (!mounted) return;
    setState(() {
      _music = raw?['music'] as bool? ?? true;
      _sfx = raw?['sfx'] as bool? ?? true;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await CacheHelper.instance.saveMap(_storeKey, <String, dynamic>{
      'music': _music,
      'sfx': _sfx,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const JourneySectionTitle(text: '设置'),
            ListTile(
              leading: const Icon(Icons.music_note, color: JourneyTheme.gold),
              title: const Text('音乐', style: JourneyTheme.body),
              trailing: _loaded
                  ? Switch(value: _music, onChanged: (v) {
                      setState(() => _music = v);
                      _save();
                    })
                  : null,
            ),
            ListTile(
              leading:
                  const Icon(Icons.volume_up, color: JourneyTheme.gold),
              title: const Text('音效', style: JourneyTheme.body),
              trailing: _loaded
                  ? Switch(value: _sfx, onChanged: (v) {
                      setState(() => _sfx = v);
                      _save();
                    })
                  : null,
            ),
            SizedBox(
              width: double.infinity,
              child: JourneyButton(
                text: '关闭',
                secondary: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
