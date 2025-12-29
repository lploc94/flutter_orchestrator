// lib/jobs/user_jobs.dart
// Test file for @TypedJob code generation

import 'package:orchestrator_core/orchestrator_core.dart';

part 'user_jobs.g.dart';

/// Interface that defines all User-related jobs.
/// The generator will create:
/// - sealed class UserJob extends BaseJob
/// - class FetchUserJob extends UserJob
/// - class UpdateUserJob extends UserJob
/// - class DeleteUserJob extends UserJob
@TypedJob(idPrefix: 'user')
abstract class UserJobInterface {
  /// Fetch a user by ID
  Future<void> fetchUser(String userId);

  /// Update a user's profile
  Future<void> updateUser({
    required String userId,
    required String name,
    String? email,
  });

  /// Delete a user
  Future<void> deleteUser(String userId);
}
