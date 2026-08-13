import '../../../core/utils/json_helpers.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.organizationName,
    this.positionName,
    this.roleName,
    this.controlObjects = const [],
  });

  final int id;
  final String email;
  final String fullName;
  final String? organizationName;
  final String? positionName;
  final String? roleName;
  final List<String> controlObjects;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (parts.isEmpty) return 'U';
    String firstRune(String value) =>
        value.isEmpty ? '' : String.fromCharCodes(value.runes.take(1)).toUpperCase();
    final list = parts.toList();
    if (list.length == 1) return firstRune(list.first);
    return '${firstRune(list[0])}${firstRune(list[1])}';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final role = asMap(json['role']);
    final position = asMap(json['position']);
    return UserProfile(
      id: asInt(json['id']) ?? 0,
      email: asString(json['email']) ?? '',
      fullName: asString(json['fullName']) ?? '',
      organizationName: asString(json['organizationName']),
      positionName: asString(position['name']),
      roleName: asString(role['name']) ?? asString(json['role']),
      controlObjects: asList(json['controlObjects'])
          .map((item) => asString(asMap(item)['name']))
          .whereType<String>()
          .toList(),
    );
  }
}
