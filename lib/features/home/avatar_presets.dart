/// 内置可选头像（DiceBear 多风格 + 未来可扩展：本地内置资源 / 阿里 Iconfont）
///
/// 设计说明：
/// - 采用 [DiceBear](https://www.dicebear.com/) 现代扁平插画家族：免费 CDN、MIT 开源、
///   无需 API Key、按 seed 确定性生成。
/// - DiceBear v9 共有 **27 个可用风格**（city / tiny-avatars 已下架）。面板当前按用户定调**精选 8 个**供选择
///   （见 [kAvatarStyles]，可自行增删），默认 现代扁平（Personas），无需按性别/分类强约束。
/// - 不再按性别区分风格：DiceBear「人物」风格内部均包含男女，无法可靠生成「全男 / 全女」，
///   且早期按 micah 给男性仍会混出女性面孔。因此面板不强调性别，全部交给用户自选。
/// - **「换一批」**：重新生成一批该风格的网络头像（换 batchSeed），同一风格即可呈现完全不同的头像顺序。
/// - **背景色自定义**：提供 7 个「主色调」快捷选择（[kAvatarBgPresets]），并支持用户在页面内
///   用单条「色相」滑动条自由调整背景色（hex 写入 URL，随头像一起保存）；主色调即滑动条锚点。
///
/// 未来扩展（预留，当前未启用）：
/// - 本地内置资源：将一批授权清晰的通用头像 PNG/SVG 放入 `assets/avatars/`，
///   用 `AssetImage('assets/avatars/xxx.png')` 展示，零网络依赖。
/// - 阿里巴巴矢量图库（Iconfont）：通过项目 CDN 链接接入，预留常量 [kIconfontCdnBase]
///   与函数 [getIconfontPresets]（当前返回空，待填项目 ID）。
///
/// 想改默认风格？把对应 [AvatarStyleOption.isDefault] 设为 true 即可。
library;

import 'dart:math';

/// DiceBear HTTP API 基础地址（v9）
const String _kDiceBearBase = 'https://api.dicebear.com/9.x';

/// 头像分辨率（网格内头像直径约 62dp，128 已足够清晰，体积约为 256 的 1/4）
const int _kDiceBearSize = 128;

/// 风格分组（仅用于面板归类展示）
enum AvatarStyleGroup {
  person('人物'),
  cartoon('卡通涂鸦'),
  robot('机器人'),
  pixel('像素'),
  abstract('抽象几何'),
  fun('趣味');

  const AvatarStyleGroup(this.label);
  final String label;
}

/// 单个可选风格的描述
class AvatarStyleOption {
  /// DiceBear 风格 key（用于拼接 URL）
  final String key;

  /// 面板中显示的中文名
  final String label;

  /// 分组
  final AvatarStyleGroup group;

  /// 风格说明
  final String desc;

  /// 选中该风格时预置的背景色（hex 不含 #，null = 透明）。
  final String? defaultBg;

  /// 是否为 App 默认推荐风格
  final bool isDefault;

  const AvatarStyleOption({
    required this.key,
    required this.label,
    required this.group,
    required this.desc,
    this.defaultBg,
    this.isDefault = false,
  });
}

/// 面板可选风格（按用户定调精选 8 个，默认 现代扁平（Personas）；其余 v9 风格可随时加入）
const List<AvatarStyleOption> kAvatarStyles = <AvatarStyleOption>[
  AvatarStyleOption(
    key: 'personas',
    label: '现代扁平',
    group: AvatarStyleGroup.person,
    desc: '现代扁平人物，中性百搭（默认）',
    isDefault: true,
    defaultBg: '2ec4b6',
  ),
  AvatarStyleOption(
    key: 'lorelei',
    label: '人物手绘',
    group: AvatarStyleGroup.person,
    desc: '精致手绘风，偏女性化面孔',
    defaultBg: 'e98aa1',
  ),
  AvatarStyleOption(
    key: 'lorelei-neutral',
    label: '表情手绘',
    group: AvatarStyleGroup.person,
    desc: '手绘风，中性面孔',
    defaultBg: 'a78bc7',
  ),
  AvatarStyleOption(
    key: 'big-ears',
    label: '萌系大耳',
    group: AvatarStyleGroup.person,
    desc: '大耳朵萌系角色（完整版，带背景）',
    defaultBg: 'ffc8a2',
  ),
  AvatarStyleOption(
    key: 'adventurer',
    label: '冒险家',
    group: AvatarStyleGroup.person,
    desc: '西式冒险家角色（完整版，带背景）',
    defaultBg: 'c08552',
  ),
  AvatarStyleOption(
    key: 'adventurer-neutral',
    label: '冒险家表情',
    group: AvatarStyleGroup.person,
    desc: '西式冒险家表情（无背景，透明）',
    defaultBg: 'cdeffd',
  ),
  AvatarStyleOption(
    key: 'pixel-art',
    label: '像素',
    group: AvatarStyleGroup.pixel,
    desc: '8-bit 像素风人物',
    defaultBg: '06d6a0',
  ),
  AvatarStyleOption(
    key: 'croodles',
    label: '卡通涂鸦',
    group: AvatarStyleGroup.cartoon,
    desc: '涂鸦手绘风',
    defaultBg: 'ffb703',
  ),
  AvatarStyleOption(
    key: 'fun-emoji',
    label: '趣味表情',
    group: AvatarStyleGroup.fun,
    desc: 'Emoji 风趣味表情头像',
    defaultBg: 'ff9f1c',
  ),
];

/// 默认风格（遍历 [kAvatarStyles] 取 isDefault，取不到则第一项）
AvatarStyleOption get kDefaultStyle =>
    kAvatarStyles.firstWhere((s) => s.isDefault, orElse: () => kAvatarStyles.first);

/// 默认背景色（浅蓝，hex 不含 #）；用户可在面板内改为任意色或无背景
const String kDefaultBg = 'cdeffd';

/// 主色调（7 个常用、协调的色板，hex 不含 #）
/// 既是「主色调」快捷选择，也是 RGB 滑动条的锚点：点击即把 R/G/B 滑动条设到该色。
const List<String> kAvatarBgPresets = <String>[
  'cdeffd', // 冰蓝（默认）
  '6ec6c6', // 黛青
  'a8e6a3', // 竹绿
  'c9372c', // 中国红
  'f6c6d8', // 樱粉
  'd6cdfa', // 薰衣草
  'ffe3a3', // 暖黄
];

/// 拼接一个 DiceBear 头像 URL
///
/// [style] 风格 key；[seed] 种子（决定形象）；[backgroundColor] 背景色 hex（不含 #，
/// 传 null 表示透明背景）；[size] 分辨率。
String diceBearUrl({
  required String style,
  required String seed,
  String? backgroundColor,
  int size = _kDiceBearSize,
}) {
  final buf = StringBuffer(
    '$_kDiceBearBase/$style/png'
    '?seed=${Uri.encodeComponent(seed)}'
    '&size=$size'
    '&radius=50',
  );
  if (backgroundColor != null && backgroundColor.isNotEmpty) {
    buf.write('&backgroundColor=${backgroundColor.replaceAll('#', '')}');
  }
  return buf.toString();
}

/// 从 DiceBear URL 解析出关键参数（风格 / 种子 / 背景色）。
///
/// 用于：① 记录头像历史时拆出结构化字段；② 历史页「修改色调」时
/// 以原 style/seed 重新拼接带新背景色的 URL。解析失败（非 DiceBear URL）返回 null。
({String style, String seed, String? bg})? parseDiceBearUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    // 形如 .../9.x/<style>/png
    if (segments.length < 3) return null;
    final style = segments[1];
    final seed = uri.queryParameters['seed'] ?? '';
    final bgParam = uri.queryParameters['backgroundColor'];
    final bg = (bgParam == null || bgParam.isEmpty) ? null : bgParam;
    return (style: style, seed: seed, bg: bg);
  } catch (_) {
    return null;
  }
}

/// 根据 [batchSeed] 生成一批（[count] 个）头像 URL
///
/// 用于面板「换一批」：每次点击改变 [batchSeed]，同一 [style] 即可得到
/// 完全不同的头像内容（seed 形如 `${style}_${batchSeed}_$i`）。
List<String> generateAvatarBatch({
  required String style,
  String? backgroundColor,
  required int batchSeed,
  int count = 12,
}) {
  return List<String>.generate(count, (i) {
    final seed = '${style}_${batchSeed}_$i';
    return diceBearUrl(
      style: style,
      seed: seed,
      backgroundColor: backgroundColor,
    );
  });
}

/// 生成一个随机 batchSeed（用于「换一批」）
int randomBatchSeed() => Random().nextInt(1 << 31);

/// 阿里 Iconfont CDN 图片基础地址模板（预留，待填项目 PID）
/// 图片方式示例：'$kIconfontCdnBase/<name>.png'
const String kIconfontCdnBase =
    'https://img.alicdn.com/t/font_<YOUR_PROJECT_ID>';

/// 预留：从阿里 Iconfont（或本地内置资源）生成预设头像 URL 列表
///
/// 当前返回空列表（尚未接入具体项目）。接入步骤：
/// 1. 在 Iconfont 创建项目，获取 PID；
/// 2. 将 [kIconfontCdnBase] 的 `<YOUR_PROJECT_ID>` 替换为真实 PID；
/// 3. 在此列出图标 `name` 列表并返回拼接后的 URL。
List<String> getIconfontPresets() {
  // TODO(avatar): 接入阿里 Iconfont 项目后，在此填充图标 name 列表并拼接 URL。
  return const <String>[];
}
