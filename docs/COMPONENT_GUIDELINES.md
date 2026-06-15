# 组件使用规范文档

## 1. 概述

本文档定义了 `app-client` 项目中所有组件、服务、工具类及通用开发规范的统一使用标准。所有参与项目开发的成员在编写代码时必须遵循本文档中的约定，以确保代码风格一致、可维护性高、减少重复代码和潜在缺陷。

**适用范围：**

- `lib/core/widgets/` — 核心 UI 组件
- `lib/widgets/` — 业务通用组件
- `lib/services/` — 服务层
- `lib/utils/` — 工具类
- `lib/core/theme/` — 主题
- `lib/features/` — 业务功能模块（Model、Screen 等）

---

## 2. 核心 UI 组件规范

> 文件位置：`lib/core/widgets/widgets.dart`

### 2.1 LoadingWidget — 通用加载指示器

**用途：** 所有异步加载场景的统一加载指示器。

**参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `message` | `String?` | `null` | 加载提示文字，可选 |
| `size` | `double` | `40` | 指示器尺寸 |

**使用示例：**

```dart
LoadingWidget(message: '加载中...')
```

**规范要求：**

- 所有异步加载场景**必须**使用此组件，**禁止**自行创建 `CircularProgressIndicator`。
- 如需显示加载提示文字，传入 `message` 参数。

---

### 2.2 EmptyWidget — 空状态占位

**用途：** 列表或数据为空时的统一空状态展示。

**参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `icon` | `IconData` | `Icons.inbox_outlined` | 空状态图标 |
| `message` | `String` | **必填** | 空状态提示文字 |
| `actionText` | `String?` | `null` | 操作按钮文字 |
| `onAction` | `VoidCallback?` | `null` | 操作按钮回调 |

**使用示例：**

```dart
EmptyWidget(
  message: '暂无数据',
  actionText: '去添加',
  onAction: () => Navigator.push(...),
)
```

**规范要求：**

- 列表/数据为空时**必须**使用此组件。
- `message` 为**必填**参数，必须提供有意义的提示文字。

---

### 2.3 ErrorWidget — 错误状态展示

> **注意：** 此组件与 Flutter 内置的 `ErrorWidget` 同名，使用时需注意命名空间，建议通过 `hide` 或 `show` 明确区分。

**用途：** 加载失败时的统一错误状态展示。

**参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `message` | `String` | **必填** | 错误提示文字 |
| `actionText` | `String?` | `null` | 重试按钮文字 |
| `onRetry` | `VoidCallback?` | `null` | 重试回调 |

**使用示例：**

```dart
// 在导入时隐藏 Flutter 内置 ErrorWidget
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:app-client/core/widgets/widgets.dart' show ErrorWidget;

ErrorWidget(
  message: '加载失败，请重试',
  onRetry: () => _loadData(),
)
```

**规范要求：**

- 加载失败时**必须**使用此组件展示错误状态。
- **必须**提供 `onRetry` 回调，确保用户可以重试操作。

---

### 2.4 showConfirmDialog — 确认对话框

**用途：** 所有需要用户确认的操作（删除、危险操作等）的统一对话框。

**签名：**

```dart
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = '确定',
  String cancelText = '取消',
})
```

**使用示例：**

```dart
final confirmed = await showConfirmDialog(
  context,
  title: '删除确认',
  content: '确定要删除这条记录吗？此操作不可撤销。',
  confirmText: '删除',
);
if (confirmed) {
  _deleteItem();
}
```

**规范要求：**

- 所有删除/危险操作**必须**使用此方法进行确认，**禁止**直接执行。
- 根据操作危险程度，可自定义 `confirmText`（如"删除"、"清空"）。

---

### 2.5 showSnackBar — SnackBar 提示

**用途：** 操作结果反馈的统一 SnackBar 提示。

**签名：**

```dart
void showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
})
```

**使用示例：**

```dart
// 成功提示
showSnackBar(context, '保存成功');

// 错误提示
showSnackBar(context, '操作失败，请重试', isError: true);
```

**规范要求：**

- 所有操作结果反馈**统一**使用此方法，**禁止**直接使用 `ScaffoldMessenger.of(context).showSnackBar`。
- 错误场景传入 `isError: true`。

---

## 3. 业务通用组件规范

> 文件位置：`lib/widgets/common_widgets.dart`

### 3.1 CategoryChip — 分类筛选标签

**用途：** 筛选标签的统一组件。

**参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `label` | `String` | **必填** | 标签文字 |
| `isSelected` | `bool` | **必填** | 是否选中 |
| `onTap` | `VoidCallback` | **必填** | 点击回调 |

**使用示例：**

```dart
CategoryChip(
  label: '全部',
  isSelected: _selectedCategory == null,
  onTap: () => setState(() => _selectedCategory = null),
)
```

**规范要求：**

- 所有筛选标签**统一**使用此组件，**禁止**自行实现类似功能。

---

### 3.2 NovelCoverImage — 小说封面

**用途：** 小说封面的统一展示组件，处理图片加载、占位和错误状态。

**参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `coverUrl` | `String?` | `null` | 封面图片 URL |
| `width` | `double` | `80` | 封面宽度 |
| `height` | `double` | `110` | 封面高度 |

**使用示例：**

```dart
NovelCoverImage(
  coverUrl: novel.coverUrl,
  width: 100,
  height: 140,
)
```

**规范要求：**

- 小说封面**统一**使用此组件，**禁止**自行使用 `Image.network` 展示封面。

---

### 3.3 EditDeletePopupMenu — 编辑/删除弹出菜单

**用途：** 列表项编辑/删除操作的统一弹出菜单。

**参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `onEdit` | `VoidCallback?` | `null` | 编辑回调 |
| `onDelete` | `VoidCallback?` | `null` | 删除回调 |

**使用示例：**

```dart
EditDeletePopupMenu(
  onEdit: () => _navigateToEdit(item),
  onDelete: () => _confirmDelete(item),
)

// 仅显示删除
EditDeletePopupMenu(
  onDelete: () => _confirmDelete(item),
)

// 仅显示编辑
EditDeletePopupMenu(
  onEdit: () => _navigateToEdit(item),
)
```

**规范要求：**

- 列表项的编辑/删除操作**统一**使用此组件。
- 传入 `null` 的回调会自动隐藏对应菜单项。

---

## 4. 服务层规范

> 文件位置：`lib/services/`

### 4.1 ApiClient — 统一 REST API 客户端

**用途：** 所有与后端 API 的通信统一通过 `ApiClient` 进行。`ApiClient` 采用全静态方法设计，无需实例化。

**方法签名：**

```dart
class ApiClient {
  // 查询列表
  static Future<ApiResponse<List<Map<String, dynamic>>>> get(
    String table, {
    List<String>? select,
    Map<String, String>? filters,
    String? order,
    int? limit,
    int? offset,
  });

  // 查询单条
  static Future<ApiResponse<Map<String, dynamic>>> getOne(
    String table, {
    Map<String, String>? filters,
    List<String>? select,
  });

  // 新增
  static Future<ApiResponse<Map<String, dynamic>>> post(
    String table, {
    required Map<String, dynamic> body,
    bool returnRepresentation = true,
    Map<String, String>? extraHeaders,
  });

  // 更新
  static Future<ApiResponse<bool>> patch(
    String table, {
    required Map<String, String>? filters,
    required Map<String, dynamic> body,
  });

  // 删除
  static Future<ApiResponse<bool>> delete(
    String table, {
    required Map<String, String>? filters,
  });
}
```

**使用示例：**

```dart
// 查询列表
final result = await ApiClient.get(
  'novels',
  filters: {'status': 'eq.published'},
  order: 'created_at.desc',
  limit: 20,
);
if (result.isSuccess) {
  final novels = result.data;
}

// 复杂过滤（Supabase and 语法）
final result = await ApiClient.get(
  'expenses',
  filters: {
    'and': '(amount.gte.100,created_at.lt.2024-01-01)',
  },
);

// 新增
final result = await ApiClient.post(
  'novels',
  body: novel.toJson(),
);

// 更新
final result = await ApiClient.patch(
  'novels',
  filters: {'id': 'eq.$novelId'},
  body: {'title': '新标题'},
);

// 删除
final result = await ApiClient.delete(
  'novels',
  filters: {'id': 'eq.$novelId'},
);
```

**规范要求：**

- 所有 API 调用**必须**通过 `ApiClient`，**禁止**直接使用 `http` 包或其他网络请求方式。
- `filters` 使用 `Map<String, String>` 格式，同名字段需使用 Supabase `and` 语法：
  ```dart
  filters: {'and': '(field1.gte.val1,field2.lt.val2)'}
  ```
- **始终**检查 `result.isSuccess` 后再使用 `result.data`，**禁止**未检查直接使用。
- POST 请求时，`body` 字段名**必须**与数据库表字段完全一致（snake_case）。

---

### 4.2 AuthService — 用户认证服务

**用途：** 管理用户登录、注册、登出等认证相关功能。

**使用示例：**

```dart
// 初始化
await AuthService.instance.initialize();

// 登录
final result = await AuthService.instance.login(email, password);

// 登出
await AuthService.instance.logout();
```

**规范要求：**

- 通过 `AuthService.instance` 单例访问，**禁止**自行实例化。
- 使用前**必须**调用 `initialize()` 进行初始化。

---

### 4.3 StorageService — 文件存储服务

**用途：** 管理文件的上传、下载和删除。

**规范要求：**

- 所有文件上传/下载/删除操作**必须**通过 `StorageService`，**禁止**直接调用存储 API。
- 通过 `StorageService.instance` 单例访问。

---

### 4.4 DictService — 字典服务

**用途：** 管理下拉选项、标签显示等字典数据的获取。

**使用示例：**

```dart
// 获取分类列表
final categories = await DictService.instance.getCategories();

// 获取标签显示名
final label = DictService.instance.getLabel(code);
```

**规范要求：**

- 所有下拉选项/标签显示**必须**通过 `DictService` 获取，**禁止**硬编码选项列表。
- **已废弃：** `AppConstants` 中的 `expenseCategories`、`moodTypes` 等常量，请迁移至 `DictService`。
- 通过 `DictService.instance` 单例访问。

---

### 4.5 NotificationService — 本地通知服务

**用途：** 管理本地通知的调度和显示。

**规范要求：**

- 所有通知功能**必须**通过 `NotificationService`，**禁止**直接使用通知插件。
- 通过 `NotificationService.instance` 单例访问。

---

### 4.6 SensitiveWordService — 敏感词过滤服务

**用途：** 对用户输入内容进行敏感词过滤。

**规范要求：**

- 用户输入内容（小说内容、评论等）提交前**必须**通过 `SensitiveWordService` 进行过滤。
- 通过 `SensitiveWordService.instance` 单例访问。

**使用示例：**

```dart
final filteredContent = await SensitiveWordService.instance.filter(content);
if (filteredContent != content) {
  showSnackBar(context, '内容包含敏感词，已自动过滤', isError: true);
}
```

---

## 5. 工具类规范

> 文件位置：`lib/utils/`

### 5.1 CacheHelper — 本地缓存

**用途：** 管理本地数据的缓存读写。

**规范要求：**

- 列表数据优先使用缓存，减少网络请求。
- 缓存键**必须**使用预定义常量，**禁止**硬编码缓存键字符串。

---

### 5.2 DateTimeUtils — 日期格式化

**用途：** 统一的日期格式化和解析工具。

**规范要求：**

- 日期显示**统一**使用 `DateTimeUtils` 提供的格式化方法。
- 日期存储时使用 `toTimestampString()` 或 `toDateString()` 进行序列化。

**使用示例：**

```dart
// 显示格式化日期
final displayDate = DateTimeUtils.formatDate(DateTime.now());

// 存储序列化
final timestamp = DateTimeUtils.toTimestampString(DateTime.now());
```

---

## 6. 主题规范

> 文件位置：`lib/core/theme/`

### 6.1 AppTheme — 应用主题

**用途：** 定义应用的全局颜色、字体、间距等主题常量。

**规范要求：**

- 所有颜色值**必须**使用 `AppTheme` 中定义的常量，**禁止**硬编码颜色值（如 `Color(0xFF123456)`）。

**使用示例：**

```dart
// 正确
Container(color: AppTheme.primaryColor)

// 错误
Container(color: Color(0xFF2196F3))
```

---

### 6.2 ThemeProvider — 主题状态管理

**用途：** 管理应用的主题切换状态（如深色/浅色模式）。

**规范要求：**

- 通过 `ThemeProvider.instance` 管理主题状态，**禁止**绕过 ThemeProvider 直接修改主题。

---

## 7. 通用开发规范

### 7.1 Model 规范

所有数据模型**必须**实现以下方法：

| 方法 | 说明 |
|------|------|
| `fromJson` | 从 JSON（Map）构造对象，**必须**处理 null 值 |
| `toJson` | 序列化为 JSON，字段名**必须**与数据库表字段完全一致（snake_case） |
| `toJsonForUpdate` | 序列化为更新用的 JSON（通常排除只读字段） |
| `copyWith` | 创建对象副本并修改指定字段 |

**规范要求：**

- `toJson` 字段名**必须**与数据库表字段完全一致（snake_case）。
- `fromJson` **必须**处理 null 值，使用 `as String? ?? '默认值'` 形式提供默认值。

**使用示例：**

```dart
class Novel {
  final String id;
  final String title;
  final String? coverUrl;

  Novel({required this.id, required this.title, this.coverUrl});

  factory Novel.fromJson(Map<String, dynamic> json) {
    return Novel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover_url': coverUrl,
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'title': title,
      'cover_url': coverUrl,
    };
  }

  Novel copyWith({String? title, String? coverUrl}) {
    return Novel(
      id: id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}
```

---

### 7.2 异步操作规范

**规范要求：**

- 所有 `async` 方法中，`await` 之后的 `setState` **必须**检查 `if (mounted)`：

```dart
Future<void> _loadData() async {
  final result = await ApiClient.get('novels');
  if (!mounted) return; // 必须检查
  setState(() {
    _novels = result.data;
  });
}
```

- `dispose` 中**禁止**调用可能触发 `setState` 的 `async` 方法。如必须调用，确保方法内部有 `mounted` 检查。

---

### 7.3 错误处理规范

**规范要求：**

- API 调用**必须**使用 `try-catch` 包裹。
- `catch` 中**必须**使用 `showSnackBar` 或 `ErrorWidget` 向用户提示错误信息。
- **禁止**静默吞掉错误（空 `catch` 块）。

**正确示例：**

```dart
try {
  final result = await ApiClient.post('novels', body: novel.toJson());
  if (result.isSuccess) {
    showSnackBar(context, '保存成功');
  } else {
    showSnackBar(context, result.errorMessage ?? '操作失败', isError: true);
  }
} catch (e) {
  showSnackBar(context, '网络异常，请重试', isError: true);
}
```

**错误示例（禁止）：**

```dart
// 禁止：空 catch 块
try {
  await ApiClient.post('novels', body: novel.toJson());
} catch (e) {
  // 什么都不做
}
```

---

### 7.4 命名规范

| 类别 | 规范 | 示例 |
|------|------|------|
| 文件名 | `snake_case.dart` | `novel_model.dart` |
| 类名 | `PascalCase` | `NovelModel` |
| 方法/变量 | `camelCase` | `loadData()`, `novelList` |
| 常量 | `camelCase`（Dart 风格） | `maxRetryCount` |
| 数据库字段 | `snake_case` | `created_at`, `cover_url` |

---

### 7.5 导入规范

**规范要求：**

- 相对路径导入**必须**使用 `../` 形式。
- **禁止**使用绝对路径导入（如 `package:app-client/...` 之外的绝对路径）。

**正确示例：**

```dart
import '../models/novel_model.dart';
import '../../services/api_client.dart';
```

**错误示例（禁止）：**

```dart
import '/workspace/app-client/lib/models/novel_model.dart';
```
