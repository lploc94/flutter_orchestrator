# Per-Feature Orchestrators

This guide explains how to structure your Flutter application with one orchestrator per feature, a common pattern in larger applications.

---

## 1. Overview

In medium-to-large apps, a single orchestrator managing all state becomes unwieldy. The **per-feature orchestrator** pattern creates one orchestrator per domain area (feature).

```
my_app/
├── main.dart                    # Register all executors
├── features/
│   ├── auth/
│   │   ├── auth_orchestrator.dart
│   │   ├── auth_jobs.dart
│   │   └── auth_executor.dart
│   ├── profile/
│   │   ├── profile_orchestrator.dart
│   │   ├── profile_jobs.dart
│   │   └── profile_executor.dart
│   └── settings/
│       ├── settings_orchestrator.dart
│       └── ...
```

---

## 2. Dispatcher is a Singleton

All orchestrators automatically share the same `Dispatcher` instance. This is by design:

```dart
// In AuthOrchestrator
dispatch(LoginJob(email, password));  // Goes to shared Dispatcher

// In ProfileOrchestrator
dispatch(FetchProfileJob(userId));    // Same Dispatcher routes to correct Executor
```

### Central Executor Registration

Register all executors once at app startup:

```dart
// main.dart
void main() {
  // Dispatcher is a singleton - all orchestrators share this
  final dispatcher = Dispatcher();

  // Register all executors
  dispatcher.register(AuthExecutor(authService));
  dispatcher.register(ProfileExecutor(profileService));
  dispatcher.register(SettingsExecutor(settingsService));

  runApp(MyApp());
}
```

---

## 3. Cross-Feature Communication

Features often need to react to each other. The **passive event system** handles this elegantly.

### Active vs Passive Events

- **Active Events**: Events from jobs THIS orchestrator dispatched
- **Passive Events**: Events from jobs OTHER orchestrators dispatched

```dart
class ProfileOrchestrator extends OrchestratorCubit<ProfileState> {
  ProfileOrchestrator() : super(ProfileState.initial());

  void fetchProfile() {
    dispatch(FetchProfileJob(userId));  // Active job
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    // Handle success from jobs we dispatched
    if (event.dataAs<User>() != null) {
      emit(state.copyWith(user: event.data));
    }
  }

  @override
  void onPassiveEvent(BaseEvent event) {
    // React to events from OTHER orchestrators
    if (event is JobSuccessEvent && event.isFromJobType<LoginJob>()) {
      // User logged in from AuthOrchestrator → refresh profile
      fetchProfile();
    }

    if (event is JobSuccessEvent && event.isFromJobType<UpdateSettingsJob>()) {
      // Settings changed → might affect profile display
      emit(state.copyWith(needsRefresh: true));
    }
  }
}
```

### Using jobType for Filtering

Since v0.5.0, all result events include `jobType` for type-safe filtering:

```dart
@override
void onPassiveEvent(BaseEvent event) {
  if (event is JobSuccessEvent) {
    // Type-safe filtering with isFromJobType<T>()
    if (event.isFromJobType<LogoutJob>()) {
      emit(ProfileState.initial());  // Clear profile on logout
    }
  }
}
```

---

## 4. State Management Integration

### BLoC/Cubit

```dart
class AuthCubit extends OrchestratorCubit<AuthState> {
  AuthCubit() : super(AuthState.unauthenticated());

  void login(String email, String password) {
    emit(state.copyWith(status: AuthStatus.loading));
    dispatch(LoginJob(email, password));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    final user = event.dataAs<User>();
    if (user != null) {
      emit(AuthState.authenticated(user));
    }
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    emit(AuthState.error(event.error.toString()));
  }
}
```

### Provider

```dart
class ProfileNotifier extends OrchestratorNotifier<ProfileState> {
  ProfileNotifier() : super(ProfileState.initial());

  void loadProfile(String userId) {
    state = state.copyWith(isLoading: true);
    dispatch(FetchProfileJob(userId));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    state = state.copyWith(
      isLoading: false,
      profile: event.data,
    );
  }
}
```

### Riverpod

```dart
class SettingsNotifier extends OrchestratorNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState.defaults());

  void updateTheme(ThemeMode mode) {
    dispatch(UpdateThemeJob(mode));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    state = state.copyWith(theme: event.data);
  }
}

// Provider definition
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
```

---

## 5. Feature Module Pattern

For larger apps, consider encapsulating each feature as a module:

```dart
// features/auth/auth_module.dart
class AuthModule {
  static void register(Dispatcher dispatcher) {
    dispatcher.register(AuthExecutor(
      AuthService(),
      TokenStorage(),
    ));
  }
}

// features/profile/profile_module.dart
class ProfileModule {
  static void register(Dispatcher dispatcher) {
    dispatcher.register(ProfileExecutor(
      ProfileService(),
    ));
  }
}

// main.dart
void main() {
  final dispatcher = Dispatcher();

  AuthModule.register(dispatcher);
  ProfileModule.register(dispatcher);
  SettingsModule.register(dispatcher);

  runApp(MyApp());
}
```

---

## 6. Testing Per-Feature Orchestrators

Each orchestrator can be tested in isolation:

```dart
void main() {
  group('ProfileOrchestrator', () {
    late MockDispatcher mockDispatcher;
    late SignalBus scopedBus;
    late ProfileOrchestrator orchestrator;

    setUp(() {
      mockDispatcher = MockDispatcher();
      scopedBus = SignalBus.scoped();

      when(() => mockDispatcher.dispatch(any())).thenReturn('job-id');

      orchestrator = ProfileOrchestrator(
        bus: scopedBus,
        dispatcher: mockDispatcher,
      );
    });

    tearDown(() {
      orchestrator.dispose();
      scopedBus.dispose();
    });

    test('dispatches FetchProfileJob on loadProfile', () {
      orchestrator.loadProfile('user-123');

      verify(() => mockDispatcher.dispatch(
        any(that: isA<FetchProfileJob>()),
      )).called(1);
    });

    test('reacts to LoginJob from other orchestrator', () async {
      // Simulate passive event (from AuthOrchestrator)
      scopedBus.emit(JobSuccessEvent(
        'auth-job-id',
        User(id: 'user-123'),
        jobType: 'LoginJob',
      ));

      await Future.delayed(Duration(milliseconds: 50));

      // Verify profile refresh was triggered
      verify(() => mockDispatcher.dispatch(
        any(that: isA<FetchProfileJob>()),
      )).called(1);
    });
  });
}
```

---

## 7. Best Practices

### ✅ Do

- **One Orchestrator per Feature**: Keep orchestrators focused on a single domain
- **Register Executors Centrally**: All executors at app startup for clarity
- **Use Passive Events for Cross-Feature**: Don't pass orchestrator references around
- **Filter by jobType**: Use `isFromJobType<T>()` for type-safe filtering
- **Inject Dependencies for Testing**: Pass `bus` and `dispatcher` in constructors

### ❌ Don't

- **Don't Create Dispatcher per Orchestrator**: It's a singleton by design
- **Don't Call Other Orchestrators Directly**: Use events instead
- **Don't Forget Passive Handlers**: Important events might come from other features

```dart
// ❌ WRONG: Direct orchestrator coupling
class ProfileOrchestrator {
  final AuthOrchestrator authOrchestrator;  // Tight coupling!

  void onUserLogin() {
    authOrchestrator.getUser();  // Don't do this
  }
}

// ✅ CORRECT: Loose coupling via events
class ProfileOrchestrator extends OrchestratorCubit<ProfileState> {
  @override
  void onPassiveEvent(BaseEvent event) {
    if (event is JobSuccessEvent && event.isFromJobType<LoginJob>()) {
      // React to login without knowing about AuthOrchestrator
      dispatch(FetchProfileJob(event.data.userId));
    }
  }
}
```

---

## 8. Example: Multi-Feature App

```dart
// features/cart/cart_orchestrator.dart
class CartOrchestrator extends OrchestratorCubit<CartState> {
  CartOrchestrator() : super(CartState.empty());

  void addItem(Product product) {
    dispatch(AddToCartJob(product));
  }

  @override
  void onPassiveEvent(BaseEvent event) {
    // Clear cart when user logs out
    if (event is JobSuccessEvent && event.isFromJobType<LogoutJob>()) {
      emit(CartState.empty());
    }

    // Update prices when settings change currency
    if (event is JobSuccessEvent && event.isFromJobType<UpdateCurrencyJob>()) {
      dispatch(RefreshCartPricesJob());
    }
  }
}
```

---

## See Also

- [Testing](./testing.md)
- [Orchestrator Concepts](../concepts/orchestrator.md)
- [Signal Bus](../concepts/signal_bus.md)
