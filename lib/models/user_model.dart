/// Minimal user model — only fields the app reliably reads. Unknown fields are
/// preserved in [raw] so nothing is lost when the backend adds properties.
class UserModel {
  const UserModel({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.gender,
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? gender;
  final Map<String, dynamic> raw;

  /// True once the backend has stamped `email_verified_at`.
  bool get isEmailVerified =>
      (raw['email_verified_at']?.toString() ?? '').isNotEmpty &&
      raw['email_verified_at'] != 'null';

  String get fullName =>
      <String?>[firstName, lastName].where((String? s) => (s ?? '').isNotEmpty).join(' ').trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _asInt(json['id']),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      gender: json['gender']?.toString(),
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'phone': phone,
    'gender': gender,
  };

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
}
