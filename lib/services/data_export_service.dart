import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
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
      final data = <String, dynamic>{
        'export_time': DateTime.now().toIso8601String(),
        'user_id': userId,
        'app_version': '1.8.5',
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
    final response = await http.get(
      Uri.parse(
        '${SupabaseConfig.url}/rest/v1/$table?user_id=eq.$userId'
        '&select=*&order=created_at.desc',
      ),
      headers: {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
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
        // 使用 count 模式获取条数
        final response = await http.get(
          Uri.parse(
            '${SupabaseConfig.url}/rest/v1/$table?user_id=eq.$userId&select=id',
          ),
          headers: {
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            'Prefer': 'count=exact',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          counts[table] = data.length;
        } else {
          counts[table] = 0;
        }
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
