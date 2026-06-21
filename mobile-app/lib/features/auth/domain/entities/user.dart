import 'package:equatable/equatable.dart';

/// Clean Architecture core domain representation of a User.
class User extends Equatable {
  final String id;
  final String username;
  final String mobileNumber;
  final String? interests;
  final String? educationalField;
  final String? educationalLevel;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.username,
    required this.mobileNumber,
    this.interests,
    this.educationalField,
    this.educationalLevel,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        username,
        mobileNumber,
        interests,
        educationalField,
        educationalLevel,
        createdAt,
      ];
}
