import 'package:mobile_app/features/auth/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required String id,
    required String username,
    required String mobileNumber,
    String? interests,
    String? educationalField,
    String? educationalLevel,
    required DateTime createdAt,
  }) : super(
          id: id,
          username: username,
          mobileNumber: mobileNumber,
          interests: interests,
          educationalField: educationalField,
          educationalLevel: educationalLevel,
          createdAt: createdAt,
        );

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      mobileNumber: json['mobile_number'] as String,
      interests: json['interests'] as String?,
      educationalField: json['educational_field'] as String?,
      educationalLevel: json['educational_level'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'mobile_number': mobileNumber,
      'interests': interests,
      'educational_field': educationalField,
      'educational_level': educationalLevel,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
