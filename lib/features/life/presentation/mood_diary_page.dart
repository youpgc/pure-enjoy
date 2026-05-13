import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/storage_service.dart';
import '../../../services/sync_service.dart';
import '../data/mood_diary_model.dart';

/// 心情日记页面
class MoodDiaryPage extends ConsumerStatefulWidget {
  const MoodDiaryPage({super.key});

  @override
  ConsumerState<MoodDiaryPage> createState() => _MoodDiaryPageState();
}

class _MoodDiaryPageState extends ConsumerState<MoodDiaryPage> {
  List<MoodDiaryModel> _diaries = [];

  @override
  void initState() {
    super.initState();
    _loadDiaries();
  }

  void _loadDiaries() {
    final box = StorageService().moodDiaryBox;
    setState(() {
      _diaries = box.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心情日记'),
      ),
      body: _diaries.isEmpty
          ? _buildEmptyState()
          : _buildDiaryList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_emotions_outlined,
            size: 80,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有心情日记',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '记录每一天的心情变化',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _diaries.length,
      itemBuilder: (context, index) {
        final diary = _diaries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      diary.mood,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diary.moodLabel ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(diary.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _deleteDiary(diary),
                    ),
                  ],
                ),
                if (diary.content != null && diary.content!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    diary.content!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddDialog() {
    final contentController = TextEditingController();
    int selectedMoodIndex = 2; // 默认平静

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('记录心情'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 心情选择
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  AppConstants.moods.length,
                  (index) => GestureDetector(
                    onTap: () => setDialogState(() => selectedMoodIndex = index),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selectedMoodIndex == index
                            ? AppTheme.accentColor.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AppConstants.moods[index],
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.moodLabels[selectedMoodIndex],
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // 日记内容
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '写下今天的心情...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final diary = MoodDiaryModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  mood: AppConstants.moods[selectedMoodIndex],
                  moodLabel: AppConstants.moodLabels[selectedMoodIndex],
                  content: contentController.text.isEmpty
                      ? null
                      : contentController.text,
                  date: DateTime.now(),
                  createdAt: DateTime.now(),
                );
                await StorageService().moodDiaryBox.put(diary.id, diary);
                SyncService().uploadMoodDiary(diary); // 同步到云端
                Navigator.pop(context);
                _loadDiaries();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteDiary(MoodDiaryModel diary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日记'),
        content: const Text('确定要删除这条心情日记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await StorageService().moodDiaryBox.delete(diary.id);
              SyncService().deleteRemote('mood_diaries', diary.id); // 从云端删除
              Navigator.pop(context);
              _loadDiaries();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
