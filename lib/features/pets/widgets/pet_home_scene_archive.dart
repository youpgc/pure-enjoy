// 归档：程序化背景变体（无活动代码，纯注释存档；见 pet_home_scene.dart 指针）。

/* ==================== 归档（程序化白日草地背景，可回退） ====================

const Color _skyTop = Color(0xFFA9D7F5);
const Color _skyBottom = Color(0xFFE8F6E0);
const Color _grassTop = Color(0xFF9ED07E);
const Color _grassBottom = Color(0xFF7CB860);
const Color _sun = Color(0xFFFFE08A);

/// 独立场景背景（程序化：天空渐变 + 太阳 + 云朵 + 草地）
class PetSceneBackgroundFlat extends StatelessWidget {
  const PetSceneBackgroundFlat({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _skyBottom],
          stops: [0.0, 0.62],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            right: 56,
            top: 72,
            child: _SceneSun(size: 64),
          ),
          const Positioned(left: 40, top: 92, child: _SceneCloud(width: 92)),
          const Positioned(right: 130, top: 148, child: _SceneCloud(width: 68)),
          const Positioned(left: 150, top: 52, child: _SceneCloud(width: 54)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.sizeOf(context).height * 0.34,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_grassTop, _grassBottom],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneSun extends StatelessWidget {
  const _SceneSun({this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.5,
      height: size * 1.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _sun.withValues(alpha: 0.28),
      ),
      padding: EdgeInsets.all(size * 0.25),
      child: const DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: _sun),
      ),
    );
  }
}

class _SceneCloud extends StatelessWidget {
  const _SceneCloud({this.width = 80});

  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 0.52;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        children: [
          Positioned(left: 0, bottom: 0, child: _blob(width * 0.46, h * 0.62)),
          Positioned(left: width * 0.24, top: 0, child: _blob(width * 0.52, h * 0.78)),
          Positioned(right: 0, bottom: 0, child: _blob(width * 0.44, h * 0.58)),
        ],
      ),
    );
  }

  Widget _blob(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(h / 2),
        ),
      );
}

==================== 程序化晨曦草甸（scene_meadow，零素材版，可回退） ====================

class PetSceneBackgroundMeadow extends StatelessWidget {
  const PetSceneBackgroundMeadow({super.key});

  static const _skyTop = Color(0xFFFFE3B3);
  static const _skyBottom = Color(0xFFFFF6E3);
  static const _grassTop = Color(0xFFA8D48A);
  static const _grassBottom = Color(0xFF7CB860);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_skyTop, _skyBottom],
            stops: [0.0, 0.62]),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: 56,
            top: 70,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD98A),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFFD98A).withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 12),
                ],
              ),
            ),
          ),
          Positioned(left: 40, top: 96, child: _cloud(92)),
          Positioned(right: 130, top: 150, child: _cloud(68)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.34,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_grassTop, _grassBottom]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cloud(double width) {
    final h = width * 0.52;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        children: [
          Positioned(left: 0, bottom: 0, child: _blob(width * 0.46, h * 0.62)),
          Positioned(
              left: width * 0.24,
              top: 0,
              child: _blob(width * 0.52, h * 0.78)),
          Positioned(
              right: 0, bottom: 0, child: _blob(width * 0.44, h * 0.58)),
        ],
      ),
    );
  }

  Widget _blob(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(h / 2),
        ),
      );
}

==================== 程序化星海之栏（scene_starry，零素材版，可回退） ====================

class PetSceneBackgroundStarry extends StatelessWidget {
  const PetSceneBackgroundStarry({super.key});

  /// 确定性星点表（fx, fy, r, 亮度）——手排 24 颗，疏密有致
  static const _stars = <List<double>>[
    [0.06, 0.08, 1.4, 0.9], [0.14, 0.18, 1.0, 0.6], [0.22, 0.06, 1.8, 1.0],
    [0.31, 0.14, 1.1, 0.7], [0.38, 0.24, 1.3, 0.8], [0.47, 0.09, 1.0, 0.5],
    [0.55, 0.19, 1.6, 0.9], [0.63, 0.05, 1.1, 0.6], [0.70, 0.16, 1.4, 0.8],
    [0.78, 0.10, 1.0, 0.55], [0.86, 0.21, 1.7, 0.9], [0.94, 0.12, 1.1, 0.65],
    [0.10, 0.30, 1.0, 0.5], [0.27, 0.34, 1.2, 0.7], [0.44, 0.31, 1.0, 0.5],
    [0.60, 0.35, 1.2, 0.6], [0.76, 0.30, 1.0, 0.5], [0.92, 0.33, 1.2, 0.7],
    [0.18, 0.44, 1.0, 0.4], [0.52, 0.46, 1.0, 0.45], [0.84, 0.43, 1.0, 0.5],
    [0.36, 0.50, 0.9, 0.35], [0.67, 0.52, 0.9, 0.4], [0.05, 0.55, 0.9, 0.35],
  ];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarryPainter(),
      size: Size.infinite,
    );
  }
}

class _StarryPainter extends CustomPainter {
  static const _top = Color(0xFF0B1026);
  static const _mid = Color(0xFF1B2550);
  static const _bottom = Color(0xFF2E3A6B);

  @override
  void paint(Canvas canvas, Size size) {
    // 深空渐变
    final sky = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
        sky,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_top, _mid, _bottom])
              .createShader(sky));

    // 星点
    for (final star in PetSceneBackgroundStarry._stars) {
      canvas.drawCircle(
        Offset(star[0] * size.width, star[1] * size.height),
        star[2],
        Paint()..color = Colors.white.withValues(alpha: star[3]),
      );
    }

    // 弦月（右上）
    final moonCenter = Offset(size.width * 0.80, size.height * 0.16);
    canvas.drawCircle(moonCenter, 34, Paint()..color = const Color(0xFFF5EFD8));
    final biteColor = Color.lerp(_top, _mid, 0.32)!;
    canvas.drawCircle(
        moonCenter.translate(-14, -8), 30, Paint()..color = biteColor);

    // 远山剪影（两重）
    final hill1 = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.66,
          size.width * 0.5, size.height * 0.76)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.86,
          size.width, size.height * 0.74)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.74, size.width, size.height * 0.26),
        Paint()..color = const Color(0xFF141A38));
    canvas.drawPath(hill1, Paint()..color = const Color(0xFF1A2142));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

==================== 归档结束 ==================== */
