/// Annotation to generate a Riverpod provider for an Orchestrator.
///
/// When applied to a class extending `OrchestratorNotifier`, the generator
/// creates a provider with automatic disposal handling.
///
/// ## Example
///
/// ```dart
/// @OrchestratorProvider()
/// class NestOrchestrator extends OrchestratorNotifier<NestState> {
///   NestOrchestrator() : super(NestState.initial());
///
///   void loadNests() {
///     dispatch(FetchNestsJob());
///   }
/// }
/// ```
///
/// Generates:
/// ```dart
/// final nestOrchestratorProvider = NotifierProvider<NestOrchestrator, NestState>(
///   NestOrchestrator.new,
/// );
/// ```
///
/// ## With Ref Access
///
/// ```dart
/// @OrchestratorProvider(withRef: true)
/// class UserOrchestrator extends OrchestratorNotifier<UserState> {
///   late final UserRepository _repo;
///
///   @override
///   UserState build() {
///     _repo = ref.watch(userRepositoryProvider);
///     return UserState.initial();
///   }
/// }
/// ```
///
/// Generates the same provider, but assumes your orchestrator uses `ref` internally.
///
/// ## Auto-Dispose
///
/// By default, providers are NOT auto-disposed (keeping state across navigation).
/// Set `autoDispose: true` for screens that should reset state when left:
///
/// ```dart
/// @OrchestratorProvider(autoDispose: true)
/// class CheckoutOrchestrator extends OrchestratorNotifier<CheckoutState> { ... }
/// ```
///
/// Generates:
/// ```dart
/// final checkoutOrchestratorProvider = NotifierProvider.autoDispose<...>(...);
/// ```
class OrchestratorProvider {
  /// Whether to generate an auto-dispose provider.
  /// When true, the orchestrator state is cleared when no longer watched.
  final bool autoDispose;

  /// Custom provider name. If not specified, uses camelCase of class name + 'Provider'.
  final String? name;

  /// Whether the orchestrator needs access to Ref.
  /// This is informational only - the generator always creates a Notifier provider.
  final bool withRef;

  const OrchestratorProvider({
    this.autoDispose = false,
    this.name,
    this.withRef = false,
  });
}
