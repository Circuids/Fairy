<div align="center">
  <img src="logo.png" alt="Fairy Logo" width="300"/>
</div>

A lightweight MVVM framework for Flutter with strongly-typed reactive data binding, commands, and dependency injection - no code generation required.

**Simplicity over complexity** - Clean APIs, minimal boilerplate, zero dependencies.

## 📖 Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Quick Reference](#quick-reference)
- [Common Patterns](#common-patterns)
- [Core Concepts](#core-concepts)
- [Dependency Injection](#dependency-injection)
- [Advanced Features](#advanced-features)
  - [Deep Equality for Collections](#deep-equality-for-collections)
  - [Custom Type Equality](#custom-type-equality)
  - [Command Error Handling](#command-error-handling)
- [Best Practices](#best-practices)
- [Performance](#performance)
- [Testing](#testing)
- [Documentation](#documentation)
- [Maintenance & Release Cadence](#maintenance--release-cadence)

## Features

- 🎓 **Few Widgets to Learn** - `Bind` for data, `Command` for actions
- 🎯 **Type-Safe** - Strongly-typed with compile-time safety
- ✨ **No Code Generation** - Runtime-only, no build_runner
- 🔄 **Auto UI Updates** - Data binding that just works
- ⚡ **Command Pattern** - Actions with `canExecute` validation and error handling
- 🏗️ **Dependency Injection** - Global and scoped DI
- 📦 **Lightweight** - Zero external dependencies

## Installation

```yaml
dependencies:
  fairy: ^2.0.0
```

## Quick Start

```dart
// 1. Create ViewModel
class CounterViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
  late final incrementCommand = RelayCommand(() => counter.value++);
}

// 2. Provide ViewModel with FairyScope (can be used anywhere in widget tree)
void main() => runApp(
  FairyScope(
    viewModel: (_) => CounterViewModel(),
    child: MyApp(),
  ),
);

// 3. Bind UI
Bind<CounterViewModel, int>(
  bind: (vm) => vm.counter,
  builder: (context, value, update) => Text('$value'),
)

Command<CounterViewModel>(
  command: (vm) => vm.incrementCommand,
  builder: (context, execute, canExecute, isRunning) =>
    ElevatedButton(
      onPressed: canExecute ? execute : null,
      child: Text('Increment'),
    ),
)
```

## Quick Reference

### Property Types

| Type | Purpose | Auto-Updates | Example |
|------|---------|--------------|---------|
| `ObservableProperty<T>` | Mutable reactive state | ✅ | `final name = ObservableProperty<String>('');` |
| `ComputedProperty<T>` | Derived/calculated values | ✅ | `late final total = ComputedProperty(() => price.value * qty.value, [price, qty], this);` |

### Command Types

| Type | Parameters | Async | Error Handling | Example |
|------|-----------|-------|----------------|---------|
| `RelayCommand` | ❌ | ❌ | ✅ | `late final save = RelayCommand(_save, onError: _handleError);` |
| `AsyncRelayCommand` | ❌ | ✅ | ✅ | `late final fetch = AsyncRelayCommand(_fetch, onError: _handleError);` |
| `RelayCommandWithParam<T>` | ✅ | ❌ | ✅ | `late final delete = RelayCommandWithParam<String>(_delete, onError: _handleError);` |
| `AsyncRelayCommandWithParam<T>` | ✅ | ✅ | ✅ | `late final upload = AsyncRelayCommandWithParam<File>(_upload, onError: _handleError);` |

**Async commands** automatically track `isRunning` and prevent concurrent execution.

**Error handling** is optional via `onError` callback - store errors in ViewModel properties and display with `Bind`.

### Widget Types

| Widget | Purpose | When to Use |
|--------|---------|-------------|
| `Bind<TViewModel, TValue>` | Single property binding | Best performance, one property |
| `Bind.viewModel<TViewModel>` | Multiple properties | Multiple properties, convenience |
| `Command<TViewModel>` | Bind commands | Buttons, actions |
| `Command.param<TViewModel, TParam>` | Parameterized commands | Delete item, update with value |

## Common Patterns

### Form with Validation

```dart
class LoginViewModel extends ObservableObject {
  final email = ObservableProperty<String>('');
  final password = ObservableProperty<String>('');
  final errorMessage = ObservableProperty<String?>(null);
  
  late final isValid = ComputedProperty<bool>(
    () => email.value.contains('@') && password.value.length >= 8,
    [email, password], this,
  );
  
  late final loginCommand = AsyncRelayCommand(
    _login,
    canExecute: () => isValid.value,
    onError: (error, stackTrace) {
      errorMessage.value = 'Login failed: $error';
    },
  );
  
  Future<void> _login() async {
    errorMessage.value = null; // Clear previous errors
    await authService.login(email.value, password.value);
  }
}
```

### List Operations

```dart
final todos = ObservableProperty<List<Todo>>([]);

late final addCommand = RelayCommandWithParam<String>(
  (title) => todos.value = [...todos.value, Todo(title)],
);

late final deleteCommand = RelayCommandWithParam<String>(
  (id) => todos.value = todos.value.where((t) => t.id != id).toList(),
);
```

### Loading States with Error Handling

```dart
class MyViewModel extends ObservableObject {
  final data = ObservableProperty<List<Item>>([]);
  final error = ObservableProperty<String?>(null);
  
  late final fetchCommand = AsyncRelayCommand(
    _fetch,
    onError: (e, _) => error.value = e.toString(),
  );
  
  Future<void> _fetch() async {
    error.value = null;
    data.value = await apiService.fetchData();
  }
}

// UI - Show loading, error, or data
Column(
  children: [
    Bind<MyViewModel, String?>(
      bind: (vm) => vm.error,
      builder: (context, error, _) {
        if (error != null) return ErrorCard(error);
        return SizedBox.shrink();
      },
    ),
    Command<MyViewModel>(
      command: (vm) => vm.fetchCommand,
      builder: (context, execute, canExecute, isRunning) {
        if (isRunning) return CircularProgressIndicator();
        return ElevatedButton(onPressed: execute, child: Text('Fetch'));
      },
    ),
  ],
)
```

### Dynamic canExecute

```dart
// ViewModel
final selected = ObservableProperty<Item?>(null);

late final deleteCommand = RelayCommand(_delete,
  canExecute: () => selected.value != null);

late final VoidCallback _disposeListener;

MyViewModel() {
  _disposeListener = selected.propertyChanged(() {
    deleteCommand.notifyCanExecuteChanged();
  });
}

@override
void dispose() {
  _disposeListener();
  super.dispose();
}

// UI - Command widget automatically respects canExecute
Command<MyViewModel>(
  command: (vm) => vm.deleteCommand,
  builder: (context, execute, canExecute, isRunning) =>
    ElevatedButton(
      onPressed: canExecute ? execute : null,  // Button disabled when canExecute is false
      child: Text('Delete'),
    ),
)
```

## Core Concepts

### Data Binding

**Single property (two-way):**
```dart
Bind<UserViewModel, String>(
  bind: (vm) => vm.name,  // Returns ObservableProperty - two-way binding
  builder: (context, value, update) => TextField(
    controller: TextEditingController(text: value),
    onChanged: update,  // update() available for two-way binding
  ),
)
```

**Single property (one-way):**
```dart
Bind<UserViewModel, String>(
  bind: (vm) => vm.name.value,  // Returns raw value - one-way binding
  builder: (context, value, update) => Text(value),  // No update needed
)
```

**Multiple properties:**
```dart
Bind.viewModel<UserViewModel>(
  builder: (context, vm) => Text('${vm.firstName.value} ${vm.lastName.value}'),
)
```

**Multiple ViewModels:** Use `Bind.viewModel2/3/4` to bind multiple ViewModels at once:
```dart
Bind.viewModel2<UserViewModel, SettingsViewModel>(
  builder: (context, user, settings) => 
    Text('${user.name.value} - ${settings.theme.value}'),
)
```

### ComputedProperty - Derived Values

```dart
final price = ObservableProperty<double>(10.0);
final qty = ObservableProperty<int>(2);

late final total = ComputedProperty<double>(
  () => price.value * qty.value,
  [price, qty], this,
);
// Automatically recalculates when price or qty changes
```

### Change Notification APIs

Fairy provides change notification at multiple levels. **Important:** Each observable type has its own isolated notification system.

| Type | `propertyChanged()` Scope | Auto-Notifies UI |
|------|---------------------------|------------------|
| `ObservableProperty<T>` | Only this property | ✅ On `.value` change |
| `ComputedProperty<T>` | Only this property | ✅ On dependency change |
| `ObservableObject` | Only vanilla fields | ❌ Must call `onPropertyChanged()` |

**Key insight:** `ObservableProperty` and `ComputedProperty` changes do **NOT** trigger `ObservableObject.propertyChanged()` listeners. Each type manages its own listeners independently - this enables Fairy's granular rebuild performance.

#### Subscribing to Changes

Use `propertyChanged(listener)` to subscribe. Returns a disposer function:

```dart
// Subscribe to ObservableProperty changes
final dispose = userName.propertyChanged(() {
  print('Name changed to: ${userName.value}');
  saveCommand.notifyCanExecuteChanged();  // Common pattern
});

// Subscribe to ComputedProperty changes
final dispose = fullName.propertyChanged(() {
  print('Full name updated: ${fullName.value}');
});

// Subscribe to ObservableObject (vanilla fields only!)
final dispose = viewModel.propertyChanged(() {
  // ⚠️ Only triggered by onPropertyChanged() calls
  // NOT triggered by ObservableProperty/ComputedProperty changes
  print('Vanilla field changed!');
});

// IMPORTANT: Always capture and call the disposer!
dispose();  // Clean up when done
```

#### Using Vanilla Fields with `onPropertyChanged()`

For plain Dart fields (not `ObservableProperty`), manually call `onPropertyChanged()`:

```dart
class UserViewModel extends ObservableObject {
  String _name = '';  // Vanilla field
  int _age = 0;       // Vanilla field
  
  String get name => _name;
  int get age => _age;
  
  void updateName(String value) {
    _name = value;
    onPropertyChanged();  // Manually notify listeners
  }
  
  // Batch updates - single notification
  void updateUser(String name, int age) {
    _name = name;
    _age = age;
    onPropertyChanged();  // One notification for both changes
  }
}
```

**When to use each approach:**

| Approach | Use Case |
|----------|----------|
| `ObservableProperty` | Default choice - automatic notifications |
| Vanilla fields + `onPropertyChanged()` | Batch updates, legacy migration |
| `property.propertyChanged()` | Cross-ViewModel sync, side effects |
| `viewModel.propertyChanged()` | Listen to vanilla field changes only |
- Use plain fields + `onPropertyChanged()` - for batch updates or legacy code migration
- Use `propertyChanged()` - for cross-ViewModel communication or triggering side effects

## Dependency Injection

### FairyScope - Widget-Scoped DI

**Key capabilities:**
- ✅ **Multiple scopes**: Use `FairyScope` multiple times in widget tree - each creates independent scope
- ✅ **Nestable**: Child scopes can access parent scope ViewModels via `Fairy.of<T>(context)`
- ✅ **Per-page ViewModels**: Ideal pattern - wrap each page/route with `FairyScope` for automatic lifecycle
- ✅ **Resolution order**: Searches nearest `FairyScope` first, then parent scopes, finally `FairyLocator`

```dart
// Single ViewModel per page (recommended pattern)
FairyScope(
  viewModel: (_) => ProfileViewModel(),
  child: ProfilePage(),
)

// Multiple ViewModels in one scope
FairyScope(
  viewModels: [
    (_) => UserViewModel(),
    (locator) => SettingsViewModel(
      userVM: locator.get<UserViewModel>(),
    ),
  ],
  child: DashboardPage(),
)

// Nested scopes - child can access parent ViewModels
FairyScope(
  viewModel: (_) => AppViewModel(),
  child: MaterialApp(
    home: FairyScope(
      viewModel: (_) => HomeViewModel(),
      child: HomePage(),  // Can access both HomeVM and AppVM
    ),
  ),
)

// Access in widgets
final vm = Fairy.of<UserViewModel>(context);
```

**Auto-disposal:** `autoDispose: true` (default) automatically disposes ViewModels when scope is removed from widget tree.

### FairyLocator - Global DI

```dart
// Register services in main()
void main() {
  FairyLocator.registerSingleton<ApiService>(ApiService());
  FairyLocator.registerLazySingleton<DbService>(() => DbService());
  runApp(MyApp());
}

// Use in FairyScope
FairyScope(
  viewModel: (locator) => ProfileViewModel(
    api: locator.get<ApiService>(),
  ),
  child: ProfilePage(),
)
```

### FairyBridge - For Overlays

Use `FairyBridge` to access parent FairyScope in dialogs/overlays:

```dart
showDialog(
  context: context,
  builder: (_) => FairyBridge(
    context: context,
    child: AlertDialog(
      content: Bind<MyViewModel, String>(
        bind: (vm) => vm.data,
        builder: (context, value, _) => Text(value),
      ),
    ),
  ),
);
```

## Advanced Features

### Deep Equality for Collections

`ObservableProperty` automatically performs **deep equality** for `List`, `Map`, and `Set` - even nested collections!

```dart
class TodoViewModel extends ObservableObject {
  final tags = ObservableProperty<List<String>>(['flutter', 'dart']);
  final matrix = ObservableProperty<List<List<int>>>([[1, 2], [3, 4]]);
  
  void updateTags() {
    tags.value = ['flutter', 'dart'];           // No rebuild (same contents)
    tags.value = ['flutter', 'dart', 'web'];    // Rebuilds
    matrix.value = [[1, 2], [3, 4]];            // No rebuild (nested equality!)
  }
}
```

**Disable if needed:** `ObservableProperty<List>([], deepEquality: false)`

### Custom Type Equality

Custom types use their `==` operator. Override it for value-based equality:

```dart
class User {
  final String id;
  final String name;
  
  @override
  bool operator ==(Object other) => other is User && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

// For types with collections, use Equals utility:
// Equals.listEquals(list1, list2), Equals.mapEquals(map1, map2)
```

### Command Error Handling

Commands support optional error handling via `onError` callback. Errors are stored in ViewModel properties and displayed using `Bind` widgets - consistent with Fairy's "Learn 2 widgets" philosophy.

**Basic Pattern:**
```dart
class MyViewModel extends ObservableObject {
  final errorMessage = ObservableProperty<String?>(null);
  
  late final saveCommand = AsyncRelayCommand(
    _save,
    onError: (error, stackTrace) {
      errorMessage.value = 'Failed to save: $error';
    },
  );
  
  Future<void> _save() async {
    errorMessage.value = null; // Clear previous errors
    await repository.save(data.value);
  }
}

// UI - Display errors with Bind
Bind<MyViewModel, String?>(
  bind: (vm) => vm.errorMessage,
  builder: (context, error, _) {
    if (error == null) return SizedBox.shrink();
    return Card(
      color: Colors.red[100],
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Text(error, style: TextStyle(color: Colors.red[900])),
      ),
    );
  },
)
```

**Type-Safe Error Handling:**
```dart
class MyViewModel extends ObservableObject {
  final error = ObservableProperty<Exception?>(null);
  
  late final loginCommand = AsyncRelayCommand(
    _login,
    onError: (error, stackTrace) {
      this.error.value = error as Exception;
      analytics.logError(error);
    },
  );
  
  Future<void> _login() async {
    error.value = null;
    await authService.login(email.value, password.value);
  }
}

// UI - Different handling per error type
Bind<MyViewModel, Exception?>(
  bind: (vm) => vm.error,
  builder: (context, error, _) {
    if (error is NetworkException) {
      return ErrorCard('Check your internet connection');
    } else if (error is AuthException) {
      return ErrorCard('Invalid credentials');
    } else if (error != null) {
      return ErrorCard('An error occurred');
    }
    return SizedBox.shrink();
  },
)
```

**Snackbar Pattern:**
```dart
class MyViewModel extends ObservableObject {
  final showSnackbar = ObservableProperty<String?>(null);
  
  late final deleteCommand = RelayCommandWithParam<String>(
    _delete,
    onError: (error, _) {
      showSnackbar.value = 'Delete failed: $error';
    },
  );
  
  void _delete(String id) {
    showSnackbar.value = null;
    repository.delete(id);
  }
}

// UI - Trigger snackbar
Bind<MyViewModel, String?>(
  bind: (vm) => vm.showSnackbar,
  builder: (context, message, update) {
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        update?.call(null); // Clear after showing
      });
    }
    return YourPageContent();
  },
)
```

**Key Points:**
- ✅ **Errors are state** - Store in `ObservableProperty` like any other state
- ✅ **Use Bind to display** - Consistent with existing patterns
- ✅ **Optional** - Only add `onError` when you need error handling
- ✅ **All command types supported** - Works with sync/async, with/without parameters

## Best Practices

### Cross-ViewModel Communication

**Why per-property listening**: `ObservableProperty` changes do NOT trigger parent `ObservableObject.onPropertyChanged()` - this preserves Fairy's granular rebuild advantage. Each property notifies only its own listeners, enabling targeted UI updates.

```dart
// ✅ Direct property subscription (recommended)
class DashboardViewModel extends ObservableObject {
  final _userVM = UserViewModel();
  VoidCallback? _nameListener;
  
  DashboardViewModel() {
    _nameListener = _userVM.name.propertyChanged(() {
      print('User name changed: ${_userVM.name.value}');
    });
  }
  
  @override
  void dispose() {
    _nameListener?.call();  // Dispose listener
    _userVM.dispose();
    super.dispose();
  }
}

// ✅ Multiple subscriptions with DisposableBag
class DashboardViewModel extends ObservableObject {
  final _userVM = UserViewModel();
  final _disposables = DisposableBag();
  
  DashboardViewModel() {
    _disposables.add(_userVM.name.propertyChanged(() => /* ... */));
    _disposables.add(_userVM.email.propertyChanged(() => /* ... */));
  }
  
  @override
  void dispose() {
    _disposables.dispose();
    _userVM.dispose();
    super.dispose();
  }
}

// ✅ ComputedProperty for derived state (cleanest)
class DashboardViewModel extends ObservableObject {
  final _userVM = UserViewModel();
  late final displayName = ComputedProperty<String>(
    () => '${_userVM.name.value} (${_userVM.email.value})',
  );
}
```

**Plain properties with manual `onPropertyChanged()`**: Use `ObservableObject.propertyChanged()` to listen to ALL changes on a ViewModel (not individual `ObservableProperty` instances):

```dart
class Logger extends ObservableObject {
  final _userVM = UserViewModel();
  VoidCallback? _vmListener;
  
  Logger() {
    // Listens to ALL property changes on _userVM
    _vmListener = _userVM.propertyChanged(() {
      print('Some property changed on UserViewModel');
    });
  }
}
```

### Auto-Disposal

Properties and commands are auto-disposed with parent ViewModels. **Exception:** Nested ViewModels require manual disposal:

```dart
class ParentViewModel extends ObservableObject {
  final data = ObservableProperty<String>('');
  late final childVM = ChildViewModel();  // ⚠️ Manual disposal required
  
  @override
  void dispose() {
    childVM.dispose();
    super.dispose();
  }
}
```

**Managing Multiple Disposables:** Use `DisposableBag` for cleaner disposal of multiple resources:

```dart
class MyViewModel extends ObservableObject {
  final _disposables = DisposableBag();
  
  MyViewModel() {
    _disposables.add(property.propertyChanged(() => /* ... */));
    _disposables.add(command.canExecuteChanged(() => /* ... */));
    _disposables.add(_subscription.cancel);  // Any VoidCallback
  }
  
  @override
  void dispose() {
    _disposables.dispose();  // Disposes all at once
    super.dispose();
  }
}
```

### Refresh Commands on Changes

When `canExecute` depends on properties, notify the command:

```dart
class MyViewModel extends ObservableObject {
  final selectedItem = ObservableProperty<Item?>(null);
  late final deleteCommand = RelayCommand(_delete, canExecute: () => selectedItem.value != null);
  
  VoidCallback? disposeChanges;
  
  MyViewModel() {
    disposeChanges = selectedItem.propertyChanged(() {
      deleteCommand.notifyCanExecuteChanged();
    });
  }
  
  void _delete() { /* ... */ }
  
  @override
  void dispose() {
    disposeChanges?.call();
    super.dispose();
  }
}
```

### Capture Disposers ⚠️

Manual listeners (via `propertyChanged()`/`canExecuteChanged()`) **must** be disposed to avoid memory leaks:

```dart
// ❌ MEMORY LEAK
viewModel.propertyChanged(() { print('changed'); });

// ✅ CORRECT
late VoidCallback dispose;
dispose = viewModel.propertyChanged(() { print('changed'); });
// Later: dispose();

// ✅ BEST: Use Bind/Command widgets (auto-managed)
Bind<MyViewModel, int>(
  bind: (vm) => vm.counter,
  builder: (context, value, _) => Text('$value'),
)
```

Auto-disposal only handles properties/commands, not manually registered listeners. Always capture disposers or use `Bind`/`Command` widgets.

### Use Scoped DI

```dart
// ✅ Scoped ViewModels auto-dispose
FairyScope(
  viewModel: (_) => UserProfileViewModel(userId: widget.userId),
  child: UserProfilePage(),
)
```

### Choose Right Binding

- **Single property (two-way):** `Bind<VM, T>` with `bind: (vm) => vm.prop` (returns ObservableProperty)
- **Single property (one-way):** `Bind<VM, T>` with `bind: (vm) => vm.prop.value` (returns raw value)
- **Multiple properties:** `Bind.viewModel<VM>` for auto-tracking
- **Avoid:** Creating new instances in binds (causes infinite rebuilds)

## Performance

Fairy is designed for performance. Benchmark results comparing with popular state management solutions (median of 5 measurements per test, averaged across 5 complete runs):

| Category | Fairy | Provider | Riverpod |
|----------|-------|----------|----------|
| Widget Performance (1000 interactions) | 112.7% | 101.9% | **100%** 🥇 |
| Memory Management (50 cycles) | 112.6% | 103.9% | **100%** 🥇 |
| Selective Rebuild (explicit Bind) | **100%** 🥇 | 133.5% | 131.3% |
| Auto-tracking Rebuild (Bind.viewModel) | **100%** 🥇 | 133.3% | 126.1% |

### Key Achievements
- **🥇 Fastest Selective Rebuilds** - 31-34% faster with explicit binding
- **🥇 Fastest Auto-tracking** - 26-33% faster while maintaining 100% rebuild efficiency
- **Unique**: Only framework achieving 100% selective efficiency (500 rebuilds) vs 33% for Provider/Riverpod (1500 rebuilds)
- **Memory**: **Intentional design decision** to use 13% more memory in exchange for 26-34% faster rebuilds (both auto-tracking and selective binding) plus superior developer experience with command auto-tracking

*Lower is better. Percentages relative to the fastest framework in each category. Benchmarked on v2.0.0.*

## Example

See the [example](../example) directory for a complete counter app demonstrating:
- MVVM architecture
- Reactive properties
- Command pattern with canExecute
- Data and command binding
- Scoped dependency injection

## Testing

Fairy ViewModels are **plain Dart classes** - no mocking frameworks or special setup required. Test business logic directly without widget overhead.

### Unit Testing ViewModels

```dart
test('increment updates counter', () {
  final vm = CounterViewModel();
  
  vm.incrementCommand.execute();
  
  expect(vm.counter.value, 1);
  vm.dispose();
});

test('login command validates email', () {
  final vm = LoginViewModel();
  
  vm.email.value = 'invalid';
  expect(vm.loginCommand.canExecute, false);
  
  vm.email.value = 'user@example.com';
  vm.password.value = 'password123';
  expect(vm.loginCommand.canExecute, true);
  
  vm.dispose();
});

test('computed property updates automatically', () {
  final vm = CartViewModel();
  
  vm.price.value = 10.0;
  vm.quantity.value = 3;
  
  expect(vm.total.value, 30.0);  // Automatically computed
  vm.dispose();
});

test('async command handles loading state', () async {
  final vm = DataViewModel();
  
  expect(vm.fetchCommand.isRunning, false);
  
  final future = vm.fetchCommand.execute();
  expect(vm.fetchCommand.isRunning, true);
  
  await future;
  expect(vm.fetchCommand.isRunning, false);
  expect(vm.data.value, isNotEmpty);
  
  vm.dispose();
});
```

### Widget Testing

```dart
testWidgets('counter increments on tap', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: FairyScope(
      viewModel: (_) => CounterViewModel(),
      child: CounterPage(),
    ),
  ));
  
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  expect(find.text('1'), findsOneWidget);
});
```

### Package Test Coverage

**574 tests passing** - covering observable properties, commands, auto-disposal, dependency injection, widget binding, deep equality, command auto-tracking, error handling, and overlays.

## Architecture Guidelines

### ViewModel
✅ **DO**: Business logic, state (ObservableProperty), commands, derived values (ComputedProperty)  
❌ **DON'T**: Reference BuildContext/widgets, navigation, UI logic, styling

### View (Widgets)
✅ **DO**: Use `Bind`/`Command` widgets, handle navigation, declarative composition  
❌ **DON'T**: Business logic, data validation, direct state modification

### Binding Patterns
✅ **DO**: 
- One-way (read-only): `bind: (vm) => vm.property.value`
- Two-way (editable): `bind: (vm) => vm.property` (returns ObservableProperty)
- Tuples (one-way): `bind: (vm) => (vm.a.value, vm.b.value)` ← All `.value`!

❌ **DON'T**: 
- Mix in tuples: `(vm.a.value, vm.b)` ← TypeError!
- Create new instances in binds ← Infinite rebuilds!

### Commands
✅ **DO**: Call `notifyCanExecuteChanged()` when conditions change, use `AsyncRelayCommand` for async  
❌ **DON'T**: Long operations in sync commands, forget to update `canExecute`

### Dependency Injection
✅ **DO**: `FairyScope` for pages/features, `FairyLocator` for app-wide services, `FairyBridge` for overlays  
❌ **DON'T**: Register ViewModels globally, manually dispose FairyScope ViewModels

## Comparison to Other Patterns

| Feature | Fairy | Provider | Riverpod | GetX | BLoC |
|---------|-------|----------|----------|------|------|
| Code Generation | ❌ | ❌ | ✅ | ❌ | ❌ |
| Type Safety | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| Boilerplate | **Low** | Low | Medium | Low | High |
| Learning Curve | **Low** | Low | Medium | Low | Medium |
| Command Pattern | **✅** | ❌ | ❌ | ❌ | ❌ |
| Two-Way Binding | **✅** | ❌ | ❌ | ✅ | ❌ |
| Auto-Disposal | **✅** | ⚠️ | ✅ | ✅ | ⚠️ |

## Documentation

For LLM-optimized documentation, see [llms.txt](https://github.com/AathifMahir/Fairy/blob/main/llms.txt) - comprehensive API reference for AI assistants.

## Maintenance & Release Cadence

Fairy follows a **non-breaking minor version** principle:

- **Major versions** (v1.0, v2.0, v3.0): May include breaking changes with migration guides
- **Minor versions** (v1.1, v1.2, v2.1, v2.2): New features and enhancements, **no breaking changes**
- **Patch versions** (v1.1.1, v2.0.1): Bug fixes and documentation updates only

**Examples:**
- ✅ v1.1, v1.2, v1.3 → All backward compatible with v1.0
- ✅ v2.1, v2.2, v2.3 → All backward compatible with v2.0
- ⚠️ v2.0 → May have breaking changes from v1.x (see CHANGELOG for migration guide)

**Upgrade confidence:** You can safely upgrade within the same major version without code changes.

**Support policy:** Only the current and previous major versions receive updates. Once v3.0 is released, v1.x will no longer receive updates (v2.x and v3.x will be supported).

## License

BSD 3-Clause License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting PRs.
