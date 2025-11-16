
class UserProfile {
  final String name;
  final String gender;
  final String phone;
  final String language;
  final String status;

  UserProfile({
    required this.name,
    required this.gender,
    required this.phone,
    required this.language,
    this.status = 'new',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'],
        gender: json['gender'],
        phone: json['user_phone'],
        language: json['language'],
        status: json['status'] ?? 'new',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'gender': gender,
        'user_phone': phone,
        'language': language,
        'status': status,
      };

  UserProfile copyWith({String? status}) {
    return UserProfile(
      name: name,
      gender: gender,
      phone: phone,
      language: language,
      status: status ?? this.status,
    );
  }
}
