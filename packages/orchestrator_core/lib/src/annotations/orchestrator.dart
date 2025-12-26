/// Annotation to mark an Orchestrator class for code generation.
///
/// When applied to a class extending `BaseOrchestrator`, the generator
/// will scan for `@OnEvent` annotated methods and generate the event
/// routing logic automatically.
class Orchestrator {
  const Orchestrator();
}

/// Annotation to mark a method as an event handler.
///
/// The generator will create type-safe event routing in `onPassiveEvent`
/// or `onActiveEvent` based on the `passive` flag.
///
/// Example:
/// ```dart
/// @Orchestrator()
/// class AuthOrchestrator extends BaseOrchestrator<AuthState> {
///   @OnEvent(UserLoggedInEvent)
///   void _handleLogin(UserLoggedInEvent event) {
///     emit(state.copyWith(user: event.user));
///   }
///
///   @OnEvent(UserLoggedOutEvent, passive: true)
///   void _handleLogout(UserLoggedOutEvent event) {
///     emit(state.copyWith(user: null));
///   }
/// }
/// ```
class OnEvent<T> {
  /// The event type to handle.
  final Type eventType;

  /// If true, this handler will be called for passive events (from other orchestrators).
  /// If false (default), it handles active events (from jobs dispatched by this orchestrator).
  final bool passive;

  /// Priority for ordering multiple handlers (higher = earlier). Default: 0.
  final int priority;

  const OnEvent(this.eventType, {this.passive = false, this.priority = 0});
}
