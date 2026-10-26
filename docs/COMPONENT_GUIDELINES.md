# 组件使用规范文档

## 1. 概述

本文档定义了 `pure_enjoy` 项目中所有组件、服务、工具类及通用开发规范的统一使用标准。所有参与项目开发的成员在编写代码时必须遵循本文档中的约定，以确保代码风格一致、可维护性高、减少重复代码和潜在缺陷。

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
import '../../../core/widgets/widgets.dart' show ErrorWidget;

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
  bool danger = false,
})
```

**使用示例：**

```dart
final confirmed = await showConfirmDialog(
  context,
  title: '删除确认',
  content: '确定要删除这条记录吗？此操作不可撤销。',
  confirmText: '删除',
  danger: true,
);
if (confirmed) {
  _deleteItem();
}
```

**规范要求：**

- 所有删除/危险操作**必须**使用此方法进行确认，**禁止**直接执行。
- 根据操作危险程度，可自定义 `confirmText`（如"删除"、"清空"）；破坏性操作传 `danger: true`（确认钮走 error 色）。

---

### 2.5 showSnackBar — SnackBar 提示

**用途：** 操作结果反馈的统一 SnackBar 提示。

**签名：**

```dart
void showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = false,
})
```

**使用示例：**

```dart
// 成功提示（绿底）
showSnackBar(context, '保存成功', isSuccess: true);

// 普通提示
showSnackBar(context, '已复制');

// 错误提示（红字）
showSnackBar(context, '操作失败，请重试', isError: true);
```

**规范要求：**

- 所有操作结果反馈**统一**使用此方法，**禁止**直接使用 `ScaffoldMessenger.of(context).showSnackBar`。
- 成功场景传 `isSuccess: true`（绿底），错误场景传 `isError: true`；内部已带 `context.mounted` 守卫。
- 宠物模块内另有同构轻提示 `showPetToast`（见 §8）。

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

### 3.2 AsyncSubmitButton — 异步提交按钮

**用途：** 异步提交动作的统一按钮：自动管理 loading 态、请求期间防重复点击。位于 `lib/core/widgets/widgets.dart`。

**使用示例：**

```dart
AsyncSubmitButton(
  label: '保存',
  onPressed: () => _save(),
)
```

**规范要求：**

- 异步提交场景**统一**使用此组件，**禁止**自行用 `StatefulWidget` 管理 loading + `onPressed: null` 防抖。
- 同类复用件：`SheetContainer`（底部弹层统一容器，键盘避让 + 手势条，同文件）、`PaginatedListMixin`（分页列表，`lib/core/widgets/paginated_list_mixin.dart`）。

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

**用途：** 所有与后端 API 的通信统一通过 `ApiClient` 进行。全静态方法设计；返回类型统一为非泛型 `ApiResponse`（`isSuccess` / `errorMessage` / `data` / `raw`）。

**方法清单（现行签名）：**

```dart
class ApiClient {
  // 查询列表（注意：limit 缺省为 10 —— 不传只拿 10 条，全量需显式传）
  static Future<ApiResponse> get(String table, {
    List<String>? select, Map<String, String>? filters, String? order,
    int? limit = 10, int? offset, List<String>? columns,  // columns 为兼容参数
    String? search, List<String>? searchFields,
    Duration? timeout, CancelToken? cancelToken, String? note, bool? useETag,
  });

  // 新增（body 与 data 二选一，returnRepresentation 控制 Prefer 头）
  static Future<ApiResponse> post(String table, Map<String, dynamic> data,
      {Map<String, dynamic>? body, bool returnRepresentation = false, ...});

  // 按 id 更新
  static Future<ApiResponse> patch(String table, Map<String, dynamic> data,
      {Map<String, dynamic>? body, required String id, Duration? timeout, String? note});

  // 按 filters 更新（patch 的过滤版）
  static Future<ApiResponse> patchByFilter(String table,
      {required Map<String, String> filters, required Map<String, dynamic> body, ...});

  // 按 id 删除 / 批量删除
  static Future<ApiResponse> delete(String table, {required String id, ...});
  static Future<ApiResponse> batchDelete(String table, {required List<String> ids, ...});
  static Future<ApiResponse> batchDeleteByFilter(String table,
      {required Map<String, String> filters, ...});

  // 聚合与 RPC
  static Future<ApiResponse> sum(String table, {required String column, ...});
  static Future<ApiResponse> count(String table, {Map<String, String>? filters, ...});
  static Future<ApiResponse> rpc(String functionName,
      {Map<String, dynamic>? params, Duration? timeout, String? note});
}
```

**使用示例：**

```dart
// 查询列表（显式 limit）
final result = await ApiClient.get(
  'expenses',
  select: 'id,amount,created_at',
  filters: {'user_id': 'eq.$uid'},
  order: 'created_at.desc',
  limit: 50,
);
if (result.isSuccess) {
  final rows = result.data ?? [];
}

// RPC 调用
final res = await ApiClient.rpc('rpc_pet_feed', params: {'p_pet_id': petId});

// 按 id 更新
await ApiClient.patch('expenses', {'amount': 100}, id: expenseId);
```

**规范要求：**

- 所有 API 调用**必须**通过 `ApiClient`，**禁止**直接使用 `http` 包或其他网络请求方式。
- `get` 的 `limit` 缺省 **10**：全量/大列表必须显式传 limit，防静默截断。
- `filters` 使用 `Map<String, String>`；同名字段复合条件用 Supabase `and` 语法：
  ```dart
  filters: {'and': '(field1.gte.val1,field2.lt.val2)'}
  ```
- **始终**检查 `result.isSuccess` 后再使用 `result.data`，**禁止**未检查直接使用。
- POST/PATCH 的字段名**必须**与数据库表字段完全一致（snake_case）。

---

### 4.2 AuthService — 用户认证服务

**用途：** 认证门面，位于 `lib/services/supabase_service.dart`（非独立文件）。

**使用示例：**

```dart
// 应用启动初始化
await AuthService.instance.initialize();

// 登录（邮箱 / 账号名两种入口）
await AuthService.instance.signInWithEmail(email, password);
await AuthService.instance.signInWithAccount(account, password);

// 登出
await AuthService.instance.signOut();
```

**规范要求：**

- 认证操作**统一**走 `AuthService.instance`，**禁止**直接调用 Supabase Auth REST。
- Token 持久化与 180 天过期检查由 `SessionManager`（`lib/services/session_manager.dart`）负责。

---

### 4.3 StorageService — 文件存储服务

**用途：** 管理文件的上传、下载和删除。

**规范要求：**

- 所有文件上传/下载/删除操作**必须**通过 `StorageService`，**禁止**直接调用存储 API。
- 通过 `StorageService.instance` 单例访问。

---

### 4.4 DictService — 字典服务

**用途：** 字典数据（心情类型、消费分类等）的统一读取，位于 `lib/services/dict_service.dart`；扩展查询在 `dict_queries.dart`。

**使用示例：**

```dart
// 静态 getter 直取字典项（同步，启动后可用）
final moods = DictService.moodType;
final categories = DictService.expenseCategory;

// 异步取列表 / 附加数据
final items = await DictService.instance.getItemsSync(type: 'mood_type');
final extra = await DictService.instance.getExtra('mood_type');

// 值转标签（扩展方法，双参数：类型码 + 值）
final label = dictService.getLabel('mood_type', value);
```

**规范要求：**

- 字典读取**统一**走 `DictService`（静态 getter + instance 方法），**禁止**在 UI 里硬编码字典映射。

---

### 4.5 NotificationService — 本地通知服务

**用途：** 管理本地通知的调度和显示。

**规范要求：**

- 所有通知功能**必须**通过 `NotificationService`，**禁止**直接使用通知插件。
- 通过 `NotificationService.instance` 单例访问。

---

### 4.6 SensitiveWordService — 敏感词过滤

**用途：** 用户产生内容的敏感词检测与过滤，位于 `lib/services/sensitive_word_service.dart`。

**使用示例：**

```dart
// 分域检测
final r1 = await SensitiveWordService.instance.checkNovelContent(text);
final r2 = await SensitiveWordService.instance.checkSystemContent(text);
final r3 = await SensitiveWordService.instance.checkAll(text);

// 过滤并落审计日志
final filtered = await SensitiveWordService.instance.filterAndLog(
  text: text, category: 'nickname', source: 'profile',
);
```

**规范要求：**

- 用户昵称/笔记/反馈等输入**必须**过敏感词检测（App 端预检 + 服务端复核双闸）。

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

### 5.3 EventBus — 事件总线

**用途：** 跨页面/跨模块的轻量事件通信，位于 `lib/core/utils/event_bus.dart`（全项目 20+ 文件复用）。

```dart
EventBus.instance.on(SomeEvent, (_) => _refresh());   // 订阅（记得 dispose 时 off）
EventBus.instance.emit(SomeEvent(payload));           // 发布
```

**规范要求：** 页面间状态通知**优先**用 EventBus / Riverpod，**禁止**为传一个回调层层透传构造参数；订阅必须在 `dispose` 解绑。

---

### 5.4 FormatUtils — 格式化工具

**用途：** 金额/数字等展示格式化，位于 `lib/utils/format_utils.dart`。展示层格式化**统一**用工具方法，**禁止**散落手写 `toStringAsFixed` 拼接。

---

## 6. 主题规范

> 文件位置：`lib/core/theme/`

### 6.1 AppTheme — 应用主题

**用途：** 定义应用的全局颜色常量，位于 `lib/core/theme/app_theme.dart`。

**现行色板（摘录）：** `primaryOrange`（主色 0xFFF26522）、`primaryYellow`、`primaryLight`、`primaryDark`、`secondaryColor`、`accentColor`、语义色 `success` / `warning` / `error` / `info`、中性灰阶 `neutral100` ~ `neutral900`。

**规范要求：**

- 所有颜色值**必须**使用 `AppTheme` 中定义的常量，**禁止**硬编码颜色值（如 `Color(0xFF123456)`）。
- 语义场景用语义色（成功 `success`、危险 `error`），**禁止**拿中性灰代替。

```dart
// 正确
Container(color: AppTheme.primaryOrange)

// 错误
Container(color: Color(0xFF2196F3))
```

---

### 6.2 ThemeProvider — 主题状态管理

**用途：** 主题（8 种配色 + 明暗）状态管理，位于 `lib/core/theme/theme_provider.dart`，经 **Riverpod** 暴露：

```dart
final themeProvider = ChangeNotifierProvider<ThemeProvider>(...);
```

**规范要求：**

- 读写主题统一走 `ref.watch(themeProvider)` / `ref.read(themeProvider)`（`ThemeProvider` 无 `instance` 单例），**禁止**绕过 Provider 直接改主题状态。

---

## 7. 通用开发规范

### 7.1 Model 规范

**规范要求：**

- 所有数据模型类放在对应 feature 的 `models/` 目录，文件名小写下划线（如 `expense_model.dart`）。
- `fromJson`：必填字段直接 `as String` / `as num` 强转（缺字段即报错，尽早暴露脏数据）；可选字段才用 `as String?` + 默认值。
- 需要把模型 PATCH 回服务端的，实现 `toJsonForUpdate()` 排除只读字段（目前 life 系模型采用；纯展示模型可不做）。
- 字段名与数据库列一致（snake_case），禁止在 Model 里做驼峰转换。

**示例（现行风格）：**

```dart
class ExpenseModel {
  const ExpenseModel({required this.id, required this.amount, this.note});

  final String id;      // 必填：强转
  final double amount;  // 必填：强转
  final String? note;   // 可选：可空

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        note: json['note'] as String?,
      );
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
| 文件名 | `snake_case.dart` | `expense_model.dart` |
| 类名 | `PascalCase` | `NovelModel` |
| 方法/变量 | `camelCase` | `loadData()`, `novelList` |
| 常量 | `camelCase`（Dart 风格） | `maxRetryCount` |
| 数据库字段 | `snake_case` | `created_at`, `cover_url` |

---

### 7.5 导入规范

**规范要求：**

- 相对路径导入**必须**使用 `../` 形式。
- 项目内统一使用**相对路径**导入（`../`、`./`）；少量历史文件用 `package:pure_enjoy/` 自导入属存量，新代码不新增。

**正确示例：**

```dart
import '../models/expense_model.dart';
import '../../services/api_client.dart';
```

**错误示例（禁止）：**

```dart
import 'package:pure_enjoy/features/life/models/expense_model.dart';  // 反例示例
```

---

## 8. 宠物模块共享组件与工具

> 位置：`lib/features/pets/widgets/` 与 `lib/features/pets/utils/`——已在模块外（home dashboard）复用的，视同全局规范件。

| 名称 | 位置 | 用途 |
|------|------|------|
| `showPetToast` / `dismissPetToast` | `widgets/pet_toast.dart` | 宠物模块统一轻提示（与 showSnackBar 同构），模块内**禁止**混用 SnackBar |
| `petRpcErrorText` / `kPetLocalError` | `utils/pet_errors.dart` | 服务端错误码 → 用户文案统一转译（22+ 文件复用，含模块外 api_response_handler） |
| `PetItemIcon` | `widgets/pet_item_icon.dart` | 道具图标统一件（icon/<key> 解析 + 兜底图标） |
| `PetCategoryRail` | `widgets/pet_category_rail.dart` | 分类横栏（背包/商城共用），分类清单与 `PetShopItemModel.categoryLabels` 同源 |
| `PetClaimResultDialog` / `buildClaimItems` | `widgets/pet_claim_result_dialog.dart`、`pet_home_adventure.dart` | 历险领取结果弹窗与掉落明细组装（双入口同源） |
| `petGoldLabel` / `petGoldConverted` | `utils/pet_gold_format.dart` | 金币 K/M 单位转换（截断 1 位小数；≥10万 K、≥100万 M）——**禁止**手写金币格式化 |
| `petDecayedStat` | `utils/pet_decay_display.dart` | 饱食/心情展示层衰减插值（服务端惰性结算为准） |

**规范要求：**

- 上述件在宠物模块内外复用时**直接引用**，**禁止**复制第二份实现。
- 新增宠物页面的提示/错误/金币展示一律走本表组件，保持口径唯一。

---

## 9. 文档维护

- 本文档与 README/PET_REQUIREMENTS 每次大版本功能落地后同步校对；API 声明以代码为准（`lib/` 实况），发现失实即改。

