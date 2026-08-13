import 'user_profile.dart';

abstract class AuthRepository {
  Future<UserProfile> login({required String email, required String password});
  Future<UserProfile> me();
  Future<void> logout();
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  });
}
