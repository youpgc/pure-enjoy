/// 请求取消令牌
/// 用于在页面销毁时取消未完成的请求，防止旧响应覆盖新数据
///
/// 使用方式：
/// ```dart
/// final cancelToken = CancelToken();
/// // 在 dispose 中调用：
/// cancelToken.cancel();
/// // 在请求中传入：
/// ApiClient.get('table', cancelToken: cancelToken);
/// ```
class CancelToken {
  bool _isCancelled = false;

  /// 是否已取消
  bool get isCancelled => _isCancelled;

  /// 取消请求
  void cancel() {
    _isCancelled = true;
  }
}

/// 请求被取消异常
class RequestCancelledException implements Exception {
  @override
  String toString() => '请求已取消';
}
