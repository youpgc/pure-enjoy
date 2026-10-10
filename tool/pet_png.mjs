#!/usr/bin/env node
/**
 * 极简 PNG 编解码（只用 node 内置 zlib，零 npm 依赖），供 tool/pet_asset_*.mjs 共用。
 *
 * 为什么自己写：素材管线要能在任何一台开发机上 `node xxx.mjs` 直接跑，不装依赖；
 * 而我们要的只是 8bit 非隔行 PNG 的解码 + 重编码，一层 zlib 就够。
 * 解不了的（JPEG 内容、16bit、隔行、调色板）一律返回 null，由调用方点名跳过——
 * 尤其"扩展名 .png 实为 JPEG"是我们素材库里真实存在的坑。
 */
import zlib from 'node:zlib';

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
export function decodePng(buf) {
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
export function resizeBox(img, tw, th) {
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
        /* 预乘均值还原成直色只需除一次覆盖率：avgPremul = Σ(rgb·a/255)/n，直色 = avgPremul·255/A
           = acc/acc[3]。这里曾经多乘了一个 k = 255/aAvg（把覆盖率除了两次），半覆盖像素被朝白色
           提亮 255/aAvg 倍（实测 3 格 100,60,30 不透明 + 1 格全透明 → 出 133,80,40，+33%），
           表现为缩小素材轮廓上一圈白边。 */
        out[o] = acc[3] > 0 ? Math.min(255, Math.round(acc[0] / acc[3])) : 0;
        out[o + 1] = acc[3] > 0 ? Math.min(255, Math.round(acc[1] / acc[3])) : 0;
        out[o + 2] = acc[3] > 0 ? Math.min(255, Math.round(acc[2] / acc[3])) : 0;
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
export function encodePng({ w, h, bpp, pixels }) {
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
