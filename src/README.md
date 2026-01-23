<div align="center">
  <img src="logo.png" alt="Fairy Logo" width="300"/>
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
  fairy: ^3.0.0
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

## Properties

Properties hold reactive state in your ViewModel. When a property's value changes, any bound UI automatically rebuilds.

### ObservableProperty\<T\>

The primary reactive property type. Automatically notifies listeners when `.value` changes.

```dart
class UserViewModel extends ObservableObject {
  final name = ObservableProperty<String>('');
  final age = ObservableProperty<int>(0);
  final isActive = ObservableProperty<bool>(true);
  
  void updateName(String newName) {
    name.value = newName;  // UI automatically rebuilds
  }
}
```

**Key features:**
- **Deep equality for collections**: `List`, `Map`, and `Set` values are compared by contents, not reference
- **Two-way binding**: When bound with `Bind`, provides an `update` callback for form inputs

### ObservableProperty.list/map/set

Factory constructors for collections that support **in-place mutations**. Use these when you need `add()`, `remove()`, or `[]=` to trigger UI updates.

```dart
class TodoViewModel extends ObservableObject {
  final todos = ObservableProperty.list<Todo>([]);
  final cache = ObservableProperty.map<String, Data>({});
  final tags = ObservableProperty.set<String>({});
  
  void addTodo(Todo todo) {
    todos.value.add(todo);       // ✅ Triggers rebuild
    cache.value[todo.id] = todo; // ✅ Triggers rebuild
  }
  
  void removeTag(String tag) {
    tags.value.remove(tag);      // ✅ Triggers rebuild
  }
}
```

**When to use:**

| Constructor | Use Case |
|-------------|----------|
| `ObservableProperty.list<T>()` | Mutable lists with add/remove |
| `ObservableProperty.map<K,V>()` | Mutable maps with updates |
| `ObservableProperty.set<T>()` | Mutable sets with add/remove |
| `ObservableProperty<List<T>>()` | Immutable pattern (reassignment only) |

**Smart notifications**: Only notifies when actual changes occur - `list[i] = value` only triggers if value differs.

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
// total.value automatically updates when price or quantity changes
```

### Subscribing to Changes

Use `propertyChanged()` to listen for changes programmatically. Returns a disposer function.

```dart
class MyViewModel extends ObservableObject {
  final name = ObservableProperty<String>('');
  late final VoidCallback _dispose;
  
  MyViewModel() {
    _dispose = name.propertyChanged(() {
      print('Name changed: ${name.value}');
    });
  }
  
  @override
  void dispose() {
    _dispose();  // Always clean up listeners!
    super.dispose();
  }
}
```

## Commands

Commands encapsulate actions with optional validation (`canExecute`) and error handling. They're the recommended way to handle user interactions.

### RelayCommand

Synchronous command for immediate actions.

```dart
class CounterViewModel extends ObservableObject {
  final count = ObservableProperty<int>(0);
  
  late final incrementCommand = RelayCommand(
    () => count.value++,
    canExecute: () => count.value < 100,  // Optional validation
  );
}
```

### AsyncRelayCommand

Asynchronous command with automatic `isRunning` state tracking and concurrent execution prevention.

```dart
class DataViewModel extends ObservableObject {
  final data = ObservableProperty<List<Item>>([]);
  
  late final fetchCommand = AsyncRelayCommand(
    () async {
      data.value = await api.fetchItems();
    },
    canExecute: () => !fetchCommand.isRunning,
  );
}
```

**Key features:**
- `isRunning` automatically tracks execution state
- Prevents concurrent execution by default
- Perfect for loading states: `if (isRunning) return CircularProgressIndicator();`

### Parameterized Commands

Use `.param<T>()` factory methods for commands that need parameters.

```dart
class TodoViewModel extends ObservableObject {
  final todos = ObservableProperty.list<Todo>([]);
  
  // Sync with parameter
  late final deleteCommand = RelayCommand.param<String>(
    (id) => todos.value.removeWhere((t) => t.id == id),
    canExecute: (id) => id.isNotEmpty,
  );
  
  // Async with parameter
  late final loadCommand = AsyncRelayCommand.param<String>(
    (userId) async => user.value = await api.fetchUser(userId),
  );
}
```

> **Note:** `.param<T>()` factory methods are preferred. Direct constructors (`RelayCommandWithParam<T>`, `AsyncRelayCommandWithParam<T>`) are also available for type annotations.

### Error Handling

Commands support optional error handling via `onError`. Store errors in properties and display with `Bind`.

```dart
class MyViewModel extends ObservableObject {
  final error = ObservableProperty<String?>(null);
  
  late final saveCommand = AsyncRelayCommand(
    _save,
    onError: (e, stack) => error.value = 'Save failed: $e',
  );
  
  Future<void> _save() async {
    error.value = null;  // Clear previous error
    await repository.save(data.value);
  }
}
```

### Dynamic canExecute

When `canExecute` depends on properties, call `notifyCanExecuteChanged()` when those properties change.

```dart
class MyViewModel extends ObservableObject {
  final selected = ObservableProperty<Item?>(null);
  late final deleteCommand = RelayCommand(
    _delete,
    canExecute: () => selected.value != null,
  );
  
  late final VoidCallback _dispose;
  
  MyViewModel() {
    _dispose = selected.propertyChanged(() {
      deleteCommand.notifyCanExecuteChanged();
    });
  }
  
  @override
  void dispose() {
    _dispose();
    super.dispose();
  }
}
```

## Widgets

Fairy provides two primary widgets: `Bind` for data and `Command` for actions.

### Bind\<TViewModel, TValue\>

Binds a single property to the UI. Best performance for single-property scenarios.

```dart
// Two-way binding (returns ObservableProperty)
Bind<UserViewModel, String>(
  bind: (vm) => vm.name,  // Returns property - enables update
  builder: (context, value, update) => TextField(
    controller: TextEditingController(text: value),
    onChanged: update,  // Two-way binding
  ),
)

// One-way binding (returns raw value)
Bind<UserViewModel, String>(
  bind: (vm) => vm.name.value,  // Returns value - read-only
  builder: (context, value, _) => Text(value),
)
```

### Bind.viewModel

Auto-tracks all accessed properties. Convenient for multiple properties.

```dart
Bind.viewModel<UserViewModel>(
  builder: (context, vm) => Column(
    children: [
      Text(vm.firstName.value),  // Both tracked
      Text(vm.lastName.value),   // automatically
    ],
  ),
)
```

**Multiple ViewModels:** Use `Bind.viewModel2/3/4`:
```dart
Bind.viewModel2<UserViewModel, SettingsViewModel>(
  builder: (context, user, settings) => 
    Text('${user.name.value} - ${settings.theme.value}'),
)
```

### Command\<TViewModel\>

Binds a command to the UI with execute, canExecute, and isRunning state.

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

For parameterized commands. `execute(T)` and `canExecute(T)` accept the parameter.

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

### FairyScopeLocator - Factory Dependency Access

The `FairyScopeLocator` is passed to ViewModel factory callbacks, providing access to **both** global dependencies and scoped ViewModels:

```dart
FairyScope(
  viewModel: (locator) => ProfileViewModel(
    // Access global services from FairyLocator
    api: locator.get<ApiService>(),
    db: locator.get<DatabaseService>(),
    
    // Access parent scope ViewModels
    appVM: locator.get<AppViewModel>(),
  ),
  child: ProfilePage(),
)
```

**Resolution order:**
1. Current `FairyScope` (for multiple VMs in same scope)
2. Parent `FairyScope` ancestors (nearest first)
3. Global `FairyLocator` registrations

**Multiple ViewModels - dependency between them:**
```dart
FairyScope(
  viewModels: [
    (_) => UserViewModel(),
    (locator) => SettingsViewModel(
      // Access UserViewModel from same scope
      userVM: locator.get<UserViewModel>(),
    ),
    (locator) => DashboardViewModel(
      // Access both from same scope
      userVM: locator.get<UserViewModel>(),
      settingsVM: locator.get<SettingsViewModel>(),
    ),
  ],
  child: DashboardPage(),
)
```

> **Note:** `FairyScopeLocator` is only valid during ViewModel construction. Do not store or use it outside the factory callback.

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

`ObservableProperty` automatically performs **deep equality** for `List`, `Map`, and `Set` - even nested collections. This prevents unnecessary rebuilds when setting the same content.

```dart
class TodoViewModel extends ObservableObject {
  final tags = ObservableProperty<List<String>>(['flutter', 'dart']);
  final matrix = ObservableProperty<List<List<int>>>([[1, 2], [3, 4]]);
  
  void updateTags() {
    tags.value = ['flutter', 'dart'];           // No rebuild (same contents)
    tags.value = ['flutter', 'dart', 'web'];    // Rebuilds (different)
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
  
  User(this.id, this.name);
  
  @override
  bool operator ==(Object other) => other is User && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

// For types with collections, use Equals utility:
// Equals.listEquals(list1, list2), Equals.mapEquals(map1, map2)
```

### Cross-ViewModel Communication

`ObservableProperty` changes do NOT trigger parent `ObservableObject.propertyChanged()` - this preserves granular rebuild performance. Use these patterns for cross-ViewModel communication:

**Direct property subscription (recommended):**
```dart
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
    _nameListener?.call();
    _userVM.dispose();
    super.dispose();
  }
}
```

**Multiple subscriptions with DisposableBag:**
```dart
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
```

**ComputedProperty for derived state (cleanest):**
```dart
class DashboardViewModel extends ObservableObject {
  final _userVM = UserViewModel();
  
  late final displayName = ComputedProperty<String>(
    () => '${_userVM.name.value} (${_userVM.email.value})',
    [_userVM.name, _userVM.email],
    this,
  );
  
  @override
  void dispose() {
    _userVM.dispose();
    super.dispose();
  }
}
```

### Vanilla Fields with onPropertyChanged()

For plain Dart fields (not `ObservableProperty`), manually call `onPropertyChanged()` to notify listeners:

```dart
class UserViewModel extends ObservableObject {
  String _name = '';
  int _age = 0;
  
  String get name => _name;
  int get age => _age;
  
  void updateName(String value) {
    _name = value;
    onPropertyChanged();  // Manually notify
  }
  
  // Batch updates - single notification
  void updateUser(String name, int age) {
    _name = name;
    _age = age;
    onPropertyChanged();  // One notification for both
  }
}
```

**When to use:**

| Approach | Use Case |
|----------|----------|
| `ObservableProperty` | Default choice - automatic notifications |
| Vanilla fields + `onPropertyChanged()` | Batch updates, legacy migration |
| `property.propertyChanged()` | Cross-ViewModel sync, side effects |

## Utilities

Fairy provides utility classes to help with common patterns.

### Equals

Deep equality utility for collections. Use when implementing `==` for custom types containing collections:

```dart
class User {
  final String id;
  final List<String> tags;
  
  User(this.id, this.tags);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          id == other.id &&
          Equals.listEquals(tags, other.tags);
  
  @override
  int get hashCode => id.hashCode ^ Equals.listHash(tags);
}
```

**Available methods:**

| Method | Description |
|--------|-------------|
| `Equals.listEquals(a, b)` | Deep equality for lists (supports nested) |
| `Equals.mapEquals(a, b)` | Deep equality for maps (supports nested) |
| `Equals.setEquals(a, b)` | Deep equality for sets (supports nested) |
| `Equals.deepCollectionEquals(a, b)` | Deep equality for any collection type |
| `Equals.listHash(list)` | Hash code for lists |
| `Equals.mapHash(map)` | Hash code for maps |
| `Equals.setHash(set)` | Hash code for sets |

### Disposable

Mixin providing lifecycle management with `isDisposed` flag and `throwIfDisposed()` helper:

```dart
class MyService with Disposable {
  void doSomething() {
    throwIfDisposed();  // Throws if already disposed
    // ... implementation
  }
  
  @override
  void dispose() {
    // Clean up resources
    super.dispose();  // Sets isDisposed = true
  }
}

// Usage
final service = MyService();
print(service.isDisposed);  // false
service.dispose();
print(service.isDisposed);  // true
```

> **Note:** `ObservableObject` already uses `Disposable` internally - you don't need to mix it in for ViewModels.

### DisposableBag

Helper for managing multiple dispose callbacks as a group:

```dart
class MyViewModel extends ObservableObject {
  final _disposables = DisposableBag();
  
  MyViewModel() {
    // Add dispose callbacks
    _disposables.add(property.propertyChanged(() => /* ... */));
    _disposables.add(command.canExecuteChanged(() => /* ... */));
    _disposables.add(() => _someResource.close());
  }
  
  @override
  void dispose() {
    _disposables.dispose();  // Disposes all registered callbacks
    super.dispose();
  }
}
```

**API:**

| Method | Description |
|--------|-------------|
| `add(VoidCallback)` | Registers a dispose callback |
| `dispose()` | Calls all registered callbacks and clears the bag |
| `clear()` | Clears callbacks without calling them |

## Best Practices

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

**Managing Multiple Disposables:** Use `DisposableBag`:

```dart
class MyViewModel extends ObservableObject {
  final _disposables = DisposableBag();
  
  MyViewModel() {
    _disposables.add(property.propertyChanged(() => /* ... */));
    _disposables.add(command.canExecuteChanged(() => /* ... */));
  }
  
  @override
  void dispose() {
    _disposables.dispose();
    super.dispose();
  }
}
```

### Capture Disposers ⚠️

Manual listeners **must** be disposed to avoid memory leaks:

```dart
// ❌ MEMORY LEAK
viewModel.propertyChanged(() { print('changed'); });

// ✅ CORRECT
late VoidCallback dispose;
dispose = viewModel.propertyChanged(() { print('changed'); });
// Later: dispose();

// ✅ BEST: Use Bind/Command widgets (auto-managed)
```

### Architecture Guidelines

**ViewModel:**
- ✅ Business logic, state (ObservableProperty), commands, derived values (ComputedProperty)
- ❌ Reference BuildContext/widgets, navigation, UI logic

**View (Widgets):**
- ✅ Use `Bind`/`Command` widgets, handle navigation
- ❌ Business logic, data validation, direct state modification

**Binding Patterns:**
- One-way: `bind: (vm) => vm.property.value`
- Two-way: `bind: (vm) => vm.property`
- ❌ Don't create new instances in binds (causes infinite rebuilds)

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

Fairy ViewModels are **plain Dart classes** - test business logic directly without widget overhead.

```dart
test('counter increments', () {
  final vm = CounterViewModel();
  vm.incrementCommand.execute();
  expect(vm.counter.value, 1);
  vm.dispose();
});

test('computed property updates', () {
  final vm = CartViewModel();
  vm.price.value = 10.0;
  vm.quantity.value = 3;
  expect(vm.total.value, 30.0);
  vm.dispose();
});

test('async command tracks loading', () async {
  final vm = DataViewModel();
  final future = vm.fetchCommand.execute();
  expect(vm.fetchCommand.isRunning, true);
  await future;
  expect(vm.fetchCommand.isRunning, false);
  vm.dispose();
});
```

**667 tests passing** - covering properties, commands, auto-disposal, DI, binding, deep equality, and more.

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
