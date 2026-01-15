class UserModel {
  final String uid;
  final String name;
  final String email;
  final int points;
  final int totalEarnings;
  final int todayEarning;
  final int spinsToday;
  final DateTime? lastSpinDate;
  final DateTime? lastLoginDate;
  final String upiId;
  final String myReferralCode;
  final String? referredBy;
  final bool referralUsed;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.points = 0,
    this.totalEarnings = 0,
    this.todayEarning = 0,
    this.spinsToday = 0,
    this.lastSpinDate,
    this.lastLoginDate,
    this.upiId = '',
    required this.myReferralCode,
    this.referredBy,
    this.referralUsed = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'points': points,
      'totalEarnings': totalEarnings,
      'todayEarning': todayEarning,
      'spinsToday': spinsToday,
      'lastSpinDate': lastSpinDate?.toIso8601String(),
      'lastLoginDate': lastLoginDate?.toIso8601String(),
      'upiId': upiId,
      'myReferralCode': myReferralCode,
      'referredBy': referredBy,
      'referralUsed': referralUsed,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      points: map['points'] ?? 0,
      totalEarnings: map['totalEarnings'] ?? 0,
      todayEarning: map['todayEarning'] ?? 0,
      spinsToday: map['spinsToday'] ?? 0,
      lastSpinDate: map['lastSpinDate'] != null
          ? DateTime.parse(map['lastSpinDate'])
          : null,
      lastLoginDate: map['lastLoginDate'] != null
          ? DateTime.parse(map['lastLoginDate'])
          : null,
      upiId: map['upiId'] ?? '',
      myReferralCode: map['myReferralCode'] ?? '',
      referredBy: map['referredBy'],
      referralUsed: map['referralUsed'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    int? points,
    int? totalEarnings,
    int? todayEarning,
    int? spinsToday,
    DateTime? lastSpinDate,
    DateTime? lastLoginDate,
    String? upiId,
    String? myReferralCode,
    String? referredBy,
    bool? referralUsed,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      points: points ?? this.points,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      todayEarning: todayEarning ?? this.todayEarning,
      spinsToday: spinsToday ?? this.spinsToday,
      lastSpinDate: lastSpinDate ?? this.lastSpinDate,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      upiId: upiId ?? this.upiId,
      myReferralCode: myReferralCode ?? this.myReferralCode,
      referredBy: referredBy ?? this.referredBy,
      referralUsed: referralUsed ?? this.referralUsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
