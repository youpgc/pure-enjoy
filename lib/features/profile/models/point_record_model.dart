class PointRecord {
  final String id;
  final String userId;
  final String type; // checkin, earn, spend, adjust, admin_adjust
  final int amount;
  final String? remark;
  final String? operatorName;
  final String? operatorId;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String status; // active, expired

  PointRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.remark,
    this.operatorName,
    this.operatorId,
    this.createdAt,
    this.expiresAt,
    this.status = 'active',
  });

  factory PointRecord.fromJson(Map<String, dynamic> json) {
    return PointRecord(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      type: json['type'] ?? '',
      amount: json['amount'] ?? 0,
      remark: json['remark'],
      operatorName: json['operator_name'],
      operatorId: json['operator_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'amount': amount,
      'remark': remark,
      'operator_name': operatorName,
      'operator_id': operatorId,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'status': status,
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'amount': amount,
      'remark': remark,
      'status': status,
    };
  }

  PointRecord copyWith({
    String? id,
    String? userId,
    String? type,
    int? amount,
    String? remark,
    String? operatorName,
    String? operatorId,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? status,
  }) {
    return PointRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      remark: remark ?? this.remark,
      operatorName: operatorName ?? this.operatorName,
      operatorId: operatorId ?? this.operatorId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }
}
