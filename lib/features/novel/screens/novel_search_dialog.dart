import 'package:flutter/material.dart';

/// 显示搜索小说对话框
void showNovelSearchDialog(
  BuildContext context, {
  required TextEditingController controller,
  required ValueChanged<String> onSearchChanged,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('搜索小说'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '输入小说名或作者名',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: onSearchChanged,
      ),
      actions: [
        TextButton(
          onPressed: () {
            controller.clear();
            onSearchChanged('');
            Navigator.pop(context);
          },
          child: const Text('清除'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('搜索'),
        ),
      ],
    ),
  );
}
