import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/widgets/widgets.dart';
import '../../../services/api_client.dart';
import '../../../services/notification_service.dart';
import '../../../utils/date_time_utils.dart';
import '../models/anniversary_model.dart';
import '../models/remind_offset.dart';
import '../widgets/remind_offset_selector.dart';
import '../widgets/app_date_picker.dart';
import './anniversary_helpers.dart';
import './anniversary_lunar_picker.dart';
import '../helpers/anniversary_cache_helper.dart';

/// 纪念日/生日 新增/编辑表单 Dialog。
/// 从 [AnniversariesScreen._showEditDialog] 抽离（治理 §1.5.5 膨胀防御）。
/// 内部用 StatefulBuilder 自管理表单状态；保存成功后由调用方经 [onSaved] 触发刷新。
Future<void> showAnniversaryEditDialog(
  BuildContext context, {
  AnniversaryModel? anniversary,
  required String filterType,
  required String? userId,
  required String? userNickname,
  required VoidCallback onSaved,
}) async {
  final isEditing = anniversary != null;
  final nameController = TextEditingController(text: anniversary?.title ?? '');
  final descController =
      TextEditingController(text: anniversary?.description ?? '');

  final String selectedType = anniversary?.type ?? filterType;
  DateTime selectedDate = anniversary?.date ?? DateTime.now();
  bool repeatYearly = anniversary?.repeatYearly ?? true;
  bool remindEnabled = anniversary?.remindEnabled ?? false;
  List<RemindOffset> remindOffsets =
      List.from(anniversary?.remindOffsets ?? const <RemindOffset>[]);
  final rt = (anniversary?.remindTime ?? '09:00').split(':');
  TimeOfDay remindTime = TimeOfDay(
    hour: int.tryParse(rt[0]) ?? 9,
    minute: int.tryParse(rt.length > 1 ? rt[1] : '0') ?? 0,
  );
  bool isLunar = anniversary?.isLunar ?? false;

  final isBirthday = filterType == 'birthday';
  final typeLabel = isBirthday ? '生日' : '纪念日';

  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(isEditing ? '编辑$typeLabel' : '添加$typeLabel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名称输入
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '名称 *',
                  hintText: isBirthday ? '例如：妈妈生日、爸爸生日' : '例如：结婚纪念日、入职纪念日',
                ),
              ),
              const SizedBox(height: 12),

              // 日期选择
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('日期 *'),
                subtitle: Text(
                  isLunar
                      ? '农历 ${getLunarDateStr(selectedDate)}'
                      : DateTimeUtils.formatDate(selectedDate),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  if (isLunar) {
                    final picked = await showLunarDatePicker(
                      dialogContext,
                      initialDate: selectedDate,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  } else {
                    final picked = await AppDatePicker.show(
                      dialogContext,
                      type: DateTimeType.date,
                      initialDate: selectedDate,
                      minDate: DateTime(1900),
                      maxDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  }
                },
              ),
              const SizedBox(height: 4),
              // 农历/公历切换
              SwitchListTile(
                title: const Text('农历'),
                subtitle: Text(isLunar ? '当前为农历日期' : '当前为公历日期'),
                contentPadding: EdgeInsets.zero,
                value: isLunar,
                onChanged: (value) {
                  setDialogState(() => isLunar = value);
                },
              ),
              const Divider(),
              const SizedBox(height: 4),

              // 描述输入
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '描述',
                  hintText: '输入描述（可选）',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // 是否每年重复
              SwitchListTile(
                title: const Text('每年重复'),
                subtitle: Text(repeatYearly ? '每年都会提醒' : '仅一次'),
                contentPadding: EdgeInsets.zero,
                value: repeatYearly,
                onChanged: (value) {
                  setDialogState(() => repeatYearly = value);
                },
              ),
              const Divider(),

              // 提醒设置：开关 + 多选提前时间（含 hh:mm）+ 当天提醒时刻
              RemindOffsetSelector(
                baseTime: DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  remindTime.hour,
                  remindTime.minute,
                ),
                initialEnabled: remindEnabled,
                initialOffsets: remindOffsets,
                onChanged: (settings) {
                  setDialogState(() {
                    remindEnabled = settings.enabled;
                    remindOffsets = settings.offsets;
                  });
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('当天提醒时刻'),
                subtitle: Text(remindTime.format(dialogContext)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await AppDatePicker.show(
                    dialogContext,
                    type: DateTimeType.time,
                    initialDate: DateTime(1970, 1, 1, remindTime.hour, remindTime.minute),
                  );
                  if (picked != null) {
                    setDialogState(() => remindTime = TimeOfDay(hour: picked.hour, minute: picked.minute));
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                showSnackBar(context, '请输入名称', isError: true);
                return;
              }
              if (userId == null) {
                showSnackBar(context, '请先登录后再保存', isError: true);
                return;
              }
              final nickname = userNickname;
              // 统一提醒 ID（编辑用原 ID，新建生成），供保存后挂接横幅
              final annId = isEditing ? anniversary!.id : const Uuid().v4();

              try {
                final body = {
                  'user_nickname': nickname,
                  'title': nameController.text.trim(),
                  'date':
                      normalizeAnniversaryDate(selectedDate).toIso8601String(),
                  'type': selectedType,
                  'description': descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  'repeat_yearly': repeatYearly,
                  'remind_enabled': remindEnabled,
                  'remind_offsets':
                      remindOffsets.map((e) => e.toJson()).toList(),
                  'remind_time':
                      '${remindTime.hour.toString().padLeft(2, '0')}:${remindTime.minute.toString().padLeft(2, '0')}',
                  'is_lunar': isLunar,
                };

                if (isEditing) {
                  final result = await ApiClient.patchByFilter(
                    'user_anniversaries',
                    filters: {'id': 'eq.${anniversary!.id}'},
                    body: body,
                  );
                  if (!result.isSuccess) {
                    throw Exception('HTTP ${result.statusCode}');
                  }
                } else {
                  final result = await ApiClient.post(
                    'user_anniversaries',
                    {
                      'id': annId,
                      'user_id': userId,
                      ...body,
                    },
                  );
                  if (!result.isSuccess) {
                    throw Exception('HTTP ${result.statusCode}');
                  }
                }

                // 纪念日提醒：开启则挂接横幅，关闭则取消已设定的提醒
                final annModel = AnniversaryModel(
                  id: annId,
                  userId: userId,
                  userNickname: nickname,
                  title: nameController.text.trim(),
                  date: normalizeAnniversaryDate(selectedDate),
                  type: selectedType,
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  repeatYearly: repeatYearly,
                  remindEnabled: remindEnabled,
                  remindOffsets: remindOffsets,
                  remindTime:
                      '${remindTime.hour.toString().padLeft(2, '0')}:${remindTime.minute.toString().padLeft(2, '0')}',
                  isLunar: isLunar,
                );
                if (remindEnabled) {
                  await NotificationService.instance
                      .scheduleAnniversaryReminder(annModel);
                } else {
                  NotificationService.instance
                      .cancelAnniversaryReminder(annId);
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                onSaved();
              } catch (e) {
                showSnackBar(context, '保存失败，请稍后重试', isError: true);
              }
            },
            child: Text(isEditing ? '保存' : '添加'),
          ),
        ],
      ),
    ),
  );
}
