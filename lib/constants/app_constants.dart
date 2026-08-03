// 应用常量定义
// 集中管理角色、状态、字典类型等硬编码值，避免散落各处

// ==================== 角色常量 ====================

/// 普通用户角色
const String roleUser = 'user';

/// 管理员角色
const String roleAdmin = 'admin';

/// 超级管理员角色
const String roleSuperAdmin = 'super_admin';

/// 管理员角色列表（含超级管理员和普通管理员）
const List<String> adminRoles = [roleAdmin, roleSuperAdmin];

// ==================== 字典类型编码 ====================

/// 客户端需要的字典类型编码列表
/// 对应 dict_service.dart 中 _neededCodes
const List<String> dictCodes = [
  'user_role',
  'member_level',
  'user_status',
  'expense_category',
  'mood_type',
  'habit_frequency',
  'habit_color',
  'novel_category',
  'novel_status',
  'feedback_category',
  'feedback_status',
  'notification_type',
  'announcement_type',
  'priority_level',
  'favorite_category',
  'note_category',
];
