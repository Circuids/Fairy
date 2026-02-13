<div align="center">
  <img src="src/logo.png" alt="Fairy Logo" width="300"/>


  [![pub package](https://img.shields.io/pub/v/fairy.svg)](https://pub.dev/packages/fairy)
  [![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
  [![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?logo=Flutter&logoColor=white)](https://flutter.dev)

</div>

A lightweight MVVM framework for Flutter with strongly-typed reactive data binding, commands, and dependency injection - no code generation required.

**Simplicity over complexity** - Clean APIs, minimal boilerplate, zero dependencies.

## 📖 Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Properties](#properties)
- [Commands](#commands)
- [Widgets](#widgets)
- [Dependency Injection](#dependency-injection)
- [Advanced Features](#advanced-features)
- [Utilities](#utilities)
- [Best Practices](#best-practices)
- [Performance](#performance)
- [Testing](#testing)
- [Maintenance & Release Cadence](#maintenance--release-cadence)

## Features

-  **Few Widgets to Learn** - `Bind` for data, `Command` for actions
-  **Type-Safe** - Strongly-typed with compile-time safety
-  **No Code Generation** - Runtime-only, no build_runner
-  **Auto UI Updates** - Data binding that just works
-  **Command Pattern** - Actions with `canExecute` validation and error handling
-  **Dependency Injection** - Global and scoped DI
-  **Lightweight** - Zero external dependencies

## Installation

```yaml
dependencies:
  fairy: ^3.0.0+1
```

## Quick Start

```dart
// 1. Create ViewModel
class CounterViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
  late final incrementCommand = RelayCommand(() => counter.value++);
}

// 2. Provide ViewModel with FairyScope
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

## Properties

Properties hold reactive state in your ViewModel. When a property's value changes, any bound UI automatically rebuilds.

### ObservableProperty\<T\>

The primary reactive property type. Automatically notifies listeners when `.value` changes.

```dart
class UserViewModel extends ObservableObject {
  final name = ObservableProperty<String>('');
  final age = ObservableProperty<int>(0);
  
  void updateName(String newName) {
    name.value = newName;  // UI automatically rebuilds
  }
}
```

**Key features:**
- **Deep equality for collections**: `List`, `Map`, and `Set` values are compared by contents
- **Two-way binding**: When bound with `Bind`, provides an `update` callback for form inputs

### ObservableProperty.list/map/set

Factory constructors for collections that support **in-place mutations**.

```dart
class TodoViewModel extends ObservableObject {
  final todos = ObservableProperty.list<Todo>([]);
  final cache = ObservableProperty.map<String, Data>({});
  final tags = ObservableProperty.set<String>({});
  
  void addTodo(Todo todo) {
    todos.value.add(todo);       // ✅ Triggers rebuild
    cache.value[todo.id] = todo; // ✅ Triggers rebuild
  }
}
```

| Constructor | Use Case |
|-------------|----------|
| `ObservableProperty.list<T>()` | Mutable lists with add/remove |
| `ObservableProperty.map<K,V>()` | Mutable maps with updates |
| `ObservableProperty.set<T>()` | Mutable sets with add/remove |
| `ObservableProperty<List<T>>()` | Immutable pattern (reassignment only) |

### ComputedProperty\<T\>

Derived values that automatically recalculate when dependencies change.

```dart
class CartViewModel extends ObservableObject {
  final price = ObservableProperty<double>(10.0);
  final quantity = ObservableProperty<int>(2);
  
  late final total = ComputedProperty<double>(
    () => price.value * quantity.value,
    [price, quantity],  // Dependencies
    this,               // Parent for auto-disposal
  );
}
```

## Commands

Commands encapsulate actions with optional validation (`canExecute`) and error handling.

### RelayCommand

Synchronous command for immediate actions.

```dart
late final incrementCommand = RelayCommand(
  () => count.value++,
  canExecute: () => count.value < 100,
);
```

### AsyncRelayCommand

Asynchronous command with automatic `isRunning` state tracking.

```dart
late final fetchCommand = AsyncRelayCommand(
  () async => data.value = await api.fetchItems(),
);
// fetchCommand.isRunning tracks loading state automatically
```

### Parameterized Commands

Use `.param<T>()` factory methods for commands that need parameters.

```dart
// Sync with parameter
late final deleteCommand = RelayCommand.param<String>(
  (id) => todos.value.removeWhere((t) => t.id == id),
  canExecute: (id) => id.isNotEmpty,
);

// Async with parameter
late final loadCommand = AsyncRelayCommand.param<String>(
  (userId) async => user.value = await api.fetchUser(userId),
);
```

> **Note:** `.param<T>()` factory methods are preferred. Direct constructors (`RelayCommandWithParam<T>`, `AsyncRelayCommandWithParam<T>`) are also available.

> **Tip:** `AsyncRelayCommand.param<T>` blocks concurrent execution — `execute("B")` is silently dropped while `execute("A")` is still running. This is fine for data-loading commands like `loadCommand` above, but can cause missed taps in selection-style commands. See [Fast Command Actions](#fast-command-actions) for the fix.

### Error Handling

```dart
late final saveCommand = AsyncRelayCommand(
  _save,
  onError: (e, stack) => error.value = 'Save failed: $e',
);
```

### Dynamic canExecute

```dart
MyViewModel() {
  _dispose = selected.propertyChanged(() {
    deleteCommand.notifyCanExecuteChanged();
  });
}
```

## Widgets

Fairy provides two primary widgets: `Bind` for data and `Command` for actions.

### Bind\<TViewModel, TValue\>

```dart
// Two-way binding
Bind<UserViewModel, String>(
  bind: (vm) => vm.name,  // Returns property
  builder: (context, value, update) => TextField(
    controller: TextEditingController(text: value),
    onChanged: update,
  ),
)

// One-way binding
Bind<UserViewModel, String>(
  bind: (vm) => vm.name.value,  // Returns value
  builder: (context, value, _) => Text(value),
)
```

### Bind.viewModel

Auto-tracks all accessed properties.

```dart
Bind.viewModel<UserViewModel>(
  builder: (context, vm) => Column(
    children: [
      Text(vm.firstName.value),
      Text(vm.lastName.value),
    ],
  ),
)
```

### Command\<TViewModel\>

```dart
Command<MyViewModel>(
  command: (vm) => vm.saveCommand,
  builder: (context, execute, canExecute, isRunning) {
    if (isRunning) return CircularProgressIndicator();
    return ElevatedButton(
      onPressed: canExecute ? execute : null,
      child: Text('Save'),
    );
  },
)
```

### Command.param

```dart
Command.param<TodoViewModel, String>(
  command: (vm) => vm.deleteCommand,
  builder: (context, execute, canExecute, isRunning) => IconButton(
    onPressed: canExecute(todoId) ? () => execute(todoId) : null,
    icon: Icon(Icons.delete),
  ),
)
```

## Dependency Injection

### FairyScope - Widget-Scoped DI

```dart
FairyScope(
  viewModel: (_) => ProfileViewModel(),
  child: ProfilePage(),
)

// Access in widgets
final vm = Fairy.of<UserViewModel>(context);
```

### FairyScopeLocator - Factory Dependency Access

The `FairyScopeLocator` passed to factory callbacks provides access to **both** global and scoped dependencies:

```dart
FairyScope(
  viewModel: (locator) => ProfileViewModel(
    api: locator.get<ApiService>(),       // Global (FairyLocator)
    appVM: locator.get<AppViewModel>(),   // Parent scope
  ),
  child: ProfilePage(),
)

// Multiple VMs can depend on each other
FairyScope(
  viewModels: [
    (_) => UserViewModel(),
    (locator) => SettingsViewModel(
      userVM: locator.get<UserViewModel>(),  // Same scope
    ),
  ],
  child: DashboardPage(),
)
```

**Resolution order:** Current scope → Parent scopes → `FairyLocator`

### FairyLocator - Global DI

```dart
void main() {
  FairyLocator.registerSingleton<ApiService>(ApiService());
  runApp(MyApp());
}
```

### FairyBridge - For Overlays

```dart
showDialog(
  context: context,
  builder: (_) => FairyBridge(
    context: context,
    child: AlertDialog(content: /* Bind widgets work here */),
  ),
);
```

## Advanced Features

### Deep Equality for Collections

`ObservableProperty` performs **deep equality** for `List`, `Map`, and `Set` - even nested collections:

```dart
tags.value = ['flutter', 'dart'];           // No rebuild (same contents)
tags.value = ['flutter', 'dart', 'web'];    // Rebuilds (different)
matrix.value = [[1, 2], [3, 4]];            // No rebuild (nested equality!)
```

**Disable if needed:** `ObservableProperty<List>([], deepEquality: false)`

### Custom Type Equality

Override `==` for value-based equality:

```dart
class User {
  final String id;
  final String name;
  
  @override
  bool operator ==(Object other) => other is User && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}
```

### Cross-ViewModel Communication

Use `propertyChanged()` to listen across ViewModels:

```dart
class DashboardViewModel extends ObservableObject {
  final _userVM = UserViewModel();
  VoidCallback? _listener;
  
  DashboardViewModel() {
    _listener = _userVM.name.propertyChanged(() {
      print('User name changed: ${_userVM.name.value}');
    });
  }
  
  @override
  void dispose() {
    _listener?.call();
    _userVM.dispose();
    super.dispose();
  }
}
```

Or use `ComputedProperty` for derived state:

```dart
late final displayName = ComputedProperty<String>(
  () => '${_userVM.name.value} (${_userVM.email.value})',
  [_userVM.name, _userVM.email],
  this,
);
```

## Utilities

### Equals

Deep equality utility for collections in custom types:

```dart
class User {
  final String id;
  final List<String> tags;
  
  @override
  bool operator ==(Object other) =>
      other is User && id == other.id && Equals.listEquals(tags, other.tags);
  
  @override
  int get hashCode => id.hashCode ^ Equals.listHash(tags);
}
```

**Methods:** `listEquals`, `mapEquals`, `setEquals`, `deepCollectionEquals`, `listHash`, `mapHash`, `setHash`

### Disposable

Mixin for lifecycle management with `isDisposed` flag:

```dart
class MyService with Disposable {
  void doSomething() {
    throwIfDisposed();  // Throws if disposed
  }
}
```

### DisposableBag

Manage multiple dispose callbacks:

```dart
final _disposables = DisposableBag();
_disposables.add(property.propertyChanged(() => /* ... */));
_disposables.dispose();  // Disposes all
```

## Best Practices

### Auto-Disposal

Properties and commands auto-dispose with parent ViewModels. Nested ViewModels require manual disposal:

```dart
@override
void dispose() {
  childVM.dispose();
  super.dispose();
}
```

### Capture Disposers ⚠️

```dart
// ❌ MEMORY LEAK
viewModel.propertyChanged(() { });

// ✅ CORRECT
final dispose = viewModel.propertyChanged(() { });
// Later: dispose();
```

### Fast Command Actions

`AsyncRelayCommand` and `AsyncRelayCommand.param<T>` block concurrent execution — while running, `canExecute` returns `false` and subsequent `execute()` calls are silently dropped. This is ideal for destructive/submit actions (delete, save, submit) where double-execution is dangerous.

For **selection or navigation patterns** (tapping items in a list, switching tabs), this means rapid taps get lost if the action awaits slow I/O. The fix: update observable state **synchronously**, then fire-and-forget the slow async work.

**Before (broken — blocks rapid taps):**
```dart
late final selectCommand = AsyncRelayCommand.param<String>(
  (id) async {
    selectedId.value = id;
    await api.saveSelection(id);  // Slow — blocks next tap
  },
);
```

**After (correct — instant state update):**
```dart
late final selectCommand = AsyncRelayCommand.param<String>(
  (id) async {
    selectedId.value = id;             // Instant UI update
    unawaited(_persistSelection(id));  // Fire-and-forget slow work
  },
);
```

### Architecture

- **ViewModel**: Business logic, state, commands
- **View**: `Bind`/`Command` widgets, navigation
- ❌ Don't create new instances in binds (causes infinite rebuilds)

## Performance

| Category | Fairy | Provider | Riverpod |
|----------|-------|----------|----------|
| Selective Rebuild | **100%** 🥇 | 133.5% | 131.3% |
| Auto-tracking Rebuild | **100%** 🥇 | 133.3% | 126.1% |

**🥇 Fastest Selective Rebuilds** - 31-34% faster with explicit binding

## Testing

```dart
test('counter increments', () {
  final vm = CounterViewModel();
  vm.incrementCommand.execute();
  expect(vm.counter.value, 1);
  vm.dispose();
});
```

**667 tests passing** - covering properties, commands, auto-disposal, DI, binding, and more.

## Comparison

| Feature | Fairy | Provider | Riverpod | GetX | BLoC |
|---------|-------|----------|----------|------|------|
| Code Generation | ❌ | ❌ | ✅ | ❌ | ❌ |
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

**Support policy:** Only the current and previous major versions receive updates. Once v4.0 is released, v2.x will no longer receive updates (v3.x and v4.x will be supported).

## License

BSD 3-Clause License - see [LICENSE](./src/LICENSE) file for details.

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting PRs.
