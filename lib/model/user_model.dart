import 'dart:convert';

import 'package:flutter/foundation.dart';

// ignore_for_file: public_member_api_docs, sort_constructors_first
class UserModel {
  String email;
  String id;
  List<dynamic>? friendsList;
  UserModel({
    required this.email,
    required this.id,
    this.friendsList,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'email': email,
      'id': id,
      'friendsList': friendsList,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
        email: map['email'] as String,
        id: map['id'] as String,
        friendsList: map['friendsList'] != null
            ? List<dynamic>.from(
                (map['friendsList'] as List<dynamic>),
              )
            : null);
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'UserModel(email: $email, id: $id, friendsList: $friendsList)';

  UserModel copyWith({
    String? email,
    String? id,
    List<dynamic>? friendsList,
  }) {
    return UserModel(
      email: email ?? this.email,
      id: id ?? this.id,
      friendsList: friendsList ?? this.friendsList,
    );
  }

  @override
  bool operator ==(covariant UserModel other) {
    if (identical(this, other)) return true;

    return other.email == email &&
        other.id == id &&
        listEquals(other.friendsList, friendsList);
  }

  @override
  int get hashCode => email.hashCode ^ id.hashCode ^ friendsList.hashCode;
}
