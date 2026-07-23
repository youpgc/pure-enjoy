import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

/// 头像裁剪页
///
/// 遵循主流应用（微信 / WhatsApp / Instagram / Telegram）的通用范式：
/// 1. 强制 1:1 方形画布（`aspectRatio: 1`）；
/// 2. 圆形遮罩预览（`withCircleUi: true`），用户所见即最终圆形效果；
/// 3. 双指缩放 + 拖动定位，框选“安全区”内的主体；
/// 4. 输出高清圆形 PNG（`cropCircle()`），显示端再裁成圆，边缘清晰。
///
/// 通过 [Navigator.pop] 返回裁切后的图片字节（[Uint8List]）；用户取消时返回 `null`。
class AvatarCropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const AvatarCropScreen({super.key, required this.imageBytes});

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final CropController _controller = CropController();
  bool _isCropping = false;

  void _onCropped(CropResult result) {
    if (result is CropSuccess) {
      // 圆形裁切结果（PNG 字节），直接上传
      Navigator.of(context).pop<Uint8List?>(result.croppedImage);
    } else {
      Navigator.of(context).pop<Uint8List?>(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop<Uint8List?>(null),
        ),
        title: const Text('调整头像'),
        actions: [
          TextButton(
            onPressed: _isCropping
                ? null
                : () {
                    setState(() => _isCropping = true);
                    // 圆形导出，匹配“我的”页圆形展示
                    _controller.cropCircle();
                  },
            child: _isCropping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '完成',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              controller: _controller,
              image: widget.imageBytes,
              aspectRatio: 1,
              withCircleUi: true,
              onCropped: _onCropped,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Center(
              child: Text(
                '双指缩放、拖动图片以调整位置',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
