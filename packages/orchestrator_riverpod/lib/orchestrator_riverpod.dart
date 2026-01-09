/// Riverpod integration for orchestrator_core framework.
///
/// This package provides seamless integration between the Event-Driven
/// Orchestrator pattern and Flutter's Riverpod ecosystem.
///
/// ## Key Classes
///
/// ### Synchronous Notifiers
/// - [OrchestratorNotifier]: Extends Riverpod Notifier with orchestration capabilities
/// - [OrchestratorFamilyNotifier]: Extends Riverpod FamilyNotifier for per-argument state
///
/// ### Asynchronous Notifiers
/// - [OrchestratorAsyncNotifier]: Extends Riverpod AsyncNotifier for async-first patterns
/// - [OrchestratorFamilyAsyncNotifier]: Extends Riverpod FamilyAsyncNotifier for per-argument async state
///
/// ## Usage
///
/// All notifiers provide:
/// - `dispatch<T>(job)` returns `JobHandle<T>` for both fire-and-forget and await patterns
/// - `onEvent(event)` unified event handler for domain events
/// - `isJobRunning(id)` to check if a job is active
///
/// ```dart
/// class UserNotifier extends OrchestratorNotifier<UserState> {
///   @override
///   UserState buildState() => const UserState();
///
///   // Fire-and-forget
///   void loadUsers() {
///     dispatch<List<User>>(LoadUsersJob());
///   }
///
///   // Await result
///   Future<User?> createUser(String name) async {
///     final handle = dispatch<User>(CreateUserJob(name: name));
///     final result = await handle.future;
///     return result.data;
///   }
///
///   @override
///   void onEvent(BaseEvent event) {
///     switch (event) {
///       case UsersLoadedEvent e:
///         state = state.copyWith(users: e.users);
///     }
///   }
/// }
/// ```
library;

export 'package:orchestrator_core/orchestrator_core.dart';

export 'src/orchestrator_async_notifier.dart';
export 'src/orchestrator_family_async_notifier.dart';
export 'src/orchestrator_family_notifier.dart';
export 'src/orchestrator_notifier.dart';
