import 'package:flutter/material.dart';

import '../../../../services/supabase_service.dart';
import '../../../life/models/weight_record_model.dart';
import '../../../life/screens/weight_record_form.dart';

/// 添加体重记录底部弹窗
///
/// 复用 [RecordForm] 单一表单，确保首页与列表页体重录入表单、BMI/体脂计算一致
/// （见 pure-enjoy-weight §7①：两份表单须同步，优先收敛为单一共享 Widget）。
/// 弹窗关闭由 onSave 包装层（dashboardPostRecord）负责，本组件只负责渲染表单。
class AddWeightSheet extends StatelessWidget {
  final Function(WeightRecordModel) onSave;

  const AddWeightSheet({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.instance.currentUserId ?? 'local_user';
    return RecordForm(
      userId: userId,
      onSave: onSave,
    );
  }
}
