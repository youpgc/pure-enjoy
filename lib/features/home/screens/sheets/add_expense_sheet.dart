import 'package:flutter/material.dart';

import '../../../../services/supabase_service.dart';
import '../../../life/models/expense_model.dart';
import '../../../life/widgets/expense_form.dart';

/// 添加支出底部弹窗
///
/// 复用 [ExpenseForm] 单一表单，确保首页与列表页记账表单一致（见 pure-enjoy-ledger §7①）。
/// 弹窗关闭由 onSave 包装层（dashboardPostRecord）负责，本组件只负责渲染表单。
class AddExpenseSheet extends StatelessWidget {
  final Function(ExpenseModel) onSave;

  const AddExpenseSheet({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.instance.currentUserId ?? 'local_user';
    return ExpenseForm(
      userId: userId,
      onSave: onSave,
    );
  }
}
