import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import './api_client.dart';

/// 离线操作类型
enum OfflineAction { create, update, delete }

/// 离线同步服务
/// 基于 SharedPreferences 实现轻量级写入前日志（Write-Ahead Log）
/// 当网络请求失败时，将操作加入本地队列，网络恢复后自动同步
class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  static const String _queueKey = 'offline_sync_queue';
  static const int maxRetryCount = 10;

  /// 与设置页（settings_screen）保持一致的开关 key / 默认值
  static const String _autoSyncSettingKey = 'setting_auto_sync';
  static const String _wifiOnlySettingKey = 'setting_wifi_only';

  bool _isSyncing = false;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool _listenerRegistered = false;
  bool _wasOffline = false;

  /// 初始化：启动时尝试同步待处理队列，并注册网络恢复监听
  Future<void> initialize() async {
    await syncPending(isBackground: true);
    _registerConnectivityListener();
  }

  /// 注册网络状态监听：网络从离线恢复时自动补发离线队列，
  /// 消除「离线写成功入队但永不补发（直到重启或手动触发）」的弱一致。
  void _registerConnectivityListener() {
    if (_listenerRegistered) return;
    _listenerRegistered = true;
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      final online = result != ConnectivityResult.none;
      if (online && _wasOffline) {
        if (kDebugMode) debugPrint('📡 网络恢复，自动补发离线队列');
        syncPending(isBackground: true);
      }
      _wasOffline = !online;
    });
  }

  /// 释放网络监听（应用退出时调用）
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _listenerRegistered = false;
  }

  /// 将失败的操作加入离线队列
  Future<void> enqueue({
    required OfflineAction action,
    required String table,
    Map<String, dynamic>? data,
    Map<String, String>? filters,
  }) async {
    final queue = await _loadQueue();
    queue.add({
      'action': action.name,
      'table': table,
      'data': data,
      'filters': filters,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
    });
    await _saveQueue(queue);
    if (kDebugMode) {
      debugPrint('📦 离线队列：已加入 $action 操作到 $table，当前队列 ${queue.length} 项');
    }
  }

  /// 同步所有待处理的操作。
  /// [isBackground] 标记是否为后台自动触发（启动 / 网络恢复）；
  /// 仅后台触发受「自动同步」总闸约束，用户主动操作（内联）触发的同步始终执行。
  Future<void> syncPending({bool isBackground = false}) async {
    // 全局总闸：仅 WiFi 同步 —— 当前非 WiFi 网络直接中止本次同步
    final wifiOnly = await _isWifiOnlyEnabled();
    if (wifiOnly) {
      final connectivity = await _connectivity.checkConnectivity();
      if (connectivity != ConnectivityResult.wifi) {
        if (kDebugMode) {
          debugPrint('📶 仅 WiFi 同步已开启，当前非 WiFi 网络，跳过本次同步');
        }
        return;
      }
    }

    // 后台自动同步总闸：关闭后启动 / 网络恢复不再自动补发（用户主动操作仍同步）
    if (isBackground && !await _isAutoSyncEnabled()) {
      if (kDebugMode) {
        debugPrint('🔕 自动同步已关闭，跳过后台自动补发');
      }
      return;
    }

    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final queue = await _loadQueue();
      if (queue.isEmpty) return;

      if (kDebugMode) {
        debugPrint('🔄 开始同步离线队列，共 ${queue.length} 项');
      }

      final remaining = <Map<String, dynamic>>[];

      for (final item in queue) {
        final success = await _syncItem(item);
        if (!success) {
          final retryCount = (item['retryCount'] as int?) ?? 0;
          if (retryCount < maxRetryCount) {
            item['retryCount'] = retryCount + 1;
            remaining.add(item);
          } else {
            if (kDebugMode) {
              debugPrint('⚠️ 离线操作超过最大重试次数，已丢弃: ${item['table']} ${item['action']}');
            }
          }
        }
      }

      await _saveQueue(remaining);

      if (kDebugMode) {
        final synced = queue.length - remaining.length;
        if (synced > 0) {
          debugPrint('✅ 离线同步完成：$synced 项成功，${remaining.length} 项待重试');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 离线同步出错: $e');
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// 获取待同步数量
  Future<int> getPendingCount() async {
    final queue = await _loadQueue();
    return queue.length;
  }

  /// 清空队列
  Future<void> clearQueue() async {
    await _saveQueue([]);
  }

  /// 读取「自动同步」开关（默认开启，与设置页一致）
  Future<bool> _isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncSettingKey) ?? true;
  }

  /// 读取「仅 WiFi 同步」开关（默认开启，与设置页一致）
  Future<bool> _isWifiOnlyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wifiOnlySettingKey) ?? true;
  }

  /// 同步单条操作
  Future<bool> _syncItem(Map<String, dynamic> item) async {
    try {
      final action = OfflineAction.values.firstWhere(
        (a) => a.name == item['action'],
      );
      final table = item['table'] as String;
      final data = item['data'] as Map<String, dynamic>?;
      final filters = Map<String, String>.from(item['filters'] as Map? ?? {});

      ApiResponse result;
      switch (action) {
        case OfflineAction.create:
          result = await ApiClient.post(table, data ?? {});
          break;
        case OfflineAction.update:
          result = await ApiClient.patchByFilter(
            table,
            filters: filters,
            body: data ?? {},
          );
          break;
        case OfflineAction.delete:
          if (filters.isNotEmpty) {
            result = await ApiClient.batchDeleteByFilter(table, filters: filters);
          } else {
            return true; // 无过滤条件的删除无法安全执行
          }
          break;
      }
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }

  /// 从 SharedPreferences 加载队列
  Future<List<Map<String, dynamic>>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_queueKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('解析离线队列失败: $e');
      }
      return [];
    }
  }

  /// 保存队列到 SharedPreferences
  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(queue));
  }
}
