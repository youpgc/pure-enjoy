import 'package:flutter/material.dart';

/// 积分类型信息
class PointTypeInfo {
  final IconData icon;
  final String label;
  final Color color;

  PointTypeInfo({
    required this.icon,
    required this.label,
    required this.color,
  });
}

/// 过期状态信息
class ExpiryInfo {
  final String label;
  final Color color;

  ExpiryInfo({
    required this.label,
    required this.color,
  });
}
