import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

/// 宠物主页库（part 拆分）：本文件是 library 声明与状态主体，
/// 三个 part 共用下列导入（Dart 的 part 文件不能自带 import）。
import '../../../constants/pet.dart';
import '../../../constants/pet_render.dart';
import '../../../core/widgets/widgets.dart';
import '../models/pet_models.dart';
import '../models/pet_event_models.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_audio.dart';
import '../services/pet_rpc.dart';
import '../services/pet_service.dart';
import '../utils/pet_action_machine.dart';
import '../utils/pet_art_resolver.dart';
import '../utils/pet_dict.dart';
import '../utils/pet_errors.dart';
import '../utils/pet_exp_curve.dart';
import '../utils/pet_home_budget.dart';
import '../widgets/pet_attributes_sheet.dart';
import '../widgets/pet_feed_sheet.dart';
import '../widgets/pet_fx_overlay.dart';
import '../widgets/pet_home_adventure.dart';
import '../widgets/pet_home_overlays.dart';
import '../widgets/pet_home_scene.dart';
import '../widgets/pet_initial_family_picker.dart';
import '../widgets/pet_event_dialog.dart';
import '../widgets/pet_living_art.dart';
import 'pet_achievements_screen.dart';
import 'pet_adventure_screen.dart';
import 'pet_bag_screen.dart';
import 'pet_breed_screen.dart';
import 'pet_dex_screen.dart';
import 'pet_egg_screen.dart';
import 'pet_foster_screen.dart';
import 'pet_growth_screen.dart';
import 'pet_quests_screen.dart';
import 'pet_shop_screen.dart';
import 'pet_wallet_screen.dart';
import '../widgets/pet_toast.dart';
import '../widgets/pet_loading.dart';

part 'pet_home_screen_layout.dart';
part 'pet_home_screen_actions.dart';

/// 宠物主页（场景舞台版 2.0，2026-09-17 美化重做）
///
/// 布局原则：宠物是唯一主角（垂直水平居中），其余信息各归其位——
/// - 场景背景：梦幻夜空场景图（与 App 主题解耦，PetSceneBackground）；
/// - 顶部通知横幅：当前查看宠的历险态三分类（进行中/归来待领取/待救助，
///   20261021 单宠口径，切宠即跟随），点击按状态分流；
/// - 左右按钮列贴顶（安全区下留少许间距）：左列 = 返回键 + 背包 / 商城 / 钱包 /
///   寄养 / 成就 / 繁育（P2 四项里成就与繁育走主页直达，孵蛋走背包蛋行、
///   进化与特性洗练走属性面板，避免按钮列在小屏上溢出）；
///   右列 = 金币胶囊 + 喂食 / 抚摸 / 历险 / 任务
///   （历险钮四态：历险/召回/领取/救助），冷却时黑色透明蒙层白色字体居中倒计时；
/// - 底部状态区：名牌 + 四维独立行沉底（PetBottomStatusCard），历险中附去向提示；
///   无任何宠物时孵化引导卡垂直水平居中（返回键/金币回独立浮层）。
/// - 中央舞台手势（2026-09-24 2D 动画定版）：单击 = 抚摸（走 interact RPC）、
///   双击 = 开心演出（纯表现，不发 RPC 不加数值）、长按 = 属性面板；
///   动作由 [PetActionMachine] 仲裁，粒子由 [PetFxController] 绘制。
/// 浮层组件见 pet_home_overlays / scene / adventure.dart，冷却派生见 PetActionBudget。
///
/// 【文件拆分 2026-09-22】单文件超 500 行红线，按职责拆为三个 part：
/// - 本文件：状态字段 + 生命周期 + 数据装载 + 派生取值 + 整体 Stack 组装
/// - `pet_home_screen_layout.dart`：舞台 / 顶部横幅 / 底部状态 / 左右两列的浮层构建
/// - `pet_home_screen_actions.dart`：交互动作（喂食、孵化、跳转、历险四态）
///
/// 【3D 下线归档 2026-09】3D 渲染层与资源包状态卡一并下线（源码注释保留），
/// 数据库 render3d_enabled / asset_manifest 列保留，3D 转后期迭代。
class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({super.key, this.initialTab});

  /// 深链页签（bag / shop / wallet / quests ...），null 表示正常进入
  final String? initialTab;

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _enabled = false;
  PetSummaryModel? _summary;
  String? _error;
  bool _busy = false;

  /// 场景主题（§11.1）：当前激活场景码；进页拉一次，主题面板切换后更新。
  /// 初值是占位默认码，真实激活码以 fetchScenes 回落为准
  String _activeScene = 'scene_dream';

  /// 场景资源预热去重标记：_sceneReadyFor 记录已解码的场景码
  bool _sceneReady = false;
  String _sceneReadyFor = '';

  /// 初载场景管线完结：fetchScenes 回落 + 激活码解码完成才置真。
  /// 门禁等它而非 _sceneReady——占位默认码先就绪就开闸，真实主题到位
  /// 再切换即「默认→已切主题」的一闪（20261028 用户实测反馈）。
  /// 置真后不再回落：在线切主题先解码后切码（_openThemes），不重锁门禁
  bool _sceneFetchDone = false;

  /// 随机事件（§3.6）：进页后首次 summary 成功时 roll 一次 home_open；
  /// 照料动作成功后 roll action_done。_eventDialogShowing 防弹层叠加。
  bool _homeEventRolled = false;
  bool _eventDialogShowing = false;

  /// 当前 _summary 是否来自本地缓存秒开（SWR 路径）——宠物状态可能滞后，
  /// 事件触发等强状态判定不得以缓存态为据（见 _maybeShowEvent）
  bool _summaryFromCache = false;

  /// 动作仲裁器（优先级/防抖，逻辑见 [PetActionMachine]）
  final PetActionMachine _machine = PetActionMachine();

  /// 舞台粒子层控制器（爱心/星星/碎屑/进化光柱，空闲自动停表）
  late final PetFxController _fx = PetFxController(vsync: this);

  /// 当前查看的宠 id（20261021 从下标制改 id 制：选中态只认身份不认位置，
  /// 列表刷新后仍指向同一只；查宠一律走 [PetSummaryModel.petInfoFor] 公共口子）
  String? _selectedPetId;

  Timer? _tick; // 冷却倒计时逐秒刷新

  /// 上一帧是否冷却中：冷却清零的那一跳 anyCooling 已翻 false，
  /// 只按它守卫会跳过清除渲染 → 蒙层冻在「1秒」（2026-10-10 修）
  bool _wasCooling = false;

  /// 底部状态面板实测高度：切换箭头按「面板顶 + 10px」对位（首帧前用兜底值）
  final GlobalKey _panelKey = GlobalKey();
  double _panelH = 168;

  /// 每帧后量一次面板高度；变化超 0.5px 才重建（防测量循环）
  void _measurePanel() {
    final h = _panelKey.currentContext?.size?.height;
    if (h != null && h > 0 && (h - _panelH).abs() > 0.5 && mounted) {
      setState(() => _panelH = h);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadActiveScene();
    // 首帧后预热占位默认码：激活码即默认码时秒回，拉取失败时兜底即用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureSceneReady(_activeScene);
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final cooling = _budget.anyCooling;
      if (cooling || _wasCooling) {
        _wasCooling = cooling;
        setState(() {});
      } else {
        _wasCooling = false;
      }
    });
  }

  /// 拉取当前激活场景（独立于 _load：主题切换不触发总览刷新）
  Future<void> _loadActiveScene() async {
    final (data, err) = await PetRpc.fetchScenes();
    if (!mounted) return;
    // 拉取失败沿用占位默认码（postFrame 预热兜底），不卡 loading
    final code = (err == null && data != null)
        ? data['active']?.toString() ?? 'scene_dream'
        : 'scene_dream';
    await _ensureSceneReady(code);
    if (!mounted) return;
    setState(() {
      _activeScene = code;
      _sceneFetchDone = true;
    });
  }

  /// 场景主题资源预热：precacheImage 解码完成才返回（loading 双条件之二）。
  /// 资源异常不卡 loading——放行后由渲染层默认背景兜底（失败留痕便于排查素材缺失）。
  Future<void> _ensureSceneReady(String code) async {
    if (_sceneReady && _sceneReadyFor == code) return;
    try {
      await precacheImage(
          AssetImage(PetSceneBackground.assetPath(code)), context);
    } catch (_) {
      if (kDebugMode) debugPrint('[PetHome] 场景资源预热失败: $code');
    }
    if (mounted) {
      setState(() {
        _sceneReadyFor = code;
        _sceneReady = true;
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _fx.dispose();
    super.dispose();
  }

  /// 舞台宠物列表：在养 + 历险中（历险派遣后原宠物保留原位，寄养/繁育中不展示）
  List<PetBriefModel> get _stagePets => (_summary?.pets ?? const <PetBriefModel>[])
      .where((p) => p.status == PetPetStatus.rearing || p.status == PetPetStatus.adventuring)
      .toList();

  /// 当前选中的宠物（无舞台宠物返回 null）
  ///
  /// 单宠口径总闸（20261021 用户拍板）：切换宠物时只经 [petInfoFor] 取
  /// 当前宠状态更新 UI，不做他宠内容展示。selected 失效（被放生/出列）
  /// 回落第一只，与旧下标防越界同语义。
  PetBriefModel? get _currentPet {
    final pets = _stagePets;
    if (pets.isEmpty) return null;
    final selected = _summary?.petInfoFor(_selectedPetId);
    if (selected != null && pets.contains(selected)) return selected;
    return pets.first;
  }

  /// 当前宠物的进行中历险（per-pet：summary 逐宠下发 pets[].adventure）
  PetAdventureBriefModel? get _currentAdventure => _currentPet?.adventure;

  /// 冷却与每日次数派生（逻辑见 [PetActionBudget]）
  PetActionBudget get _budget =>
      PetActionBudget(config: _summary?.config ?? const {}, pet: _currentPet);

  Future<void> _load({bool force = false}) async {
    final enabled = await PetService.instance.isPetEnabled(forceRefresh: force);
    if (!enabled) {
      if (mounted) {
        setState(() {
          _enabled = false;
          _loading = false;
        });
      }
      return;
    }
    final (summary, err) =
        await PetService.instance.fetchSummary(forceRefresh: force);
    _summaryFromCache = PetService.instance.lastSummaryFromCache;
    // 字典非阻塞预热（家系等开放值域文案，失败走端内兜底；20261030）
    if (force || PetDict.isEmpty) unawaited(PetRpc.fetchDicts());
    if (mounted) {
      setState(() {
        _enabled = true;
        _summary = summary;
        _error = summary == null ? (err ?? '宠物功能已关闭') : null;
        _loading = false;
        // 选中失效（被放生/出列）时回落第一只；指向仍有效则保持不变。
        // summary 拉取失败（_summary=null）不参与失效判定：瞬时网络错误
        // 不应把选中宠重置回第一只（20261021 审查）
        if (summary != null &&
            _selectedPetId != null &&
            !_stagePets.any((p) => p.id == _selectedPetId)) {
          _selectedPetId = null;
        }
      });
      // 打开宠物页的插叙事件：仅本次停留首次成功装载时掷一次（§3.6 home_open）
      if (summary != null && !_homeEventRolled) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // 真正走到 roll 才算已掷（历险中等跳过场景不算，本停留可再试）
          if (await _maybeShowEvent(kPetEventContextHomeOpen)) {
            _homeEventRolled = true;
          }
        });
      }
    }
    _syncAmbient();
  }

  /// 低状态环境态接线（§11.3 2026-10-08 修订）：饱食/心情任一低于历险出发
  /// 阈值（同一口径，零新增配置）→ ambient 切 sad；恢复即回 idle。
  /// 阈值缺键（旧版服务端）不启用 sad，回退常态 idle。
  void _syncAmbient() {
    if (!mounted) return; // _load 完成时页面可能已销毁（异步竞态）
    final pet = _currentPet;
    final cfg = _summary?.config ?? const {};
    final hT = (cfg['adventure_hunger_threshold'] as num?)?.toInt();
    final mT = (cfg['adventure_mood_threshold'] as num?)?.toInt();
    final low = pet != null &&
        ((hT != null && hT > 0 && pet.hunger < hT) ||
            (mT != null && mT > 0 && pet.mood < mT));
    _machine.ambientOverride = low ? PetAction.sad : null;
    if (low) {
      if (_machine.current == PetAction.idle) _playAction(PetAction.sad);
    } else if (_machine.current == PetAction.sad) {
      _machine.reset();
      if (mounted) setState(() {});
    }
  }

  /// 随机事件尝试触发：roll 未命中/失败一律静默（插叙彩蛋不打扰主流程），
  /// 命中才弹层；选择结算后刷新总览（心情/经验/亲密/金币可能变化）。
  /// 返回「是否真正走到 roll」——busy/历险中这类跳过场景返回 false 不算已掷，
  /// 本次停留后续仍可再试（20261021 审查：home_open 曾被历险态跳过吞掉）
  Future<bool> _maybeShowEvent(String pContext) async {
    if (!mounted || _eventDialogShowing || _busy) return false;
    // 缓存秒开的总览宠物状态可能滞后（如刚出发历险）——缓存态不掷事件，
    // 待网络新帧落地后的装载/动作再掷（跳过不算已掷，配额不亏）
    if (_summaryFromCache) return false;
    final pet = _currentPet;
    if (pet == null) return false;
    // 历险中不触发随机事件（2026-10-14 服务端 choose 已收口 rearing-only；
    // 客户端同步收口入口，避免「弹了窗、选了才报错」的体验）
    if (pet.status != PetPetStatus.rearing) return false;
    final (event, _) = await PetRpc.eventRoll(pContext);
    if (!mounted || _eventDialogShowing) return true; // roll 已发生，计已掷
    if (event == null || event.options.isEmpty) return true;
    // roll 期间切宠则落点当前宠，但仅限仍可交互（养育中）的宠——
    // 落到历险/繁育中的宠会让弹窗无法选择（choose 端 rearing-only）
    final current = _currentPet;
    final target = (current != null &&
            current.status == PetPetStatus.rearing)
        ? current
        : pet;
    if (target.status != PetPetStatus.rearing) return true; // 掷骰宠也历险了：弃弹不亏配额
    _eventDialogShowing = true;
    try {
      await showPetEventDialog(context, event: event, petId: target.id);
    } finally {
      _eventDialogShowing = false;
    }
    if (mounted) _load();
    return true;
  }

  void _switchPet(int delta) {
    final pets = _stagePets;
    if (pets.length < 2) return;
    final from = pets.indexWhere((p) => p.id == _selectedPetId);
    // 选中失效（被放生/出列，视图已回落第一只）从 0 出发再位移
    final cur = from < 0 ? 0 : from;
    // 换宠回落环境态：A 宠的演出不带进 B 宠
    _machine.reset();
    _fx.clear();
    setState(() {
      _selectedPetId = pets[(cur + delta + pets.length) % pets.length].id;
    });
    _syncAmbient(); // 新宠的低状态环境态（sad）按其自身数值重算
  }

  @override
  Widget build(BuildContext context) {
    // 面板高度随内容（历险提示行出现/消失）浮动，每帧后量一次供箭头对位
    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePanel());
    return Scaffold(body: _buildBody(Theme.of(context).colorScheme));
  }

  Widget _buildBody(ColorScheme cs) {
    // 初始 loading 双条件：总览就绪 + 场景管线完结（激活码已定且解码完成）
    if (_loading || !_sceneFetchDone) {
      return const Center(child: PetPawLoading());
    }
    if (!_enabled) return const EmptyWidget(message: '宠物功能暂未开放');
    if (_summary == null) {
      return PetLoadErrorView(
        message: _error,
        onRetry: () {
          setState(() => _loading = true);
          _load(force: true);
        },
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PetSceneBackground(sceneCode: _activeScene),
        if (_stagePets.isNotEmpty) ...[
          _stage(),
          ..._switchArrows(),
          _topBanner(cs),
          _bottomPanel(cs),
          _leftRail(),
          _rightRail(),
        ] else ...[
          // 无任何宠物：返回键/金币常驻顶部角落 + 孵化引导卡垂直水平居中
          PetBackButton(onBack: () => Navigator.maybePop(context)),
          PetGoldBadge(gold: _summary?.wallet.goldBalance ?? 0),
          Center(
            child: PetHatchGuide(
                hasEgg: _summary!.eggsReadyInstant > 0,
                busy: _busy,
                onHatch: _hatchFirstEgg,
                onGoEggs: _openEggs),
          ),
        ],
      ],
    );
  }
}
