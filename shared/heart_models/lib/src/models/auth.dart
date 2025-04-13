import 'dart:typed_data';

import 'misc.dart';

abstract interface class User implements Model {
  String? get displayName;

  String? get email;

  String get id;

  DateTime? get createdAt;

  DateTime? get scheduledForDeletionAt;

  String? remoteAvatar;

  Uint8List? localAvatar;

  factory User({
    String? displayName,
    String? email,
    String? avatar,
    required String id,
    DateTime? createdAt,
    DateTime? scheduledForDeletionAt,
  }) {
    return _User(
      displayName: displayName,
      email: email,
      remoteAvatar: avatar,
      id: id,
      createdAt: createdAt,
      scheduledForDeletionAt: scheduledForDeletionAt,
    );
  }

  User copyWith({String? displayName, String? email});

  factory User.fromJson(Map json) {
    return User(
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
      id: json['id'] as String,
      createdAt: switch (json['createdAt']) {
        int epoch => DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true),
        String s => DateTime.tryParse(s),
        _ => null,
      },
      scheduledForDeletionAt: switch (json['scheduledForDeletionAt']) {
        int epoch => DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true),
        String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }
}

class _User implements User {
  @override
  final String? displayName;
  @override
  final String? email;
  @override
  String? remoteAvatar;
  @override
  final String id;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? scheduledForDeletionAt;
  @override
  Uint8List? localAvatar;

  _User({
    required this.displayName,
    required this.email,
    required this.remoteAvatar,
    required this.id,
    required this.createdAt,
    this.scheduledForDeletionAt,
  });

  @override
  String toString() {
    return displayName ?? email ?? 'User $id';
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
      if (remoteAvatar != null) 'avatar': remoteAvatar,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  User copyWith({String? displayName, String? email}) {
    return _User(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      remoteAvatar: remoteAvatar,
      id: id,
      createdAt: createdAt,
    );
  }
}
