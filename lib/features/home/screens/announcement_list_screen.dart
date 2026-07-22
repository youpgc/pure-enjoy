import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/announcement_service.dart';

/// 公告列表页
///
/// 展示当前生效的全部公告（已发布 + 未过期），按优先级置顶。
/// 后台 Announcements.tsx 发布/撤回/删改后，用户在此可见。
class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  bool _loading = true;
  List<Announcement> _list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await AnnouncementService.fetchActive(limit: 50);
    if (mounted) {
      setState(() {
        _list = list;
        _loading = false;
      });
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  /// 后台创建时间按北京时间展示；created_at 为 UTC，转北京(+8)
  String _format(DateTime? d) {
    if (d == null) return '长期有效';
    final bj = d.toUtc().add(const Duration(hours: 8));
    return '${bj.year}-${_pad(bj.month)}-${_pad(bj.day)} ${_pad(bj.hour)}:${_pad(bj.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('公告')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(
                  child: Text('暂无公告', style: TextStyle(color: Colors.grey)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final a = _list[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (a.priority == 'high')
                                    Container(
                                      margin: const EdgeInsets.only(left: 8, top: 2),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '重要',
                                        style: TextStyle(
                                          color: AppTheme.error,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(a.typeLabel,
                                        style: const TextStyle(fontSize: 12)),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '发布于 ${_format(a.publishAt)}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                a.content,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
