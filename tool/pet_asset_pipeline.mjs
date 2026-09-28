#!/usr/bin/env node
/**
 * 宠物 2D 素材处理管线（纯 node 内置 zlib，零 npm 依赖）。
 *
 * 只做两件事，且默认不覆盖原图（输出到候选目录，人眼过一遍再决定换不换）：
 *   --refilter   无损：逐扫描行挑最优 PNG 滤波器重编码（像素完全不变）
 *   --scale 768  有损（缩小）：预乘 alpha 的盒式降采样到目标长边，再重编码
 *
 * 用法：
 *   node tool/pet_asset_pipeline.mjs --refilter --in assets/pets/scenes --out /tmp/pets_out
 *   node tool/pet_asset_pipeline.mjs --scale 768 --in assets/pets/frames --out /tmp/pets_out
 *
 * 处理不了什么：扩展名叫 .png 但内容是 JPEG 的文件（月萤三阶底图就是）——
 * 解 JPEG 需要 DCT/哈夫曼解码器，不是一层 zlib 的事，加依赖又违背"零依赖脚本"。
 * 这类文件一律跳过并在报告里点名，请从源头（AI 出图目录）重导出真 PNG。
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const argv = process.argv.slice(2);
const flag = (name, dft) => {
  const i = argv.indexOf(`--${name}`);
  return i === -1 ? dft : argv[i + 1];
};
const MODE = argv.includes('--sheet') ? 'sheet' : argv.includes('--scale') ? 'scale' : 'refilter';
const TARGET = Number(flag('scale', 768));
const IN = path.resolve(flag('in', 'assets/pets/frames'));
const OUT = path.resolve(flag('out', '/tmp/pets_out'));

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = ~0;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return ~c >>> 0;
}

function chunk(type, data) {
  const head = Buffer.alloc(8);
  head.writeUInt32BE(data.length, 0);
  head.write(type, 4, 'ascii');
  const body = Buffer.concat([head, data]);
  const tail = Buffer.alloc(4);
  tail.writeUInt32BE(crc32(body.subarray(4)), 0);
  return Buffer.concat([body, tail]);
}

/** Paeth 预测器，PNG 解码与逐行选滤波都要用 */
const paeth = (a, b, c) => {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
};

/** 解出 RGBA/RGB 位图；不支持的（JPEG 内容、16bit、隔行、调色板）返回 null */
function decodePng(buf) {
  if (!(buf[0] === 0x89 && buf[1] === 0x50)) return null;
  let off = 8;
  let ihdr = null;
  const idat = [];
  while (off + 8 <= buf.length) {
    const len = buf.readUInt32BE(off);
    const type = buf.subarray(off + 4, off + 8).toString('ascii');
    const data = buf.subarray(off + 8, off + 8 + len);
    if (type === 'IHDR') {
      ihdr = {
        w: data.readUInt32BE(0),
        h: data.readUInt32BE(4),
        depth: data[8],
        color: data[9],
        interlace: data[12],
      };
    } else if (type === 'IDAT') {
      idat.push(Buffer.from(data));
    } else if (type === 'IEND') {
      break;
    }
    off += 12 + len;
  }
  if (!ihdr || ihdr.depth !== 8 || ihdr.interlace !== 0) return null;
  const bpp = ihdr.color === 6 ? 4 : ihdr.color === 2 ? 3 : 0;
  if (!bpp) return null;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = ihdr.w * bpp;
  if (raw.length !== ihdr.h * (stride + 1)) return null;
  const out = Buffer.alloc(ihdr.h * stride);
  for (let y = 0; y < ihdr.h; y++) {
    const ft = raw[y * (stride + 1)];
    const src = y * (stride + 1) + 1;
    const cur = y * stride;
    const up = cur - stride;
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[cur + x - bpp] : 0;
      const b = y > 0 ? out[up + x] : 0;
      const c = x >= bpp && y > 0 ? out[up + x - bpp] : 0;
      const v = raw[src + x];
      const d =
        ft === 0
          ? v
          : ft === 1
            ? v + a
            : ft === 2
              ? v + b
              : ft === 3
                ? v + ((a + b) >> 1)
                : v + paeth(a, b, c);
      out[cur + x] = d & 0xff;
    }
  }
  return { ...ihdr, bpp, pixels: out };
}

/** 盒式降采样：RGBA 先预乘 alpha 再加权平均，避免透明区的脏色渗出黑边 */
function resizeBox(img, tw, th) {
  const { w, h, bpp, pixels: src } = img;
  const out = Buffer.alloc(tw * th * bpp);
  for (let ty = 0; ty < th; ty++) {
    const y0 = Math.floor((ty * h) / th);
    const y1 = Math.max(y0 + 1, Math.floor(((ty + 1) * h) / th));
    for (let tx = 0; tx < tw; tx++) {
      const x0 = Math.floor((tx * w) / tw);
      const x1 = Math.max(x0 + 1, Math.floor(((tx + 1) * w) / tw));
      const n = (y1 - y0) * (x1 - x0);
      const acc = [0, 0, 0, 0];
      for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
          const i = (y * w + x) * bpp;
          const a = bpp === 4 ? src[i + 3] : 255;
          acc[0] += src[i] * a;
          acc[1] += src[i + 1] * a;
          acc[2] += src[i + 2] * a;
          acc[3] += a;
        }
      }
      const o = (ty * tw + tx) * bpp;
      const aAvg = acc[3] / n;
      if (bpp === 4) {
        out[o + 3] = Math.round(aAvg);
        const k = aAvg > 0 ? 255 / aAvg : 0;
        out[o] = acc[3] > 0 ? Math.min(255, Math.round((acc[0] / acc[3]) * k)) : 0;
        out[o + 1] = acc[3] > 0 ? Math.min(255, Math.round((acc[1] / acc[3]) * k)) : 0;
        out[o + 2] = acc[3] > 0 ? Math.min(255, Math.round((acc[2] / acc[3]) * k)) : 0;
      } else {
        out[o] = Math.round(acc[0] / n / 255);
        out[o + 1] = Math.round(acc[1] / n / 255);
        out[o + 2] = Math.round(acc[2] / n / 255);
      }
    }
  }
  return { w: tw, h: th, bpp, pixels: out };
}

/** 重编码：逐扫描行挑最优滤波器（最小绝对和启发式）+ zlib level 9 */
function encodePng({ w, h, bpp, pixels }) {
  const stride = w * bpp;
  const rows = [];
  for (let y = 0; y < h; y++) {
    const cur = y * stride;
    const row = pixels.subarray(cur, cur + stride);
    const up = y > 0 ? pixels.subarray(cur - stride, cur) : Buffer.alloc(stride);
    let best = null;
    let bestScore = Infinity;
    let bestType = 0;
    for (let ft = 0; ft <= 4; ft++) {
      const cand = Buffer.allocUnsafe(stride);
      let score = 0;
      for (let x = 0; x < stride; x++) {
        const a = x >= bpp ? row[x - bpp] : 0;
        const b = up[x];
        const c = x >= bpp ? up[x - bpp] : 0;
        const pred =
          ft === 0 ? 0 : ft === 1 ? a : ft === 2 ? b : ft === 3 ? (a + b) >> 1 : paeth(a, b, c);
        const d = (row[x] - pred) & 0xff;
        cand[x] = d;
        score += d > 128 ? 256 - d : d;
      }
      if (score < bestScore) {
        bestScore = score;
        best = cand;
        bestType = ft;
      }
    }
    rows.push(Buffer.from([bestType]), best);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = bpp === 4 ? 6 : 2;
  const idat = zlib.deflateSync(Buffer.concat(rows), { level: 9 });
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', idat),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

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
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const cell = sliceCell(img, c * cw, r * ch, cw, ch);
      const kept = dropSmallIslands(cell);
      const b = contentBox(cell);
      if (b.w <= 0) {
        console.log(`SKIP 格 ${r * COLS + c + 1}: 整格被判为背景`);
        continue;
      }
      cells.push({ cell, box: b, kept });
    }
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
