class ReferralCodeModel {
  final String code;
  final String uid;
  final int reward;
  final List<String> usedBy;

  ReferralCodeModel({
    required this.code,
    required this.uid,
    this.reward = 2000,
    this.usedBy = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'reward': reward,
      'usedBy': usedBy,
    };
  }

  factory ReferralCodeModel.fromMap(String code, Map<String, dynamic> map) {
    return ReferralCodeModel(
      code: code,
      uid: map['uid'] ?? '',
      reward: map['reward'] ?? 2000,
      usedBy: List<String>.from(map['usedBy'] ?? []),
    );
  }
}
