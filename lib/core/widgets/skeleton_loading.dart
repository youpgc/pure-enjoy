import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 通用骨架屏组件
/// 基于 Shimmer 效果，提供列表、网格、首页等多种预设
class SkeletonLoading extends StatelessWidget {
  final Widget child;

  const SkeletonLoading({super.key, required this.child});

  /// 列表项骨架（用于书架、小说列表等）
  static Widget list({
    Key? key,
    int itemCount = 6,
    double itemHeight = 72,
    bool showAvatar = true,
    bool showSubtitle = true,
  }) {
    return SkeletonLoading(
      key: key,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: itemCount,
        itemBuilder: (_, __) => _SkeletonListItem(
          height: itemHeight,
          showAvatar: showAvatar,
          showSubtitle: showSubtitle,
        ),
      ),
    );
  }

  /// 网格骨架（用于封面网格展示）
  static Widget grid({
    Key? key,
    int itemCount = 6,
    int crossAxisCount = 3,
    double aspectRatio = 0.65,
  }) {
    return SkeletonLoading(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: (_, __) => const _SkeletonGridItem(),
        ),
      ),
    );
  }

  /// 首页 Dashboard 骨架
  static Widget dashboard({Key? key}) {
    return SkeletonLoading(
      key: key,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部问候语骨架
            _shimmerBlock(width: 120, height: 24),
            const SizedBox(height: 8),
            _shimmerBlock(width: 200, height: 16),
            const SizedBox(height: 24),
            // 统计卡片骨架
            Row(
              children: List.generate(3, (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  child: _shimmerContainer(height: 80, radius: 12),
                ),
              )),
            ),
            const SizedBox(height: 24),
            // 最近活动骨架
            _shimmerBlock(width: 80, height: 18),
            const SizedBox(height: 12),
            ...List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _shimmerContainer(height: 64, radius: 12),
            )),
            const SizedBox(height: 16),
            // 最近阅读骨架
            _shimmerBlock(width: 80, height: 18),
            const SizedBox(height: 12),
            Row(
              children: List.generate(3, (i) => Padding(
                padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                child: _shimmerContainer(width: 90, height: 120, radius: 8),
              )),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      highlightColor: colorScheme.surface,
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }

  /// 内部工具：shimmer 矩形块
  static Widget _shimmerBlock({double? width, double height = 16, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  /// 内部工具：shimmer 容器
  static Widget _shimmerContainer({double? width, double height = 60, double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 列表项骨架子组件
class _SkeletonListItem extends StatelessWidget {
  final double height;
  final bool showAvatar;
  final bool showSubtitle;

  const _SkeletonListItem({
    required this.height,
    this.showAvatar = true,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (showAvatar) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (showSubtitle) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: 160,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 网格项骨架子组件
class _SkeletonGridItem extends StatelessWidget {
  const _SkeletonGridItem();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 10,
          width: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
