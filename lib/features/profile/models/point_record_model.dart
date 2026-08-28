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

}
