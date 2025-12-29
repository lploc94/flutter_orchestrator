# Typed Job Patterns

This guide covers patterns for creating type-safe job hierarchies in Dart 3+.

---

## 1. The Problem

In a per-feature architecture, you often have multiple related jobs:

```dart
// Without structure - hard to know which jobs belong together
class FetchUserJob extends BaseJob { ... }
class UpdateUserJob extends BaseJob { ... }
class DeleteUserJob extends BaseJob { ... }
class FetchOrderJob extends BaseJob { ... }
class CreateOrderJob extends BaseJob { ... }
```

Questions arise:
- Which jobs belong to the User feature?
- How do I handle all user jobs in one executor?
- How do I filter passive events by job "family"?

---

## 2. Sealed Classes (Recommended for Dart 3+)

Dart 3's `sealed` classes provide compile-time exhaustive checking:

```dart
// jobs/user_jobs.dart
sealed class UserJob extends BaseJob {
  UserJob({required super.id});
}

class FetchUserJob extends UserJob {
  final String userId;

  FetchUserJob(this.userId)
      : super(id: generateJobId('fetch_user'));
}

class UpdateUserJob extends UserJob {
  final String userId;
  final String name;
  final String? email;

  UpdateUserJob({
    required this.userId,
    required this.name,
    this.email,
  }) : super(id: generateJobId('update_user'));
}

class DeleteUserJob extends UserJob {
  final String userId;

  DeleteUserJob(this.userId)
      : super(id: generateJobId('delete_user'));
}
```

### Unified Executor

Handle all sealed subtypes in one executor with exhaustive pattern matching:

```dart
class UserExecutor extends BaseExecutor<UserJob> {
  final UserRepository _repo;

  UserExecutor(this._repo);

  @override
  Future<dynamic> process(UserJob job) async {
    // Exhaustive switch - compiler ensures all cases handled
    return switch (job) {
      FetchUserJob(:final userId) => await _repo.getById(userId),
      UpdateUserJob(:final userId, :final name, :final email) =>
          await _repo.update(userId, name, email),
      DeleteUserJob(:final userId) => await _repo.delete(userId),
    };
  }
}
```

### Passive Event Filtering

Filter events by the sealed parent type:

```dart
@override
void onPassiveEvent(BaseEvent event) {
  if (event is JobSuccessEvent) {
    // Check if it's any UserJob
    if (event.jobType?.startsWith('FetchUserJob') == true ||
        event.jobType?.startsWith('UpdateUserJob') == true ||
        event.jobType?.startsWith('DeleteUserJob') == true) {
      // Handle any user job completion
      refreshUserList();
    }
  }
}
```

Or use `isFromJobType<T>()` for specific types:

```dart
if (event.isFromJobType<UpdateUserJob>()) {
  // User was updated
  refreshUserDisplay();
}
```

---

## 3. Abstract Class Pattern (Pre-Dart 3)

For Dart 2.x or when you don't need exhaustive checking:

```dart
abstract class OrderJob extends BaseJob {
  OrderJob({required super.id});
}

class FetchOrdersJob extends OrderJob {
  final String? status;
  FetchOrdersJob({this.status}) : super(id: generateJobId('fetch_orders'));
}

class CreateOrderJob extends OrderJob {
  final List<String> productIds;
  CreateOrderJob(this.productIds) : super(id: generateJobId('create_order'));
}
```

### Type Checking in Executor

```dart
class OrderExecutor extends BaseExecutor<OrderJob> {
  @override
  Future<dynamic> process(OrderJob job) async {
    if (job is FetchOrdersJob) {
      return await _fetchOrders(job.status);
    } else if (job is CreateOrderJob) {
      return await _createOrder(job.productIds);
    }
    throw UnimplementedError('Unknown order job: ${job.runtimeType}');
  }
}
```

---

## 4. Single Job with Typed Params

For simpler cases, use a single job with sealed params:

```dart
class CartJob extends BaseJob {
  final CartAction action;

  CartJob(this.action) : super(id: generateJobId('cart'));
}

sealed class CartAction {}

class AddToCart extends CartAction {
  final String productId;
  final int quantity;
  AddToCart(this.productId, {this.quantity = 1});
}

class RemoveFromCart extends CartAction {
  final String productId;
  RemoveFromCart(this.productId);
}

class ClearCart extends CartAction {}
```

### Executor with Action Pattern Matching

```dart
class CartExecutor extends BaseExecutor<CartJob> {
  @override
  Future<dynamic> process(CartJob job) async {
    return switch (job.action) {
      AddToCart(:final productId, :final quantity) =>
          await _addToCart(productId, quantity),
      RemoveFromCart(:final productId) =>
          await _removeFromCart(productId),
      ClearCart() =>
          await _clearCart(),
    };
  }
}
```

---

## 5. Comparison

| Pattern | Pros | Cons |
|---------|------|------|
| Sealed Classes | Exhaustive checking, clear hierarchy | Requires Dart 3+, more boilerplate |
| Abstract Class | Simple, works everywhere | No exhaustive checking |
| Typed Params | Fewer job classes, flexible | Less discoverable, action buried |

### Recommendations

- **Sealed Classes**: Best for feature modules with 3+ related jobs
- **Abstract Class**: Good for backward compatibility or simple hierarchies
- **Typed Params**: Best for jobs with many similar operations (CRUD)

---

## 6. Complete Example

```dart
// features/product/product_jobs.dart
sealed class ProductJob extends BaseJob {
  ProductJob({required super.id});
}

class FetchProductsJob extends ProductJob {
  final String? categoryId;
  final int page;

  FetchProductsJob({
    this.categoryId,
    this.page = 1,
  }) : super(id: generateJobId('fetch_products'));
}

class FetchProductDetailJob extends ProductJob {
  final String productId;

  FetchProductDetailJob(this.productId)
      : super(id: generateJobId('fetch_product_detail'));
}

class SearchProductsJob extends ProductJob {
  final String query;
  final int page;

  SearchProductsJob(this.query, {this.page = 1})
      : super(id: generateJobId('search_products'));
}

// features/product/product_executor.dart
class ProductExecutor extends TypedExecutor<ProductJob, ProductResult> {
  final ProductRepository _repo;

  ProductExecutor(this._repo);

  @override
  Future<ProductResult> run(ProductJob job) async {
    return switch (job) {
      FetchProductsJob(:final categoryId, :final page) =>
          ProductListResult(await _repo.list(categoryId: categoryId, page: page)),
      FetchProductDetailJob(:final productId) =>
          ProductDetailResult(await _repo.getById(productId)),
      SearchProductsJob(:final query, :final page) =>
          ProductListResult(await _repo.search(query, page: page)),
    };
  }
}

// Result types
sealed class ProductResult {}
class ProductListResult extends ProductResult {
  final List<Product> products;
  ProductListResult(this.products);
}
class ProductDetailResult extends ProductResult {
  final Product product;
  ProductDetailResult(this.product);
}

// features/product/product_orchestrator.dart
class ProductCubit extends OrchestratorCubit<ProductState> {
  ProductCubit() : super(ProductState.initial());

  void loadProducts({String? categoryId}) {
    emit(state.copyWith(isLoading: true));
    dispatch(FetchProductsJob(categoryId: categoryId));
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    final result = event.data;
    if (result is ProductListResult) {
      emit(state.copyWith(products: result.products, isLoading: false));
    } else if (result is ProductDetailResult) {
      emit(state.copyWith(selectedProduct: result.product, isLoading: false));
    }
  }
}
```

---

## See Also

- [Per-Feature Orchestrators](./per-feature-orchestrators.md)
- [Executor Concepts](../concepts/executor.md)
- [Job Concepts](../concepts/job.md)
