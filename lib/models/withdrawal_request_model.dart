class WithdrawalRequestModel {
  final String id;
  final String uid;
  final String upiId;
  final int amount;
  final int pointsUsed;
  final String status; // pending | approved | rejected | paid
  final DateTime requestedAt;

  WithdrawalRequestModel({
    required this.id,
    required this.uid,
    required this.upiId,
    required this.amount,
    required this.pointsUsed,
    this.status = 'pending',
    required this.requestedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'upiId': upiId,
      'amount': amount,
      'pointsUsed': pointsUsed,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
    };
  }

  factory WithdrawalRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return WithdrawalRequestModel(
      id: id,
      uid: map['uid'] ?? '',
      upiId: map['upiId'] ?? '',
      amount: map['amount'] ?? 0,
      pointsUsed: map['pointsUsed'] ?? 0,
      status: map['status'] ?? 'pending',
      requestedAt: map['requestedAt'] != null
          ? DateTime.parse(map['requestedAt'])
          : DateTime.now(),
    );
  }
}
