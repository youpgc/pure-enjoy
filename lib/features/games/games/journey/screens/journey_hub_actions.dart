import 'package:flutter/material.dart';

import '../../../models/game_model.dart';
import '../../../play/game_leaderboard_screen.dart';
import '../widgets/journey_theme.dart';
import 'journey_hub_settings_sheet.dart';

/// hub 页动作面板：设置抽屉 / 排行榜跳转（与页面布局解耦）。

/// 西行设置（环绕方向等局外偏好）底部抽屉。
void openJourneySettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: JourneyTheme.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
          top: Radius.circular(JourneyTheme.radiusPanel)),
    ),
    builder: (_) => const JourneySettingsSheet(),
  );
}

/// 西行排行：跳通用排行榜页；配置未加载时回退宿主 gameId，仍为空则提示暂未开放。
void openJourneyLeaderboard(
  BuildContext context, {
  required String snapshotGameId,
  required String fallbackGameId,
  required String gameCode,
}) {
  final gameId =
      snapshotGameId.isNotEmpty ? snapshotGameId : fallbackGameId;
  if (gameId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('排行榜暂未开放')),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GameLeaderboardScreen(
        game: GameModel(id: gameId, code: gameCode, name: '西行'),
      ),
    ),
  );
}
