part of 'journey_flame_game.dart';

/// 飘字贴图缓存：文字只在首次出现时排版并栅格化成白色主体与黑色阴影两张贴图，
/// 渲染帧只按目标色与透明度调制绘制，不再逐帧创建 TextPainter/TextStyle。
/// 阴影独立成图，避免整体染色时把黑色描边也染成飘字色；
/// 采用 LRU 淘汰并释放图像，上限固定，避免伤害数字海量文本无限增长。
class JourneyFxGlyphCache {
  static const int _maxGlyphs = 96;
  static const double _fontSize = 15;
  static const double _pad = 6;

  final Map<String, _JourneyGlyph> _images = <String, _JourneyGlyph>{};

  /// 取贴图；不存在则排版并栅格化后入缓存。
  _JourneyGlyph _glyph(String text) {
    final hit = _images[text];
    if (hit != null) {
      // 命中即移到链表尾，维持 LRU。
      _images
        ..remove(text)
        ..[text] = hit;
      return hit;
    }
    const style = TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: _fontSize,
      fontWeight: FontWeight.w700,
    );
    final bodyPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    // 阴影层只保留模糊黑影，文字本体透明，两层叠放还原原逐帧绘制的描边。
    final shadowPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          color: const Color(0x00000000),
          shadows: const <Shadow>[
            Shadow(color: Color(0x99000000), blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = bodyPainter.width.ceil() + (_pad * 2).ceil();
    final h = bodyPainter.height.ceil() + (_pad * 2).ceil();
    final glyph = _JourneyGlyph(
      _rasterize(w, h, (canvas) {
        bodyPainter.paint(canvas, const Offset(_pad, _pad));
      }),
      _rasterize(w, h, (canvas) {
        shadowPainter.paint(canvas, const Offset(_pad, _pad));
      }),
    );
    _images[text] = glyph;
    if (_images.length > _maxGlyphs) {
      _images.remove(_images.keys.first)?.dispose();
    }
    return glyph;
  }

  ui.Image _rasterize(
    int width,
    int height,
    void Function(Canvas canvas) draw,
  ) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    draw(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  /// 发射时预热贴图，避免首次渲染在同一帧内栅格化。
  void cache(String text) => _glyph(text);

  /// 绘制一条飘字：位置与原逐帧排版一致（水平居中、底部对齐锚点），
  /// 主体贴图用 colorFilter 调制为目标色，阴影贴图保持黑色不参与染色。
  void paint(
    Canvas canvas,
    String text,
    Offset pos,
    Color color,
    double alpha,
    Paint paint,
  ) {
    if (alpha <= 0) return;
    final glyph = _glyph(text);
    final src = Rect.fromLTWH(
      0,
      0,
      glyph.body.width.toDouble(),
      glyph.body.height.toDouble(),
    );
    final dst = Rect.fromLTWH(
      pos.dx - glyph.body.width / 2,
      pos.dy - glyph.body.height + _pad,
      glyph.body.width.toDouble(),
      glyph.body.height.toDouble(),
    );
    paint
      ..colorFilter = null
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    canvas.drawImageRect(glyph.shadow, src, dst, paint);
    paint.colorFilter = ui.ColorFilter.mode(
      color.withValues(alpha: alpha),
      ui.BlendMode.srcATop,
    );
    canvas.drawImageRect(glyph.body, src, dst, paint);
  }

  /// 对局卸载时释放全部贴图句柄。
  void clear() {
    for (final glyph in _images.values) {
      glyph.dispose();
    }
    _images.clear();
  }
}

/// 一条飘字的主体贴图与独立阴影贴图。
class _JourneyGlyph {
  _JourneyGlyph(this.body, this.shadow);

  final ui.Image body;
  final ui.Image shadow;

  void dispose() {
    body.dispose();
    shadow.dispose();
  }
}
