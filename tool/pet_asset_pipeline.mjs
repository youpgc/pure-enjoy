#!/usr/bin/env node
/**
 * 宠物 2D 素材处理管线（纯 node 内置 zlib，零 npm 依赖）。
 *
 * 只做三件事，且默认不覆盖原图（输出到候选目录，人眼过一遍再决定换不换）：
 *   --refilter   无损：逐扫描行挑最优 PNG 滤波器重编码（像素完全不变）
 *   --scale 768  有损（缩小）：预乘 alpha 的盒式降采样到目标长边，再重编码
 *   --sheet / --parts  AI 姿态表/部件表 → 逐帧素材 / 剪贴部件（见各模式注释）
 *
 * 用法：
 *   node tool/pet_asset_pipeline.mjs --refilter --in assets/pets/scenes --out /tmp/pets_out
 *   node tool/pet_asset_pipeline.mjs --scale 768 --in assets/pets/frames --out /tmp/pets_out
 *   node tool/pet_asset_pipeline.mjs --sheet --in 表.png --out 目录 --cols 4 --rows 2 --height 328
 *   node tool/pet_asset_pipeline.mjs --parts --in 部件表.png --out 目录 --cols 4 --rows 2
 *
 * 处理不了什么：扩展名叫 .png 但内容是 JPEG 的文件（月萤三阶底图就是）——
 * 解 JPEG 需要 DCT/哈夫曼解码器，不是一层 zlib 的事，加依赖又违背"零依赖脚本"。
 * 这类文件一律跳过并在报告里点名，请从源头（AI 出图目录）重导出真 PNG。
 */
import fs from 'node:fs';
import path from 'node:path';
import { decodePng, resizeBox, encodePng } from './pet_png.mjs';

const argv = process.argv.slice(2);
const flag = (name, dft) => {
  const i = argv.indexOf(`--${name}`);
  return i === -1 ? dft : argv[i + 1];
};
const MODE = argv.includes('--parts')
  ? 'parts'
  : argv.includes('--sheet')
    ? 'sheet'
    : argv.includes('--scale')
      ? 'scale'
      : 'refilter';
const TARGET = Number(flag('scale', 768));
const IN = path.resolve(flag('in', 'assets/pets/frames'));
const OUT = path.resolve(flag('out', '/tmp/pets_out'));

/* ---------- sheet 模式：AI 姿态表 → 逐帧素材 ----------
 * 三步都在解决 AI 出图的既有毛病，缺一步动画就会抖：
 *  1) 抠像用「从格子边缘洪水填充」而不是全局白色阈值——白猫配白底，
 *     全局阈值会把白毛一起抠没；而内部白毛被描边围住，边缘洪水到不了。
 *  2) 只保留面积足够大的连通块，顺手把水印/杂点抠掉。
 *  3) 各帧内容包围盒重新按统一比例缩放 + 底部对齐到同一地平线，
 *     否则 AI 每格画得略大略小，播起来就是"一帧一个个体重在跳"。
 */
const COLS = Number(flag('cols', 4));
const ROWS = Number(flag('rows', 2));
const KEY_T = Number(flag('key', 225));
const FRAME_H = Number(flag('height', 384));
const PREFIX = flag('prefix', 'frame');
/// 次大连通块的保留门槛：0.15 刚好留住「吃」姿态里的食盆，又能滤掉右下角水印
const KEEP_RATIO = Number(flag('ratio', 0.15));
/// 连通块「填充率」下限：面积 / 包围盒面积。部件实心通常在 0.3 以上，
/// 而格子分隔线是又长又空的细条（<0.1），据此把线判掉而不是按触边猜。
const LINE_FILL = Number(flag('fill', 0.12));
const BY_GRID = argv.includes('--grid');

function sliceCell(img, cx, cy, cw, ch) {
  const at = (x, y) => {
    const s = ((cy + y) * img.w + (cx + x)) * img.bpp;
    return [img.pixels[s], img.pixels[s + 1], img.pixels[s + 2]];
  };
  const isBg = (x, y) => Math.min(...at(x, y)) >= KEY_T;
  const keyed = new Uint8Array(cw * ch);
  const stack = new Int32Array(cw * ch);
  let sp = 0;
  const push = (x, y) => {
    const q = y * cw + x;
    if (!keyed[q] && isBg(x, y)) {
      keyed[q] = 1;
      stack[sp++] = q;
    }
  };
  for (let x = 0; x < cw; x++) { push(x, 0); push(x, ch - 1); }
  for (let y = 0; y < ch; y++) { push(0, y); push(cw - 1, y); }
  while (sp > 0) {
    const q = stack[--sp];
    const x = q % cw;
    const y = (q - x) / cw;
    if (x > 0) push(x - 1, y);
    if (x < cw - 1) push(x + 1, y);
    if (y > 0) push(x, y - 1);
    if (y < ch - 1) push(x, y + 1);
  }
  const out = Buffer.alloc(cw * ch * 4);
  for (let y = 0; y < ch; y++) {
    for (let x = 0; x < cw; x++) {
      const [r, g, b] = at(x, y);
      const d = (y * cw + x) * 4;
      out[d] = r; out[d + 1] = g; out[d + 2] = b;
      out[d + 3] = keyed[y * cw + x] ? 0 : 255;
    }
  }
  return { w: cw, h: ch, bpp: 4, pixels: out };
}

/** 只保留面积 >= 最大连通块 ratio 的前景（水印、杂点归零） */
function dropSmallIslands(cell, ratio = KEEP_RATIO) {
  const { w, h, pixels } = cell;
  const seen = new Uint8Array(w * h);
  const stack = new Int32Array(w * h);
  const comps = [];
  for (let i = 0; i < w * h; i++) {
    if (seen[i] || pixels[i * 4 + 3] === 0) continue;
    let sp = 0;
    const list = [];
    seen[i] = 1;
    stack[sp++] = i;
    while (sp > 0) {
      const q = stack[--sp];
      list.push(q);
      const x = q % w;
      const y = (q - x) / w;
      const nb = [];
      if (x > 0) nb.push(q - 1);
      if (x < w - 1) nb.push(q + 1);
      if (y > 0) nb.push(q - w);
      if (y < h - 1) nb.push(q + w);
      for (const n of nb) {
        if (!seen[n] && pixels[n * 4 + 3] !== 0) {
          seen[n] = 1;
          stack[sp++] = n;
        }
      }
    }
    comps.push(list);
  }
  const keep = Math.max(64, Math.max(...comps.map((c) => c.length)) * ratio);
  for (const c of comps) {
    if (c.length >= keep) continue;
    for (const q of c) pixels[q * 4 + 3] = 0;
  }
  return comps.reduce((a, c) => a + (c.length >= keep ? 1 : 0), 0);
}

/**
 * 全表连通块分格（取代「按格线硬切」）。
 * AI 画部件表时不守格线：头会溢出到隔壁格，格子之间还有淡淡的分隔线。
 * 按格线切就会把溢出的一截下巴留在错误的格里（表现为部件上多一块毛）。
 * 这里先从整张图的外沿洪水抠像，再对前景做连通块标记，按质心把每一块
 * 分派到它所属的格子——下巴与头本来就相连，自然跟着头走；分隔线是又长又
 * 空的细条，按「填充率」判掉。
 */
function segmentCells(img, cols, rows) {
  const { w, h, bpp, pixels } = img;
  const at = (x, y) => {
    const s = (y * w + x) * bpp;
    return [pixels[s], pixels[s + 1], pixels[s + 2]];
  };
  const isBg = (x, y) => Math.min(...at(x, y)) >= KEY_T;
  const keyed = new Uint8Array(w * h);
  const stack = new Int32Array(w * h);
  let sp = 0;
  const push = (x, y) => {
    const q = y * w + x;
    if (!keyed[q] && isBg(x, y)) {
      keyed[q] = 1;
      stack[sp++] = q;
    }
  };
  for (let x = 0; x < w; x++) { push(x, 0); push(x, h - 1); }
  for (let y = 0; y < h; y++) { push(0, y); push(w - 1, y); }
  while (sp > 0) {
    const q = stack[--sp];
    const x = q % w;
    const y = (q - x) / w;
    if (x > 0) push(x - 1, y);
    if (x < w - 1) push(x + 1, y);
    if (y > 0) push(x, y - 1);
    if (y < h - 1) push(x, y + 1);
  }
  const seen = new Uint8Array(w * h);
  const cw = Math.floor(w / cols);
  const ch = Math.floor(h / rows);
  const cells = [];
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      cells.push({ x0: c * cw, y0: r * ch, w: cw, h: ch, pixels: Buffer.alloc(cw * ch * 4), n: 0 });
    }
  }
  let dropped = 0;
  for (let i = 0; i < w * h; i++) {
    if (seen[i] || keyed[i]) continue;
    sp = 0;
    const list = [];
    let sx = 0, sy = 0, x0 = w, x1 = -1, y0 = h, y1 = -1;
    seen[i] = 1;
    stack[sp++] = i;
    while (sp > 0) {
      const q = stack[--sp];
      list.push(q);
      const x = q % w;
      const y = (q - x) / w;
      sx += x;
      sy += y;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
      const nb = [];
      if (x > 0) nb.push(q - 1);
      if (x < w - 1) nb.push(q + 1);
      if (y > 0) nb.push(q - w);
      if (y < h - 1) nb.push(q + w);
      for (const n of nb) {
        if (!seen[n] && !keyed[n]) {
          seen[n] = 1;
          stack[sp++] = n;
        }
      }
    }
    const bw = x1 - x0 + 1;
    const bh = y1 - y0 + 1;
    // 分隔线/杂点：包围盒很大但像素很稀（填充率），或整体太小
    if (list.length < 200 || list.length / (bw * bh) < LINE_FILL) {
      dropped++;
      continue;
    }
    const cx = Math.floor(sx / list.length / cw);
    const cy = Math.floor(sy / list.length / ch);
    const cell = cells[Math.min(rows - 1, cy) * cols + Math.min(cols - 1, cx)];
    for (const q of list) {
      const x = q % w;
      const y = (q - x) / w;
      const [r, g, b] = at(x, y);
      const d = ((y - cell.y0) * cell.w + (x - cell.x0)) * 4;
      const src = q * bpp;
      cell.pixels[d] = pixels[src];
      cell.pixels[d + 1] = pixels[src + 1];
      cell.pixels[d + 2] = pixels[src + 2];
      cell.pixels[d + 3] = 255;
    }
    cell.n++;
  }
  return { cells, dropped };
}

function contentBox(cell) {
  const { w, h, pixels } = cell;
  let x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (pixels[(y * w + x) * 4 + 3] === 0) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  return { x0, y0, w: x1 - x0 + 1, h: y1 - y0 + 1 };
}

function crop(cell, b) {
  const out = Buffer.alloc(b.w * b.h * 4);
  for (let y = 0; y < b.h; y++) {
    const src = ((b.y0 + y) * cell.w + b.x0) * 4;
    cell.pixels.copy(out, y * b.w * 4, src, src + b.w * 4);
  }
  return { w: b.w, h: b.h, bpp: 4, pixels: out };
}

function blit(canvas, img, dx, dy) {
  for (let y = 0; y < img.h; y++) {
    const ty = dy + y;
    if (ty < 0 || ty >= canvas.h) continue;
    for (let x = 0; x < img.w; x++) {
      const tx = dx + x;
      if (tx < 0 || tx >= canvas.w) continue;
      const s = (y * img.w + x) * 4;
      if (img.pixels[s + 3] === 0) continue;
      const d = (ty * canvas.w + tx) * 4;
      canvas.pixels[d] = img.pixels[s];
      canvas.pixels[d + 1] = img.pixels[s + 1];
      canvas.pixels[d + 2] = img.pixels[s + 2];
      canvas.pixels[d + 3] = 255;
    }
  }
}

function runSheet(inFile, outDir) {
  const img = decodePng(fs.readFileSync(inFile));
  if (!img) {
    console.error(`${inFile} 解不出来：需要 8bit 非隔行 PNG（AI 出的 JPEG 请先转 PNG）`);
    process.exit(1);
  }
  const cw = Math.floor(img.w / COLS);
  const ch = Math.floor(img.h / ROWS);
  const cells = [];
  const grid = [];
  if (BY_GRID) {
    for (let r = 0; r < ROWS; r++)
      for (let c = 0; c < COLS; c++) grid.push(sliceCell(img, c * cw, r * ch, cw, ch));
  } else {
    const seg = segmentCells(img, COLS, ROWS);
    grid.push(...seg.cells);
    console.log(`连通块分格：按细条/碎块规则丢掉 ${seg.dropped} 块`);
  }
  for (let i = 0; i < grid.length; i++) {
    const cell = grid[i];
    const kept = dropSmallIslands(cell);
    const b = contentBox(cell);
    if (b.w <= 0) {
      console.log(`SKIP 格 ${i + 1}: 整格被判为背景`);
      continue;
    }
    cells.push({ cell, box: b, kept });
  }
  const med = (arr) => {
    const a = [...arr].sort((x, y) => x - y);
    return a[Math.floor(a.length / 2)];
  };
  // 以最高格为基准缩放（保证不裁切），同时用中位数体检：AI 若把某一格画大了，
  // 逐帧播起来就是"个体在跳"，这里直接报出来而不是悄悄把整表压小
  const maxH = Math.max(...cells.map((e) => e.box.h));
  const heights = cells.map((e) => e.box.h);
  const drift = maxH / med(heights);
  if (drift > 1.12) {
    console.log(
      `WARN 格间尺寸漂移 ${((drift - 1) * 100).toFixed(0)}%（最高 ${maxH} / 中位 ${med(heights)}）` +
        `——同组帧应由同一批生成，或重出偏大的那一格`,
    );
  }
  const s = FRAME_H / maxH;
  const maxW = Math.max(...cells.map((e) => e.box.w));
  const fw = Math.round(maxW * s) + 8;
  const fh = FRAME_H + 8;
  fs.mkdirSync(outDir, { recursive: true });
  let total = 0;
  cells.forEach((e, i) => {
    const content = crop(e.cell, e.box);
    const rw = Math.round(content.w * s);
    const rh = Math.round(content.h * s);
    const scaled = resizeBox(content, rw, rh);
    const canvas = { w: fw, h: fh, bpp: 4, pixels: Buffer.alloc(fw * fh * 4) };
    blit(canvas, scaled, Math.round((fw - rw) / 2), fh - 4 - rh); // 底部对齐同一地平线
    const name = `${PREFIX}_${String(i + 1).padStart(2, '0')}.png`;
    const enc = encodePng(canvas);
    fs.writeFileSync(path.join(outDir, name), enc);
    total += enc.length;
    console.log(
      `${name} ${fw}×${fh} 内容 ${rw}×${rh} ${(enc.length / 1024).toFixed(0)}KB 前景块 ${e.kept}`,
    );
  });
  console.log(
    `\n${cells.length} 帧，合计 ${(total / 1024).toFixed(0)}KB` +
      `（单帧均 ${(total / cells.length / 1024).toFixed(0)}KB）→ ${outDir}\n` +
      `量产能见：8 动作 × ${cells.length} 帧 = ${8 * cells.length} 张/形态；` +
      `按本表实测单帧推算约 ${(total / cells.length * 8 * cells.length / 1024 / 1024).toFixed(1)}MB/形态`,
  );
}

/* ---------- parts 模式：AI 部件表 → 剪贴动画（cutout puppet）素材 ----------
 * 与 sheet 模式的两点关键差别，都是被"逐帧约定会毁掉部件"逼出来的：
 *  1) 不做统一缩放、不做底部对齐——部件之间要保持原表里的相对位置，
 *     否则头和身各自归到同一地平线后，接起来就是"头埋进身体"。
 *  2) 输出 parts.json：记录每个部件在**原表坐标系**的左上角与尺寸，
 *     Lottie 图层位置 = 部件中心 - 参考部件中心，据此还原骨架。
 */
function runParts(inFile, outDir) {
  const img = decodePng(fs.readFileSync(inFile));
  if (!img) {
    console.error(`${inFile} 解不出来：需要 8bit 非隔行 PNG（AI 出的 JPEG 请先转 PNG）`);
    process.exit(1);
  }
  const cw = Math.floor(img.w / COLS);
  const ch = Math.floor(img.h / ROWS);
  const seg = segmentCells(img, COLS, ROWS);
  console.log(`连通块分格：按细条/碎块规则丢掉 ${seg.dropped} 块`);
  fs.mkdirSync(outDir, { recursive: true });
  const parts = [];
  let total = 0;
  seg.cells.forEach((cell, i) => {
    const kept = dropSmallIslands(cell);
    const b = contentBox(cell);
    if (b.w <= 0) {
      console.log(`SKIP 格 ${i + 1}: 整格被判为背景`);
      return;
    }
    const name = `${PREFIX}_${String(i + 1).padStart(2, '0')}.png`;
    const enc = encodePng(crop(cell, b));
    fs.writeFileSync(path.join(outDir, name), enc);
    total += enc.length;
    parts.push({
      name,
      cell: i,
      x: cell.x0 + b.x0,
      y: cell.y0 + b.y0,
      w: b.w,
      h: b.h,
      blocks: kept,
    });
    console.log(
      `${name} ${b.w}×${b.h} @(${parts[parts.length - 1].x},${parts[parts.length - 1].y}) ` +
        `${(enc.length / 1024).toFixed(0)}KB 前景块 ${kept}`,
    );
  });
  const manifest = { sheetW: img.w, sheetH: img.h, cols: COLS, rows: ROWS, cellW: cw, cellH: ch, parts };
  fs.writeFileSync(path.join(outDir, 'parts.json'), JSON.stringify(manifest, null, 2));
  console.log(
    `\n${parts.length} 个部件，合计 ${(total / 1024).toFixed(0)}KB；坐标清单 parts.json → ${outDir}\n` +
      `注意：部件尺寸未经缩放，量的是原表像素；拼动画时以 sheetW×sheetH 为设计画布。`,
  );
}

if (MODE === 'parts') {
  runParts(IN, OUT);
  process.exit(0);
}

if (MODE === 'sheet') {
  runSheet(IN, OUT);
  process.exit(0);
}

fs.mkdirSync(OUT, { recursive: true });
let done = 0;
let skipped = 0;
for (const f of fs.readdirSync(IN).filter((n) => /\.png$/i.test(n))) {
  const buf = fs.readFileSync(path.join(IN, f));
  const img = decodePng(buf);
  if (!img) {
    console.log(`SKIP ${f}: 不是 8bit 非隔行 PNG（多为「扩展名 .png 实为 JPEG」），须从源头重导出`);
    skipped += 1;
    continue;
  }
  let work = img;
  if (MODE === 'scale') {
    const s = Math.min(1, TARGET / Math.max(img.w, img.h));
    if (s < 1) work = resizeBox(img, Math.round(img.w * s), Math.round(img.h * s));
  }
  const encoded = encodePng(work);
  if (MODE === 'refilter') {
    const back = decodePng(encoded);
    if (!back || !back.pixels.equals(img.pixels)) {
      console.error(`FAIL ${f}: 重编码后像素与源不一致，已丢弃不输出`);
      continue;
    }
  }
  fs.writeFileSync(path.join(OUT, f), encoded);
  console.log(
    `${f}: ${img.w}×${img.h} → ${work.w}×${work.h}，` +
      `${(buf.length / 1024).toFixed(0)}KB → ${(encoded.length / 1024).toFixed(0)}KB` +
      `（${(((encoded.length - buf.length) / buf.length) * 100).toFixed(1)}%）`,
  );
  done += 1;
}
console.log(
  `\n模式 ${MODE === 'scale' ? `降采样到长边 ${TARGET}` : '无损重滤波'}；` +
    `处理 ${done} 个、跳过 ${skipped} 个；输出目录 ${OUT}`,
);
console.log('候选产物需人眼过一遍再替换 assets/pets，替换后跑 node tool/pet_asset_check.mjs --fix');
