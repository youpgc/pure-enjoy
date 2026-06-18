import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_client.dart';
import 'supabase_service.dart';

/// 数据导出服务
class DataExportService {
  /// 导出类型
  static const String typeExpenses = 'expenses';
  static const String typeWeight = 'weight_records';
  static const String typeMood = 'mood_diaries';
  static const String typeAll = 'all';

  /// 导出数据并分享
  static Future<ExportResult> exportAndShare({
    required String type,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      return ExportResult(success: false, error: '请先登录');
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final data = <String, dynamic>{
        'export_time': DateTime.now().toIso8601String(),
        'user_id': userId,
        'app_version': '${packageInfo.version}+${packageInfo.buildNumber}',
      };

      // 根据类型获取数据
      if (type == typeExpenses || type == typeAll) {
        data['expenses'] = await _fetchData('expenses', userId);
      }
      if (type == typeWeight || type == typeAll) {
        data['weight_records'] = await _fetchData('weight_records', userId);
      }
      if (type == typeMood || type == typeAll) {
        data['mood_diaries'] = await _fetchData('mood_diaries', userId);
      }

      // 生成 JSON 文件
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'pure_enjoy_${type}_$dateStr.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonString);

      // 分享文件
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '纯享数据导出 - $fileName',
      );

      // 统计条数
      int totalCount = 0;
      if (data.containsKey('expenses')) totalCount += (data['expenses'] as List).length;
      if (data.containsKey('weight_records')) totalCount += (data['weight_records'] as List).length;
      if (data.containsKey('mood_diaries')) totalCount += (data['mood_diaries'] as List).length;

      return ExportResult(
        success: true,
        count: totalCount,
        filePath: file.path,
      );
    } catch (e) {
      return ExportResult(success: false, error: e.toString());
    }
  }

  /// 从 Supabase 获取数据
  static Future<List<Map<String, dynamic>>> _fetchData(
    String table,
    String userId,
  ) async {
    // expenses/weight_records/mood_diaries 使用 date 排序，其他表使用 created_at
    final orderField = (table == typeExpenses || table == typeWeight || table == typeMood)
        ? 'date'
        : 'created_at';

    final result = await ApiClient.get(
      table,
      filters: {'user_id': userId},
      select: '*',
      order: '$orderField.desc',
    );

    if (result.isSuccess && result.data != null) {
      return result.data!;
    }

    return [];
  }

  /// 获取各类型数据条数预览
  static Future<Map<String, int>> getDataCounts() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return {};

    final counts = <String, int>{};

    for (final table in [typeExpenses, typeWeight, typeMood]) {
      try {
        // 使用 count=exact 获取条数
        counts[table] = await ApiClient.count(
          table,
          filters: {'user_id': 'eq.$userId'},
        );
      } catch (e) {
        counts[table] = 0;
      }
    }

    return counts;
  }
}

/// 导出结果
class ExportResult {
  final bool success;
  final int? count;
  final String? filePath;
  final String? error;

  ExportResult({
    required this.success,
    this.count,
    this.filePath,
    this.error,
  });
}
