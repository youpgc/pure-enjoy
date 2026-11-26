import 'package:flutter/material.dart';

import '../../../../../core/widgets/paginated_list_mixin.dart';
import 'journey_run_detail_screen.dart';
import '../models/journey_talent_models.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_progress_sync.dart';
import '../../../../../services/supabase_service.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';

/// 西行履历列表页：功德流水 / 西行记录。
/// 以服务端分页为真源（清缓存不丢），结算新记录按本地镜像实时补显，
/// 网络失败回落本地离线镜像。

/// 功德来源中文标签（未知类型回落「其他」）。
const Map<String, String> _kSourceLabels = <String, String>{
  'run_settle': '对局结算',
  'talent_spend': '天赋点亮',
  'character_unlock': '角色解锁',
  'revive_spend': '还魂复活',
  'unlock_spend': '统一解锁',
};

/// 时间：yyyy-MM-dd HH:mm（北京墙钟口径，禁止设备时区）。
/// 记录 createdAt 由 journeyBjNow() 落盘（isUtc 标记=BJ 墙钟字段），
/// 直读字段即为北京时间；旧数据为设备 +08 墙钟，直读同样正确。
String _fmtDate(DateTime? t) {
  if (t == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// 时长：mm:ss。
String _fmtDuration(int ms) {
  final total = ms <= 0 ? 0 : ms ~/ 1000;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 来源小标签（面板底 + 鎏金描边，口径同功德胶囊）。
Widget _sourceTag(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: JourneyTheme.panelRaised,
      border: Border.all(color: JourneyTheme.goldDeep),
    ),
    child: Text(label, style: JourneyTheme.faint),
  );
}

/// 服务端分页列表公共骨架：远端为真源，失败时用本地离线镜像兜底。
/// 首载/刷新失败保留原分页状态；远端从未成功时触底不重复请求，靠刷新重试。
abstract class _JourneyPagedListState<T, W extends StatefulWidget>
    extends State<W>
    with PaginatedListMixin<W> {
  @override
  int get pageSize => 30;

  String get title;
  String get emptyText;

  /// 本地离线镜像（远端未成功时展示）。
  List<T> readLocalRecords();

  /// 远端分页拉取；返回 null 表示失败，由调用方保留本地兜底。
  Future<List<T>?> fetchPage(
    String userId, {
    required int limit,
    required int offset,
  });

  /// 单条记录卡片。
  Widget tile(BuildContext context, T record);

  /// 记录唯一 id（用于远端快照与本地镜像去重合并）。
  String recordId(T record);

  List<T>? _remote;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    initPagination();
    _load(reset: true);
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    // reset 只占用加载锁、不提前改页码：失败保留原分页状态，成功后归位，
    // 避免刷新失败后页码停在 1 而列表仍是旧数据，下次触底错位追加。
    if (reset) {
      if (!beginReset()) return;
    } else if (!beginLoadMore()) {
      return;
    }
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      cancelLoadMore(revertPage: !reset);
      if (mounted) setState(() => _loading = false);
      return;
    }
    final (limit, offset) = reset ? (pageSize, 0) : paginationParams;
    final page = await fetchPage(userId, limit: limit, offset: offset);
    if (!mounted) return;
    if (page == null) {
      cancelLoadMore(revertPage: !reset);
      setState(() => _loading = false);
      return;
    }
    setState(() {
      if (reset) resetPagination();
      _remote = <T>[
        ...(reset ? <T>[] : (_remote ?? <T>[])),
        ...page,
      ];
      onPaginationDataLoaded(page.length);
      _loading = false;
    });
  }

  @override
  void onLoadMore() {
    // 远端从未成功时只有本地兜底，触底不再反复拉首页；下拉刷新才重试。
    if (_remote == null) return;
    _load();
  }

  /// 远端从未成功时用本地兜底，触底不重试；底部给出下拉重试提示，
  /// 避免用户误以为列表到底或无数据。
  @override
  Widget buildLoadMoreIndicator() {
    if (_remote == null && !_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('离线记录 · 下拉刷新重试', style: JourneyTheme.faint),
        ),
      );
    }
    return super.buildLoadMoreIndicator();
  }

  /// 远端快照 + 本地新增的实时合并视图。
  /// 本地镜像按时间倒序，取头部尚未出现在远端快照中的记录补到最前：
  /// 结算产生的新记录在 ListenableBuilder 重建后立即可见，无需下拉刷新。
  /// 本地旧记录（已含于远端快照）不重复补入；远端未成功时回落纯本地镜像。
  List<T> _visibleRecords() {
    final remote = _remote;
    if (remote == null) return readLocalRecords();
    final local = readLocalRecords();
    if (local.isEmpty) return remote;
    final remoteIds = remote.map(recordId).toSet();
    var freshEnd = 0;
    while (freshEnd < local.length &&
        !remoteIds.contains(recordId(local[freshEnd]))) {
      freshEnd++;
    }
    if (freshEnd == 0) return remote;
    return <T>[...local.getRange(0, freshEnd), ...remote];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: JourneyProgressService.instance,
      builder: (context, _) {
        // 直达记录页时补一次读档：进度服务有加载守卫，完成后通知刷新
        JourneyProgressService.instance.ensureLoaded();
        final records = _visibleRecords();
        return JourneyPageScaffold(
          title: title,
          body: _loading && records.isEmpty
              ? const Center(child: JourneyLoading(label: '加载中…'))
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: records.isEmpty
                      ? ListView(
                          children: <Widget>[
                            const SizedBox(height: 120),
                            Center(
                              child: Text(emptyText,
                                  style: JourneyTheme.faint),
                            ),
                          ],
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          itemCount: records.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, int index) {
                            if (index == records.length) {
                              return buildLoadMoreIndicator();
                            }
                            return tile(context, records[index]);
                          },
                        ),
                ),
        );
      },
    );
  }
}

// ---- 功德流水页 ----

/// 功德流水页：append-only 流水列表（来源标签 + 增减额 + 余额快照）。
class JourneyMeritRecordsScreen extends StatefulWidget {
  const JourneyMeritRecordsScreen({super.key});

  @override
  State<JourneyMeritRecordsScreen> createState() =>
      _JourneyMeritRecordsScreenState();
}

class _JourneyMeritRecordsScreenState extends _JourneyPagedListState<
    JourneyMeritRecordModel, JourneyMeritRecordsScreen> {
  @override
  String get title => '功德流水';

  @override
  String get emptyText => '暂无功德流水';

  @override
  String recordId(JourneyMeritRecordModel r) => r.id;

  @override
  List<JourneyMeritRecordModel> readLocalRecords() =>
      JourneyProgressService.instance.state.meritRecords;

  @override
  Future<List<JourneyMeritRecordModel>?> fetchPage(
    String userId, {
    required int limit,
    required int offset,
  }) =>
      JourneyProgressSync.fetchMeritRecordsPage(
        userId,
        limit: limit,
        offset: offset,
      );

  @override
  Widget tile(BuildContext context, JourneyMeritRecordModel r) {
    final positive = r.delta >= 0;
    return JourneyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _sourceTag(_kSourceLabels[r.sourceType] ?? '其他'),
              const SizedBox(width: 8),
              Text(
                positive ? '+${r.delta}' : '${r.delta}',
                style: JourneyTheme.title.copyWith(
                  color: positive ? JourneyTheme.gold : JourneyTheme.cinnabar,
                ),
              ),
              const Spacer(),
              Text('余额 ${r.balanceAfter}', style: JourneyTheme.caption),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  r.remark,
                  style: JourneyTheme.faint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(_fmtDate(r.createdAt), style: JourneyTheme.faint),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- 西行记录页 ----

/// 西行记录页：一场对局一条（难别/模式 + 击杀/时长 + 功德入账），
/// 点击卡片进入详情查看当局属性快照。远端分页为真源，失败回落本地镜像。
class JourneyRunRecordsScreen extends StatefulWidget {
  const JourneyRunRecordsScreen({super.key});

  @override
  State<JourneyRunRecordsScreen> createState() => _JourneyRunRecordsScreenState();
}

class _JourneyRunRecordsScreenState extends _JourneyPagedListState<
    JourneyRunRecordModel, JourneyRunRecordsScreen> {
  @override
  String get title => '西行记录';

  @override
  String get emptyText => '暂无西行记录';

  @override
  String recordId(JourneyRunRecordModel r) => r.id;

  @override
  List<JourneyRunRecordModel> readLocalRecords() =>
      JourneyProgressService.instance.state.runRecords;

  @override
  Future<List<JourneyRunRecordModel>?> fetchPage(
    String userId, {
    required int limit,
    required int offset,
  }) =>
      JourneyProgressSync.fetchRunRecordsPage(
        userId,
        limit: limit,
        offset: offset,
      );

  /// 西行记录标题：优先 name（服务端按 type 带名称 / 本地 levelTitle）；
  /// 为空按 levelNo 兜底；非主线按 kind（远端读 type）映射模式名。
  String _runTitle(JourneyRunRecordModel r) {
    if (r.levelTitle.isNotEmpty) return r.levelTitle;
    if (r.levelNo > 0) return '第 ${r.levelNo} 难';
    switch (r.kind) {
      case 'endless':
        return '无尽妖潮';
      case 'daily':
        return '西行游历';
      default:
        return '模式对局';
    }
  }

  @override
  Widget tile(BuildContext context, JourneyRunRecordModel r) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => JourneyRunDetailScreen(record: r),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: JourneyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(_runTitle(r), style: JourneyTheme.body),
                const SizedBox(width: 8),
                Text(
                  r.cleared ? '通关 ✓' : '未竟',
                  style: JourneyTheme.caption.copyWith(
                    color: r.cleared
                        ? JourneyTheme.gold
                        : JourneyTheme.textFaint,
                  ),
                ),
                const Spacer(),
                Text(
                  '+${r.meritGained}',
                  style: JourneyTheme.title.copyWith(color: JourneyTheme.gold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '击杀 ${r.kills} · ${_fmtDuration(r.durationMs)}',
                    style: JourneyTheme.caption,
                  ),
                ),
                Text(_fmtDate(r.createdAt), style: JourneyTheme.faint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
