import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../../services/supabase_service.dart';
import '../../../life/models/reminder_model.dart';
import '../../../life/models/remind_offset.dart';
import '../../../life/widgets/remind_offset_selector.dart';
import '../../../../utils/date_time_utils.dart';
import '../../../life/widgets/app_date_picker.dart';

/// 添加提醒底部弹窗
///
/// 用于快速创建一条提醒，包含标题、描述与提醒时间。
class AddReminderSheet extends StatefulWidget {
  final Function(ReminderModel) onSave;

  const AddReminderSheet({super.key, required this.onSave});

  @override
  State<AddReminderSheet> createState() => AddReminderSheetState();
}

class AddReminderSheetState extends State<AddReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _remindAt = DateTime.now().add(const Duration(hours: 1));
  bool _remindEnabled = false;
  List<RemindOffset> _remindOffsets = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final reminder = ReminderModel(
        id: const Uuid().v4(),
        userId: AuthService.instance.currentUserId ?? 'local_user',
        title: _titleController.text,
        description: _descController.text.isEmpty ? null : _descController.text,
        remindAt: _remindAt,
        remindEnabled: _remindEnabled,
        remindOffsets: _remindOffsets,
      );

      widget.onSave(reminder);
  }

  @override
  Widget build(BuildContext context) {
    // 外层包裹 SingleChildScrollView：键盘弹出压缩可视高度时可滚动，避免底部溢出
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('添加提醒', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '标题'),
              validator: (v) => v?.isEmpty == true ? '请输入标题' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '描述（可选）'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('提醒时间'),
              trailing: Text(DateTimeUtils.formatStandard(_remindAt)),
              onTap: () async {
                // 选择器统一按北京墙钟交互（与展示口径一致，避免模拟器 UTC 时区偏 8 小时）
                final bjNow =
                    DateTimeUtils.toBeijingWallClock(DateTime.now());
                final bjInitial =
                    DateTimeUtils.toBeijingWallClock(_remindAt);
                final date = await showDatePicker(
                  context: context,
                  initialDate: bjInitial,
                  firstDate: bjNow,
                  lastDate: bjNow.add(const Duration(days: 365)),
                );
                if (date == null) return;
                if (!mounted) return;
                final time = await AppDatePicker.show(
                  this.context,
                  type: DateTimeType.time,
                  initialDate: bjInitial,
                );
                if (time == null) return;
                if (!mounted) return;
                setState(() {
                  // 北京墙钟还原为设备时刻后写回（存储/调度瞬时值不变）
                  _remindAt = DateTimeUtils.fromBeijingWallClock(DateTime(
                    date.year, date.month, date.day,
                    time.hour, time.minute,
                  ));
                });
              },
            ),
            const SizedBox(height: 16),
            RemindOffsetSelector(
              // 标签展示用北京墙钟口径（与提醒时间展示一致）
              baseTime: DateTimeUtils.toBeijingWallClock(_remindAt),
              initialEnabled: _remindEnabled,
              initialOffsets: _remindOffsets,
              onChanged: (settings) {
                setState(() {
                  _remindEnabled = settings.enabled;
                  _remindOffsets = settings.offsets;
                });
              },
            ),
            const SizedBox(height: 16),
            AsyncSubmitButton(label: '保存', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
