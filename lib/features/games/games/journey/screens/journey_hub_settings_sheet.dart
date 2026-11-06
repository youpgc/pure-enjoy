import 'package:flutter/material.dart';

import '../../../../../utils/cache_helper.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';

/// 西行设置浮层（音乐/音效开关，本地 CacheHelper 持久化）。
/// 自 hub 抽出独立文件以控制 hub 页行数（≤500 约定）。
class JourneySettingsSheet extends StatefulWidget {
  const JourneySettingsSheet({super.key});

  @override
  State<JourneySettingsSheet> createState() => _JourneySettingsSheetState();
}

class _JourneySettingsSheetState extends State<JourneySettingsSheet> {
  static const String _storeKey = 'journey_settings_v1';

  /// 环绕旋转方向（局内生效）：独立键存 'cw'/'ccw'，默认顺时针；
  /// 对局页进局时读取注入引擎（见 journey_battle_screen._setup）。
  static const String _spinKey = 'journey_spin_dir';

  bool _music = true;
  bool _sfx = true;
  bool _clockwise = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await CacheHelper.instance.loadMap(_storeKey);
    final spin = await CacheHelper.instance.loadMap(_spinKey);
    if (!mounted) return;
    setState(() {
      _music = raw?['music'] as bool? ?? true;
      _sfx = raw?['sfx'] as bool? ?? true;
      _clockwise = (spin?['dir'] as String? ?? 'cw') != 'ccw';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await CacheHelper.instance.saveMap(_storeKey, <String, dynamic>{
      'music': _music,
      'sfx': _sfx,
    });
  }

  /// 旋转方向即时写缓存（下一次进局生效）。
  Future<void> _saveSpinDir(bool clockwise) async {
    await CacheHelper.instance.saveMap(_spinKey, <String, dynamic>{
      'dir': clockwise ? 'cw' : 'ccw',
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const JourneySectionTitle(text: '设置'),
            ListTile(
              leading: const Icon(Icons.music_note, color: JourneyTheme.gold),
              title: const Text('音乐', style: JourneyTheme.body),
              trailing: _loaded
                  ? Switch(value: _music, onChanged: (v) {
                      setState(() => _music = v);
                      _save();
                    })
                  : null,
            ),
            ListTile(
              leading:
                  const Icon(Icons.volume_up, color: JourneyTheme.gold),
              title: const Text('音效', style: JourneyTheme.body),
              trailing: _loaded
                  ? Switch(value: _sfx, onChanged: (v) {
                      setState(() => _sfx = v);
                      _save();
                    })
                  : null,
            ),
            // 环绕旋转方向：开=顺时针（默认），关=逆时针，即时写缓存
            ListTile(
              leading:
                  const Icon(Icons.rotate_right, color: JourneyTheme.gold),
              title: const Text('旋转方向', style: JourneyTheme.body),
              subtitle: Text(
                _clockwise ? '顺时针' : '逆时针',
                style: JourneyTheme.faint,
              ),
              trailing: _loaded
                  ? Switch(value: _clockwise, onChanged: (v) {
                      setState(() => _clockwise = v);
                      _saveSpinDir(v);
                    })
                  : null,
            ),
            SizedBox(
              width: double.infinity,
              child: JourneyButton(
                text: '关闭',
                secondary: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
