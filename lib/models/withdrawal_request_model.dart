import 'package:cloud_firestore/cloud_firestore.dart';

class WithdrawalRequest {
  final String id;
  final String userId;
  final String userName;
  final int coins;
  final double amountInRupees;
  final String? mobileNumber;
  final String? upiId;
  final String status; // pending, approved, rejected
  final DateTime createdAt;

  WithdrawalRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.coins,
    required this.amountInRupees,
    this.mobileNumber,
    this.upiId,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'coins': coins,
      'amountInRupees': amountInRupees,
      'mobileNumber': mobileNumber,
      'upiId': upiId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory WithdrawalRequest.fromMap(Map<String, dynamic> map, String docId) {
    return WithdrawalRequest(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'User',
      coins: map['coins']?.toInt() ?? 0,
      amountInRupees: map['amountInRupees']?.toDouble() ?? 0.0,
      mobileNumber: map['mobileNumber'],
      upiId: map['upiId'],
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
