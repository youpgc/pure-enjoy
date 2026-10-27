#!/usr/bin/env python3
"""场景主题生成图水印裁剪工具。

ImageGen 生成图右下角带水印：底部裁掉一条（默认 12%）即可去除——
底部恰好是 App 沉底状态卡的覆盖弃区，构图无需心疼。

用法：
  python tool/trim_watermark.py <输入目录或文件> [--bottom 12] [--right 0] [--out 输出目录]

  --bottom  底部裁剪百分比（默认 12，覆盖右下角水印带）
  --right   右侧裁剪百分比（默认 0；水印偏右时追加）
  --out     输出目录（默认输入目录下 trimmed/ 子目录，不覆盖原图）

裁后直接可用于 assets/pets/scenes/（App 端 BoxFit.cover 自适应，
不要求精确 832x1216；裁后仍为竖版且短边 >= 832 即最佳）。
"""
import argparse
import sys
from pathlib import Path

from PIL import Image


def trim_one(src: Path, dst: Path, bottom_pct: float, right_pct: float) -> tuple[int, int]:
    im = Image.open(src)
    if im.mode != "RGB":
        im = im.convert("RGB")
    w, h = im.size
    cut_h = round(h * bottom_pct / 100)
    cut_w = round(w * right_pct / 100)
    im = im.crop((0, 0, w - cut_w, h - cut_h))
    im.save(dst, "PNG")
    return im.size


def main() -> None:
    ap = argparse.ArgumentParser(description="场景生成图水印裁剪（底部弃区一刀切）")
    ap.add_argument("input", help="生成图目录或单文件")
    ap.add_argument("--bottom", type=float, default=12, help="底部裁剪百分比（默认 12）")
    ap.add_argument("--right", type=float, default=0, help="右侧裁剪百分比（默认 0）")
    ap.add_argument("--out", help="输出目录（默认输入目录下 trimmed/）")
    args = ap.parse_args()

    src = Path(args.input)
    if src.is_dir():
        files = sorted(p for p in src.iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"))
        out_dir = Path(args.out) if args.out else src / "trimmed"
    else:
        files = [src]
        out_dir = Path(args.out) if args.out else src.parent / "trimmed"
    if not files:
        sys.exit(f"未找到图片: {src}")
    out_dir.mkdir(parents=True, exist_ok=True)

    for f in files:
        dst = out_dir / (f.stem + ".png")
        w, h = trim_one(f, dst, args.bottom, args.right)
        note = "" if (w >= 832 and h > w) else "  [提示] 短边<832 或非竖版，建议用更高分辨率原图"
        print(f"{f.name} -> {dst.name}  {w}x{h}{note}")


if __name__ == "__main__":
    main()
