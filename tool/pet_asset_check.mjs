#!/usr/bin/env node
/**
 * 宠物 2D 素材验收（纯 node 内置模块，零 npm 依赖）。
 *
 * 为什么需要它：3D 期的素材验收页（pet_asset_audit_screen + glb_inspector）随
 * 3D 一期下线被删了，但「素材命名即契约」（宠物铁律 9）没丢——降维到 2D 换的是
 * 载体，不是验收。犬/兔/鼠 开系要量产 40 形态素材，靠人眼对文件名必翻车。
 *
 * 校验三块：光栅体积/边长阈值、分层弯曲树契约（checkBendTree）、
 * 物品图标两端一致。底图与整图帧序列清单已随两条路的下线移除。
 *
 * 用法（仓库内任意位置）：
 *   node tool/pet_asset_check.mjs         校验并打印报告
 *
 * 退出码：0 = 无 FAIL；1 = 有 FAIL（可挂进提交前流程）
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ASSETS = path.join(ROOT, 'assets', 'pets');
const BEND = path.join(ROOT, 'lib', 'constants', 'pet_bend.dart');
const PUBSPEC = path.join(ROOT, 'pubspec.yaml');
const ADMIN_ICONS = path.resolve(ROOT, '..', 'pure-enjoy-admin', 'public', 'pet-icons');

/// 阈值口径（分两类预算）：
/// - 角色图：单张 WARN 260KB / FAIL 600KB、边长 WARN 768 / FAIL 1536
///   （实测 1024² 透明帧 909KB、降采样到 768² 后 462KB，即这套阈值对应「768 够用」；
///   弯曲树 384² 表情帧远低于此线，只拦意外混入的大图）。
/// - 场景背景（scenes/）：全屏 cover、无透明通道，边长必须 ≥ 屏幕短边，
///   不适用角色图的 768 口径，单列 1.6MB 上限（实测 scene_dream 832×1216 = 1418KB）。
const LIMITS = {
  role: { edgeWarn: 768, edgeFail: 1536, sizeWarn: 260 * 1024, sizeFail: 600 * 1024 },
  scene: { edgeWarn: 1536, edgeFail: 2048, sizeWarn: 1024 * 1024, sizeFail: 1600 * 1024 },
};

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

/** 光栅体检：格式嗅探 + 体积/边长阈值（角色图与场景两套口径） */
function checkRaster(file) {
  const info = probe(file);
  const name = path.basename(file);
  const r = rel(file);
  const kb = (info.size / 1024).toFixed(0);

  if (info.sig === 'UNKNOWN') add('FAIL', `${r}: 无法识别的图片格式`);
  if (name.endsWith('.png') && info.sig !== 'PNG')
    add('FAIL', `${r}: 扩展名 .png 实为 ${info.sig}（${kb}KB）——管线会误判，且 JPEG 无透明通道，必须重导出真 PNG`);
  if (info.w === 0) return { info, name };

  const edge = Math.max(info.w, info.h);
  const lim = inDir(file, 'scenes') ? LIMITS.scene : LIMITS.role;
  if (edge > lim.edgeFail) add('FAIL', `${r}: ${info.w}×${info.h} 超边长上限 ${lim.edgeFail}（整幅解码 ${(info.w * info.h * 4 / 1048576).toFixed(1)}MB RGBA）`);
  else if (edge > lim.edgeWarn) add('WARN', `${r}: ${info.w}×${info.h} 大于 ${lim.edgeWarn}，按显示尺寸够用时可再降`);
  if (info.size > lim.sizeFail) add('FAIL', `${r}: ${kb}KB 超体积上限 ${lim.sizeFail / 1024}KB`);
  else if (info.size > lim.sizeWarn) add('WARN', `${r}: ${kb}KB 偏大（上限 ${lim.sizeWarn / 1024}KB）`);
  return { info, name };
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
 * 分层弯曲素材契约（`assets/pets/anim/<系>/<评级>/<种属 code>/<阶 sN>/`）。
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

/// 字典同步守卫：kLongDropNames（App 兜底字典）须覆盖 SQL 工作区所有
/// long_only 掉落 code（服务端联查 name 已是主源，此处防兜底字典漏同步）
function checkLongDropDict() {
  const SQL_DIR = path.resolve(ROOT, '..', 'sql', 'pet');
  if (!fs.existsSync(SQL_DIR)) return; // 工作区不在旁侧时跳过（CI 等场景）
  const dart = fs.readFileSync(path.join(ROOT, 'lib', 'constants', 'pet.dart'), 'utf8');
  const m = /kLongDropNames = <String, String>\{([\s\S]*?)\};/.exec(dart);
  if (!m) {
    add('FAIL', 'constants/pet.dart 未找到 kLongDropNames，长途掉落名字典缺失');
    return;
  }
  const dict = new Set([...m[1].matchAll(/'([a-z0-9_]+)'/g)].map((x) => x[1]));
  const codes = new Set();
  for (const f of fs.readdirSync(SQL_DIR).filter((f) => f.endsWith('.sql'))) {
    const src = fs.readFileSync(path.join(SQL_DIR, f), 'utf8').replace(/\r/g, '');
    for (const ln of src.split('\n')) {
      if (!ln.includes('long_only')) continue;
      // 整张 drop_table 可能压在同一行：只取 long_only 数组段内的 code，
      // 常规掉落（help/play/memory items）的 code 不属于长途独占清单
      const seg = /long_only[^[]*\[([^\]]*)\]/.exec(ln);
      if (!seg) continue;
      for (const c of seg[1].matchAll(/"code"\s*:\s*"([a-z0-9_]+)"/g)) codes.add(c[1]);
    }
  }
  const missing = [...codes].filter((c) => !dict.has(c));
  if (missing.length) {
    add('WARN', `kLongDropNames 漏同步 long_only 掉落码: ${missing.join(', ')}（服务端联查为主，此处仅兜底完整性）`);
  } else if (codes.size > 0) {
    add('PASS', `长途掉落名字典同步: ${codes.size} 个 long_only 码全覆盖`);
  }
}

const files = walk(ASSETS).filter(
  (f) => /\.(png|jpe?g|webp)$/i.test(f) && !inDir(f, 'items'),
);
for (const f of files) checkRaster(f);
checkBendTree();
checkIcons();
checkLongDropDict();

const order = { FAIL: 0, WARN: 1, PASS: 2 };
for (const i of issues.sort((a, b) => order[a.level] - order[b.level]))
  console.log(`${i.level.padEnd(4)} ${i.msg}`);
const fails = issues.filter((i) => i.level === 'FAIL').length;
const warns = issues.filter((i) => i.level === 'WARN').length;
console.log(`\n共 ${issues.length} 条：FAIL ${fails} / WARN ${warns}`);
process.exit(fails > 0 ? 1 : 0);
