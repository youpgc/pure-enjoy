import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import 'version_check_service.dart';

/// 更新对话框组件
///
/// 从 [VersionCheckService] 抽取为独立文件，降低 services 层单文件体积。
/// 行为与原内联实现完全一致。
class UpdateDialog extends StatefulWidget {
  final String version;
  final String releaseNotes;
  final bool isForceUpdate;
  final String? apkUrl;
  final String? fallbackUrl;
  final VersionCheckService versionService;

  const UpdateDialog({
    super.key,
    required this.version,
    required this.releaseNotes,
    required this.isForceUpdate,
    required this.apkUrl,
    this.fallbackUrl,
    required this.versionService,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    widget.versionService.downloadProgress.addListener(_onProgressChanged);
    widget.versionService.downloadStatus.addListener(_onStatusChanged);
  }

  @override
  void dispose() {
    widget.versionService.downloadProgress.removeListener(_onProgressChanged);
    widget.versionService.downloadStatus.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    if (mounted) {
      setState(() {
        _progress = widget.versionService.downloadProgress.value;
      });
    }
  }

  void _onStatusChanged() {
    if (mounted) {
      setState(() {
        _statusText = widget.versionService.downloadStatus.value;
      });
    }
  }

  Future<void> _startUpdate() async {
    if (widget.apkUrl == null || widget.apkUrl!.isEmpty) {
      if (mounted) {
        showSnackBar(context, '下载地址无效，请稍后重试');
      }
      return;
    }

    setState(() => _isDownloading = true);

    await widget.versionService.downloadAndInstall(
      context,
      widget.apkUrl!,
      fallbackUrl: widget.fallbackUrl,
    );

    if (mounted) {
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isForceUpdate && !_isDownloading,
      child: AlertDialog(
        title: Text(widget.isForceUpdate ? '🔒 强制更新' : '📦 发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最新版本: v${widget.version}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (widget.releaseNotes.isNotEmpty) ...[
              const Text(
                '更新内容:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(
                    widget.releaseNotes,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.isForceUpdate)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '此版本为强制更新，必须更新后才能继续使用。',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _statusText,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.isForceUpdate && !_isDownloading)
            TextButton(
              onPressed: () {
                widget.versionService.dismissVersion(widget.version);
                Navigator.pop(context);
              },
              child: const Text('稍后更新'),
            ),
          FilledButton(
            onPressed: _isDownloading ? null : _startUpdate,
            child: Text(_isDownloading ? '下载中...' : '立即更新'),
          ),
        ],
      ),
    );
  }
}
