#!/usr/bin/env node
/**
 * 宠物 2D 素材验收 + 随包清单重生成（纯 node 内置模块，零 npm 依赖）。
 *
 * 为什么需要它：3D 期的素材验收页（pet_asset_audit_screen + glb_inspector）随
 * 3D 一期下线被删了，但「素材命名即契约」（宠物铁律 9）没丢——降维到 2D 换的是
 * 载体，不是验收。犬/兔/鼠 开系要量产 40 形态 × 多动作素材，靠人眼对文件名必翻车。
 *
 * 用法（仓库内任意位置）：
 *   node tool/pet_asset_check.mjs         只校验并打印报告
 *   node tool/pet_asset_check.mjs --fix   校验 + 按目录实际文件重生成
 *                                         lib/features/pets/utils/pet_art.dart 的清单区块
 *
 * 退出码：0 = 无 FAIL；1 = 有 FAIL（可挂进提交前流程）
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ASSETS = path.join(ROOT, 'assets', 'pets');
const INVENTORY = path.join(ROOT, 'lib', 'features', 'pets', 'utils', 'pet_art.dart');
const ACTION_ENUM = path.join(ROOT, 'lib', 'constants', 'pet_render.dart');
const BEND = path.join(ROOT, 'lib', 'constants', 'pet_bend.dart');
const PUBSPEC = path.join(ROOT, 'pubspec.yaml');
const ADMIN_ICONS = path.resolve(ROOT, '..', 'pure-enjoy-admin', 'public', 'pet-icons');

/// 阈值口径（2026-09-24 按实测数据校准，分两类预算）：
/// - 角色图（底图 + 帧序列）：单只形态 3 阶底图 + 有帧动作合计目标 <1MB，
///   因此单张 WARN 260KB / FAIL 600KB、边长 WARN 768 / FAIL 1536；
///   实测 1024² 透明帧 909KB、降采样到 768² 后 462KB，即这套阈值对应「768 够用」。
/// - 场景背景（scenes/）：全屏 cover、无透明通道，边长必须 ≥ 屏幕短边，
///   不适用角色图的 768 口径，单列 1.6MB 上限（实测 scene_dream 832×1216 = 1418KB）。
const LIMITS = {
  role: { edgeWarn: 768, edgeFail: 1536, sizeWarn: 260 * 1024, sizeFail: 600 * 1024 },
  scene: { edgeWarn: 1536, edgeFail: 2048, sizeWarn: 1024 * 1024, sizeFail: 1600 * 1024 },
};

const BEGIN = '// BEGIN generated:pet-art';
const END = '// END generated:pet-art';
const fix = process.argv.includes('--fix');
const issues = [];

function add(level, msg) {
  issues.push({ level, msg });
}

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)],
  );
}

const rel = (p) => path.relative(ROOT, p).replace(/\\/g, '/');

const inDir = (file, dir) => file.includes(`${dir}${path.sep}`);

/** 嗅探真实格式并读尺寸（Flutter 按内容解码，扩展名骗得过低层但骗不了清单） */
function probe(file) {
  const buf = fs.readFileSync(file);
  let sig = 'UNKNOWN';
  if (buf[0] === 0x89 && buf[1] === 0x50) sig = 'PNG';
  else if (buf[0] === 0xff && buf[1] === 0xd8) sig = 'JPEG';
  else if (buf.subarray(0, 4).toString('ascii') === 'RIFF') sig = 'WEBP';
  else if (buf.subarray(0, 5).toString('ascii') === '<?xml') sig = 'SVG';
  let w = 0;
  let h = 0;
  let alpha = null;
  if (sig === 'PNG') {
    w = buf.readUInt32BE(16);
    h = buf.readUInt32BE(20);
    alpha = buf[25] === 6 || buf[25] === 4; // color type 带 alpha 通道
  } else if (sig === 'JPEG') {
    for (let i = 2; i + 9 < buf.length; ) {
      if (buf[i] !== 0xff) {
        i += 1;
        continue;
      }
      const marker = buf[i + 1];
      const isSof = marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker);
      if (isSof) {
        h = buf.readUInt16BE(i + 5);
        w = buf.readUInt16BE(i + 7);
        alpha = false;
        break;
      }
      i += 2 + buf.readUInt16BE(i + 2);
    }
  } else if (sig === 'WEBP' && buf.subarray(12, 16).toString('ascii') === 'VP8X') {
    w = 1 + buf.readUIntLE(24, 3);
    h = 1 + buf.readUIntLE(27, 3);
    alpha = (buf[20] & 0x10) !== 0;
  } else if (sig === 'WEBP' && buf.subarray(12, 16).toString('ascii') === 'VP8 ') {
    w = buf.readUInt16LE(26) & 0x3fff;
    h = buf.readUInt16LE(28) & 0x3fff;
    alpha = false;
  }
  return { sig, w, h, alpha, size: buf.length };
}

/** 动作值域只有一个真源：lib/constants/pet_render.dart 的 PetAction（铁律 12） */
function actionCodes() {
  const src = fs.readFileSync(ACTION_ENUM, 'utf8');
  const codes = [...src.matchAll(/^  [a-zA-Z]+\('([a-z_]+)'/gm)].map((m) => m[1]);
  if (codes.length === 0) throw new Error('PetAction 枚举解析失败：检查 constants/pet_render.dart');
  return new Set(codes);
}

const STAGE_RE = /^(.+)_(\d{2})\.png$/; // cat_ssr1_01.png -> 基础形 + 阶位
const FRAME_RE = /^(.+)_(.+)_([0-9]+)\.png$/; // cat_ssr1_idle_1.png -> 种属 + 动作 + 帧号

function checkRaster(file, codes) {
  const info = probe(file);
  const name = path.basename(file);
  const inFrames = inDir(file, 'frames');
  const r = rel(file);
  const kb = (info.size / 1024).toFixed(0);

  if (info.sig === 'UNKNOWN') add('FAIL', `${r}: 无法识别的图片格式`);
  if (name.endsWith('.png') && info.sig !== 'PNG')
    add('FAIL', `${r}: 扩展名 .png 实为 ${info.sig}（${kb}KB）——清单与管线都会误判，且 JPEG 无透明通道，必须重导出真 PNG`);
  if (info.w === 0) return { info, name, inFrames };

  const edge = Math.max(info.w, info.h);
  const lim = inDir(file, 'scenes') ? LIMITS.scene : LIMITS.role;
  if (edge > lim.edgeFail) add('FAIL', `${r}: ${info.w}×${info.h} 超边长上限 ${lim.edgeFail}（整幅解码 ${(info.w * info.h * 4 / 1048576).toFixed(1)}MB RGBA）`);
  else if (edge > lim.edgeWarn) add('WARN', `${r}: ${info.w}×${info.h} 大于 ${lim.edgeWarn}，按显示尺寸够用时可再降`);
  if (info.size > lim.sizeFail) add('FAIL', `${r}: ${kb}KB 超体积上限 ${lim.sizeFail / 1024}KB`);
  else if (info.size > lim.sizeWarn) add('WARN', `${r}: ${kb}KB 偏大（上限 ${lim.sizeWarn / 1024}KB）`);

  if (inFrames) {
    if (info.alpha === false) add('FAIL', `${r}: 帧序列无透明通道，舞台上会把背景方块一起放大`);
    const m = FRAME_RE.exec(name);
    if (!m) add('FAIL', `${r}: 帧文件名不合契约 <species_code>_<action>_N.png`);
    else if (!codes.has(m[2])) add('FAIL', `${r}: 动作码「${m[2]}」不在 PetAction 值域内（改名须三端同批，铁律 12）`);
  }
  return { info, name, inFrames };
}

function collectInventory(codes) {
  const stageArt = new Map(); // species -> [{stage, file}]
  const frames = new Map(); // species -> Map(action -> Set(N))
  // 场景图不参与清单（它是全屏背景，按 BoxFit.cover 用，与种属无关）；
  // anim/ 是分层弯曲的 6 档表情帧，契约由 checkBendTree 单独校验——它按
  // 评级/种属/阶 分目录、文件名不带种属前缀，不该套进「底图 + 动作帧」两套清单
  const files = walk(ASSETS).filter(
    (f) =>
      /\.(png|jpe?g|webp)$/i.test(f) &&
      !inDir(f, 'items') &&
      !inDir(f, 'scenes') &&
      !inDir(f, 'anim'),
  );
  for (const f of files) {
    const name = path.basename(f);
    if (inDir(f, 'frames')) {
      const m = FRAME_RE.exec(name);
      if (!m || !codes.has(m[2])) continue;
      if (!frames.has(m[1])) frames.set(m[1], new Map());
      if (!frames.get(m[1]).has(m[2])) frames.get(m[1]).set(m[2], new Set());
      frames.get(m[1]).get(m[2]).add(Number(m[3]));
      continue;
    }
    const m = STAGE_RE.exec(name);
    if (!m) {
      add('FAIL', `${rel(f)}: 底图文件名不合契约 <species_code>_<NN>.png（NN 从 01 起=stage0）`);
      continue;
    }
    if (!stageArt.has(m[1])) stageArt.set(m[1], []);
    stageArt.get(m[1]).push({ stage: Number(m[2]) - 1, file: rel(f) });
  }
  for (const [code, acts] of frames) {
    for (const [action, ns] of acts) {
      const sorted = [...ns].sort((a, b) => a - b);
      if (sorted[0] !== 1) add('FAIL', `${code}_${action}: 帧号应从 1 起，实际最小 ${sorted[0]}`);
      for (let i = 1; i < sorted.length; i++)
        if (sorted[i] !== sorted[i - 1] + 1) add('FAIL', `${code}_${action}: 帧号断档（${sorted[i - 1]} 之后直接 ${sorted[i]}）`);
      if (!stageArt.has(code)) add('WARN', `${code}: 只有 ${action} 帧、没有整只底图（无帧动作会没有身体可补间）`);
    }
  }
  return { stageArt, frames, count: files.length };
}

function dartInventory({ stageArt, frames }) {
  const byCode = (a, b) => a[0].localeCompare(b[0]);
  const stageBody = [...stageArt.entries()]
    .sort(byCode)
    .map(
      ([code, list]) =>
        `  '${code}': [\n` +
        list
          .slice()
          .sort((a, b) => a.stage - b.stage)
          .map((e) => `    '${e.file}',`)
          .join('\n') +
        `\n  ],`,
    )
    .join('\n');
  const frameBody = [...frames.entries()]
    .sort(byCode)
    .map(
      ([code, acts]) =>
        `  '${code}': {` +
        [...acts.entries()]
          .sort(byCode)
          .map(([action, ns]) => `'${action}': ${Math.max(...ns)}`)
          .join(', ') +
        `},`,
    )
    .join('\n');
  return `const Map<String, List<String>> kPetStageArt = {
${stageBody}
};

const Map<String, Map<String, int>> kPetActionFrames = {
${frameBody}
};`;
}

function checkInventoryDart(inv) {
  const src = fs.readFileSync(INVENTORY, 'utf8');
  const block = src.slice(src.indexOf(BEGIN) + BEGIN.length, src.indexOf(END));
  if (!src.includes(BEGIN) || !src.includes(END)) {
    add('FAIL', 'pet_art.dart 缺少 generated:pet-art 标记，无法校验清单');
    return;
  }
  const want = dartInventory(inv).trim();
  const normalize = (s) => s.replace(/\s+/g, '').replace(/,$/gm, '');
  if (normalize(block) === normalize(want)) {
    add('PASS', `pet_art.dart 清单与 ${inv.count} 个随包素材一致`);
    return;
  }
  if (!fix) {
    add('FAIL', `pet_art.dart 清单与 assets/pets 实际文件不一致（跑 node tool/pet_asset_check.mjs --fix 重生成）`);
    return;
  }
  fs.writeFileSync(
    INVENTORY,
    src.replace(new RegExp(`${BEGIN}[\\s\\S]*${END}`), `${BEGIN}\n\n${want}\n\n${END}`),
  );
  console.log('已按目录实际文件重生成清单区块，请再跑 dart format + flutter analyze');
}

function checkIcons() {
  const app = new Set(fs.readdirSync(path.join(ASSETS, 'items')).map((f) => f.replace(/\.svg$/, '')));
  if (!fs.existsSync(ADMIN_ICONS)) {
    add('WARN', `未找到后台图标目录 ${ADMIN_ICONS}，跳过两端 diff`);
    return;
  }
  const admin = new Set(fs.readdirSync(ADMIN_ICONS).map((f) => f.replace(/\.svg$/, '')));
  const onlyAdmin = [...admin].filter((k) => !app.has(k));
  const onlyApp = [...app].filter((k) => !admin.has(k));
  if (onlyAdmin.length) add('FAIL', `App 缺图标 ${onlyAdmin.length} 个（商城/背包会空白）：${onlyAdmin.join(', ')}`);
  if (onlyApp.length) add('FAIL', `Admin public/pet-icons 缺 ${onlyApp.length} 个（后台预览空白）：${onlyApp.join(', ')}`);
  if (!onlyAdmin.length && !onlyApp.length) add('PASS', `物品图标两端一致：${app.size} 个`);
}

/**
 * 分层弯曲素材契约（`assets/pets/anim/<评级>/<种属 code>/<阶 sN>/`）。
 *
 * 为什么单列一道校验：弯曲渲染把「表情分档」当结构用——编排表的 `expr` 通道按
 * **下标**点名第几档，缺任一档就在切档瞬间画出透明像素（闪一下空帧）；而 6 档帧
 * 的几何全部定义在该形态的生产栅格 side 上，尺寸一变就逐像素错位。再加上
 * flutter assets 不递归，漏登记一行目录＝运行期 rootBundle 取不到图。
 * 三类错误都在真机上才看得见，故在这里前置成 FAIL。
 */
function checkBendTree() {
  const start = issues.length;
  const src = fs.readFileSync(BEND, 'utf8');
  const list = /kPetBendFrameFiles = \[([\s\S]*?)\];/.exec(src);
  if (!list) {
    add('FAIL', 'pet_bend.dart 未找到 kPetBendFrameFiles，弯曲契约无法校验');
    return;
  }
  const want = [...list[1].matchAll(/'([a-z0-9_]+)'/g)].map((m) => m[1]);
  const specs = [
    ...src.matchAll(/dir:\s*'([^']+)',[^}]*?side:\s*(\d+)/g),
  ].map((m) => ({ dir: m[1], side: Number(m[2]) }));
  if (!specs.length) {
    add('FAIL', 'pet_bend.dart 未解析到任何 PetBendGeo.dir');
    return;
  }
  const pub = fs.readFileSync(PUBSPEC, 'utf8');
  for (const { dir, side } of specs) {
    const abs = path.join(ROOT, dir);
    if (!fs.existsSync(abs)) {
      add('FAIL', `${dir}: kPetBendGeo 登记了目录但包内不存在（六档全解码失败＝舞台空白）`);
      continue;
    }
    if (!pub.includes(`- ${dir}/`)) {
      add('FAIL', `${dir}: 未登记进 pubspec 的 assets（flutter assets 不递归，漏一行就取不到图）`);
    }
    const names = fs.readdirSync(abs).map((f) => f.replace(/\.png$/i, ''));
    const missing = want.filter((n) => !names.includes(n));
    const extra = names.filter((n) => !want.includes(n));
    if (missing.length) {
      add('FAIL', `${dir}: 缺表情帧 ${missing.join(', ')}（编排按下标点名，缺档＝切档闪空帧）`);
    }
    if (extra.length) {
      add('WARN', `${dir}: 有未登记文件 ${extra.join(', ')}（不会被播放，白占包体）`);
    }
    for (const n of want) {
      const f = path.join(abs, `${n}.png`);
      if (!fs.existsSync(f)) continue;
      const info = probe(f);
      if (info.sig !== 'PNG') add('FAIL', `${dir}/${n}.png: 实为 ${info.sig}，弯曲渲染要求透明 PNG`);
      else if (info.alpha === false) add('FAIL', `${dir}/${n}.png: 无透明通道，舞台上会闪出方框背景`);
      if (info.w && (info.w !== side || info.h !== side)) {
        add('FAIL', `${dir}/${n}.png: ${info.w}×${info.h} 与该形态栅格 ${side}² 不符（归零线/眼区/支点全定义在 ${side} 上）`);
      }
    }
  }
  const root = path.join(ASSETS, 'anim');
  if (!fs.existsSync(root)) {
    add('WARN', 'assets/pets/anim 不存在，弯曲路径无素材（整图补间兜底）');
    return;
  }
  const dirs = [...new Set(walk(root).filter((f) => /\.png$/i.test(f)).map(path.dirname))];
  const known = new Set(specs.map((s) => path.join(ROOT, s.dir)));
  for (const d of dirs) {
    if (!known.has(d)) add('WARN', `${rel(d)}: 磁盘上有弯曲目录但没登记进 kPetBendGeo（不会被播放）`);
  }
  if (!issues.slice(start).some((i) => i.level === 'FAIL')) {
    add('PASS', `弯曲素材契约一致：${specs.length} 形态 × ${want.length} 档表情帧，均已登记 pubspec`);
  }
}

const codes = actionCodes();
const files = walk(ASSETS).filter(
  (f) => /\.(png|jpe?g|webp)$/i.test(f) && !inDir(f, 'items'),
);
for (const f of files) checkRaster(f, codes);
const inv = collectInventory(codes);
checkInventoryDart(inv);
checkBendTree();
checkIcons();

const order = { FAIL: 0, WARN: 1, PASS: 2 };
for (const i of issues.sort((a, b) => order[a.level] - order[b.level]))
  console.log(`${i.level.padEnd(4)} ${i.msg}`);
const fails = issues.filter((i) => i.level === 'FAIL').length;
const warns = issues.filter((i) => i.level === 'WARN').length;
console.log(`\n共 ${issues.length} 条：FAIL ${fails} / WARN ${warns}`);
console.log(`动作值域 ${codes.size} 个：${[...codes].join(', ')}`);
process.exit(fails > 0 ? 1 : 0);
