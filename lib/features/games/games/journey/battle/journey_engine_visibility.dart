part of 'journey_flame_game.dart';

/// 相机可见判定：渲染剔除与特效发射共用同一口径，避免屏外实体占用绘制与粒子池。
extension JourneyCameraVisibility on JourneyMonsterComponent {
  /// 本体是否落在可见矩形内；margin 为额外边距（像素），留出体型避免边缘闪现。
  bool isVisibleToCamera(double margin) {
    final rect = game.camera.visibleWorldRect;
    if (rect.isEmpty) return true;
    final px = position.x;
    final py = position.y;
    return px >= rect.left - margin &&
        px <= rect.right + margin &&
        py >= rect.top - margin &&
        py <= rect.bottom + margin;
  }
}
