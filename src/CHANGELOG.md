## 2.0.0+1

**Documentation Enhancement** - Improved clarity on change notification APIs and ViewModel testing.

### 📚 Documentation

#### Change Notification APIs - Clarified Isolation
- **Rewrote Core Concepts section** to properly explain notification isolation between observable types
- **Added clarity table** showing `propertyChanged()` scope for each type:
  - `ObservableProperty<T>` → Only notifies listeners of this specific property
  - `ComputedProperty<T>` → Only notifies listeners of this specific computed property
  - `ObservableObject` → Only notifies for vanilla fields (via `onPropertyChanged()`)
- **Key insight documented**: `ObservableProperty` and `ComputedProperty` changes do **NOT** trigger `ObservableObject.propertyChanged()` listeners - this enables Fairy's granular rebuild performance
- **Added decision table** for choosing between approaches

#### Testing Section - Emphasis on ViewModel Testing
- **Rewrote Testing section** to emphasize that ViewModels are plain Dart classes
- **Added 4 comprehensive unit test examples**:
  - Basic command execution testing
  - `canExecute` validation testing
  - Computed property auto-update testing
  - Async command loading state testing
- **Highlighted**: No mocking frameworks or special setup required
- Package test coverage moved to dedicated subsection

### Notes

- Documentation-only release, no code changes
- Fully backward compatible

---

## 2.0.0

**V2 Major Release** - Cleaner API with better error handling and simplified dependency injection.

### 🔄 Breaking Changes

#### 1. Bind Widget: `selector:` → `bind:` Parameter

**Migration:** Find and replace `selector:` with `bind:` in all `Bind` widgets.

```dart
// Before (V1)
Bind<UserViewModel, String>(
  selector: (vm) => vm.userName,
  builder: (context, value, update) => TextField(...),
)

// After (V2)
Bind<UserViewModel, String>(
  bind: (vm) => vm.userName,
  builder: (context, value, update) => TextField(...),
)
```

#### 2. FairyLocator: Remove `.instance`

**Migration:** Find and replace `FairyLocator.instance.` with `FairyLocator.`

```dart
// Before (V1)
FairyLocator.instance.registerSingleton<ApiService>(ApiService());
final api = FairyLocator.instance.get<ApiService>();

// After (V2)
FairyLocator.registerSingleton<ApiService>(ApiService());
final api = FairyLocator.get<ApiService>();
```

**All methods are now static:** `registerSingleton`, `registerLazySingleton`, `registerFactory`, `get`, `isRegistered`, `unregister`, `reset`.

### ✨ New Features

#### Command Error Handling with `onError` Callback

Commands now support error handling at the UI level via optional `onError` callback. Available on all command types:

```dart
class LoginViewModel extends ObservableObject {
  final errorMessage = ObservableProperty<String?>(null);
  
  late final loginCommand = AsyncRelayCommand(
    _login,
    onError: (error, stackTrace) {
      errorMessage.value = 'Login failed: $error';
      logger.error('Login error', error, stackTrace);
    },
  );
  
  Future<void> _login() async {
    errorMessage.value = null; // Clear previous errors
    await authService.login(email.value, password.value);
  }
}

// Display errors using Bind (consistent with "Learn 2 widgets" philosophy)
Bind<LoginViewModel, String?>(
  bind: (vm) => vm.errorMessage,
  builder: (context, error, _) {
    if (error == null) return SizedBox.shrink();
    return ErrorCard(error);
  },
)
```

**Key Points:**
- Errors stored as state in ViewModel (`ObservableProperty`)
- Display errors via `Bind` widget (consistent pattern)
- Optional callback - only add when needed
- Available on: `RelayCommand`, `AsyncRelayCommand`, `RelayCommandWithParam<T>`, `AsyncRelayCommandWithParam<T>`

### 🎯 Design Decisions

#### Why No `context.watch<T>()` or `ref.watch<T>()` Style Extensions?

**Deliberate omission** to maintain Fairy's core philosophy and simplicity:

- **Widget-based API keeps it simple**: `Bind` and `Command` widgets handle all reactive needs without requiring custom `StatelessWidget`/`StatefulWidget` base classes
- **No framework coupling**: Unlike Provider/Riverpod which require `ConsumerWidget`/`ConsumerStatefulWidget`, Fairy works with standard Flutter widgets
- **Avoid complexity**: Listenable extensions would require new widget types and lifecycle patterns, contradicting the "Learn 2 widgets" philosophy
- **Explicit over implicit**: `Bind` widgets make reactive dependencies visible and auditable in the widget tree

**For imperative access** (e.g., calling commands in callbacks), `Fairy.of<T>(context)` provides read-only ViewModel access. For overlays, use `FairyBridge` widget.

### 📚 Documentation

- Added comprehensive command error handling examples (basic, type-safe, snackbar patterns)
- Updated Quick Reference table with error handling capabilities
- Updated all examples to use V2 API (`bind:` parameter, static `FairyLocator`)
- Enhanced Common Patterns section with error handling integration

### 🧪 Testing

- **574 tests** passing (up from 565 in v1.4.0)
- Added 9 tests for command error handling scenarios
- All breaking changes validated with updated tests

### 📊 Performance

- Benchmarks updated with V2 measurements
- Performance characteristics maintained from v1.4.0
- Memory: 112.6% baseline, Widget: 112.7% baseline
- Selective Rebuilds: 100% baseline (31-34% faster than Provider/Riverpod)
- Auto-tracking: 100% baseline (26-33% faster than Provider/Riverpod)

### 💡 Migration Effort

**Small projects (< 10 files):** 10-15 minutes  
**Medium projects (10-50 files):** 20-30 minutes  
**Large projects (50+ files):** 30-60 minutes

**Migration steps:**
1. Replace `selector:` → `bind:` (find & replace)
2. Replace `FairyLocator.instance.` → `FairyLocator.` (find & replace)
3. Test thoroughly
4. Optionally add error handling where needed


### 📅 Release & Support

**Introduced formal versioning policy:** Fairy now follows a non-breaking minor version principle with clear support cadence. See README for full details on version compatibility and support policy.

---

## 1.4.0

**Auto-Tracking for Commands** - Commands now automatically track when accessed in `Bind.viewModel`, enabling reactive UI updates without explicit `Command` widget usage.

### ✨ New Features

- **Command.canExecute auto-tracking** - All command `canExecute` getters/methods now report access to `DependencyTracker`
  - `RelayCommand.canExecute` getter automatically tracked
  - `AsyncRelayCommand.canExecute` getter automatically tracked
  - `RelayCommandWithParam<T>.canExecute(param)` method automatically tracked
  - `AsyncRelayCommandWithParam<T>.canExecute(param)` method automatically tracked
  - Impact: `Bind.viewModel` now rebuilds when `notifyCanExecuteChanged()` is called, even without using `Command` widget

### 🎯 Benefits

**Before (v1.3.x):**
```dart
Bind.viewModel<MyViewModel>(
  builder: (context, vm) {
    // ❌ This won't rebuild when canExecute changes!
    return ElevatedButton(
      onPressed: vm.saveCommand.canExecute ? vm.saveCommand.execute : null,
      child: Text('Save'),
    );
  },
)
```

**After (v1.4.0):**
```dart
Bind.viewModel<MyViewModel>(
  builder: (context, vm) {
    // ✅ Automatically rebuilds when canExecute changes!
    return ElevatedButton(
      onPressed: vm.saveCommand.canExecute ? vm.saveCommand.execute : null,
      child: Text('Save'),
    );
  },
)
```

### 📝 Migration Guide

**No code changes required!** This is fully backward compatible:

- ✅ Existing `Command` widget usage → Works exactly the same
- ✅ Direct command access in `Bind.viewModel` → Now auto-tracks (was broken before)
- ✅ Direct command `execute()` calls → Works exactly the same

### 🧪 Testing

- Added 7 comprehensive tests for command auto-tracking in `Bind.viewModel`
- Added 6 tests for command selector patterns and edge cases
- All 565 tests passing

### 📊 Performance

- Improved benchmark methodology with noise reduction (warm-up + median of 5 measurements)
- **Rebuild Performance**: 24-32% faster than Provider/Riverpod with auto-tracking
- **Selective Rebuilds**: 30-38% faster with explicit binding
- **Memory Trade-off**: Intentional 14% increase for superior rebuild performance and DX

### Notes

- Fully backward compatible - no breaking changes
- Improves developer experience by making command usage more intuitive
- Commands now behave consistently with `ObservableProperty` auto-tracking

---

## 1.3.5+1

**Documentation Refinement** - Improved clarity and completeness of binding patterns and disposal utilities.

### 📚 Documentation

- **Enhanced binding examples** - Added one-way binding example alongside two-way in Data Binding section
- **Clarified binding patterns** - Corrected misleading statement about one-way binding requiring manual notifications
- **Added UI integration** - Dynamic canExecute section now shows complete ViewModel-to-UI flow
- **Compacted Custom Type Equality** - Streamlined section by removing redundant examples
- **Added DisposableBag documentation** - Utility for managing multiple disposable resources in ViewModels

### Notes

- Documentation-only release, no code changes
- Fully backward compatible

---

## 1.3.5

**Documentation Overhaul & Regression Fix** - Comprehensive README improvements and restores plain property binding support from v1.2.0.

### 🐛 Bug Fixes

- **Fixed**: Plain property getters with `onPropertyChanged()` now properly trigger UI rebuilds
  - Issue: After v1.3.0, bindings using plain getters (e.g., `selector: (vm) => vm.message` where `message` is a regular property) stopped rebuilding
  - Solution: Restored ViewModel subscription fallback for plain properties while preserving v1.3.0's ObservableProperty tracking
  - Impact: Both ObservableProperty and plain property patterns now work correctly

### 📚 Documentation

- **Improved README structure** - Reduced from 1341 to ~520 lines (61% more compact)
- **Added Quick Reference tables** - Properties, Commands, and Widget types at a glance
- **Added Common Patterns section** - 4 practical copy-paste examples (form validation, list operations, loading states, dynamic canExecute)
- **Added Performance benchmarks** - Comparative analysis with Provider and Riverpod
- **Updated positioning** - "Simplicity over complexity" as core philosophy
- **Unified root and package READMEs** - Consistent high-quality documentation across GitHub and pub.dev
- **Fixed Bind.viewModel2/3/4 documentation** - Correctly described as multi-ViewModel binding
- **Corrected `Bind.observer` references** to `Bind.viewModel` in API documentation

### 🧪 Testing

- Added 21 tests for plain property binding patterns
- Total: 543 tests passing (up from 522 in v1.3.0)

### Notes

- Fully backward compatible with v1.2.0 and v1.3.0
- No breaking changes

---

## 1.3.0

**One-Way Binding Fix & Tuple Support Release** - Critical bug fix for one-way binding with improved tuple handling.

This release fixes a critical bug where one-way bindings with `.value` access didn't trigger UI rebuilds, and adds comprehensive tuple binding support with clear documentation of limitations.

### 🐛 Bug Fixes

#### One-Way Binding Rebuild Issue (Critical)
- **Fixed**: One-way bindings now properly rebuild when ObservableProperty values change
  - **Issue**: Selectors using `.value` (e.g., `selector: (vm) => vm.property.value`) didn't rebuild UI
  - **Root Cause**: One-way binding only subscribed to ViewModel.propertyChanged(), missing direct property changes
  - **Solution**: Integrated DependencyTracker to automatically track all accessed ObservableProperty instances
  - **Impact**: All `.value` accesses in selectors now correctly trigger UI updates

#### DependencyTracker Integration
- **Enhanced**: Bind widget now uses DependencyTracker for one-way bindings
  - Automatically detects which ObservableProperty instances are accessed during selector evaluation
  - Subscribes to all accessed properties for change notifications
  - Re-tracks dependencies on each change for dynamic selector patterns
  - Proper cleanup of all tracked listeners on disposal

### 🧪 Testing Enhancements

#### Comprehensive Tuple Binding Tests
- **Added 17 new tests** for tuple selector patterns covering all scenarios
  - ✅ **8 tests**: Tuples with `.value` access (all working correctly)
  - ✅ **4 tests**: Two-way binding without `.value` for non-tuple cases
  - ✅ **4 tests**: Tuples without `.value` (correctly throwing TypeError to document limitation)
  - ✅ **1 test**: Documentation explaining technical reasons for tuple limitations

#### Memory Leak Prevention Tests
- **Added 8 comprehensive tests** validating proper disposal and cleanup
  - Basic one-way binding disposal
  - Multiple property cleanup
  - Selector changes (switching between properties)
  - List binding cleanup
  - Stress testing (50 create/dispose cycles)
  - Mixed one-way/two-way binding scenarios
  - Rapid rebuild and disposal (20 cycles with 3 updates each)
  - All tests validate no memory leaks after disposal

#### List Binding Tests
- **Added 4 tests** for one-way binding with list values
  - Deep equality validation with list modifications
  - Shallow equality with new list instances
  - Proper understanding of deepEquality parameter behavior

### 📚 Documentation Improvements

#### Tuple Binding Patterns
- **Documented valid tuple patterns**: All tuple items must use `.value`
  ```dart
  // ✅ VALID
  Bind<VM, (int, String)>(
    selector: (vm) => (vm.counter.value, vm.message.value),
    builder: (context, tuple, update) => ...
  )
  
  // ❌ INVALID - Will throw TypeError
  Bind<VM, (int, String)>(
    selector: (vm) => (vm.counter, vm.message),  // ObservableProperty instances
    builder: (context, tuple, update) => ...
  )
  ```

#### Technical Limitation Explained
- **Why tuples don't support ObservableProperty unwrapping**:
  - Automatic unwrapping only works for top-level return values
  - Tuples with ObservableProperty instances fail type casting: `_selected as TValue`
  - Supporting this would require runtime type introspection and recursive unwrapping
  - Clear error messages guide developers to correct usage

### 🎯 Test Suite Status
- **Total Tests**: 505 tests (up from 497)
  - +8 tests for tuple binding scenarios
  - +8 tests for memory leak prevention
  - +4 tests for list binding patterns
- **All Tests Passing**: 100% pass rate

### 📦 Breaking Changes

None - This is a backward-compatible bug fix release.

### 💡 Migration Guide

No migration needed. This release fixes existing functionality without API changes. If you were experiencing issues with one-way bindings not updating, they will now work correctly.

---

## 1.2.0

**Enhanced Dependency Tracking Release** - Advanced lazy builder support and performance optimizations.

This release introduces intelligent dependency tracking for deferred callbacks (ListView.builder) and significantly improves rebuild performance for `Bind.viewModel` API.

### 🚀 New Features

#### Enhanced Dependency Tracker
- **Lazy builder support** - Automatic tracking for deferred callbacks like `ListView.builder`
  - InheritedWidget-based fallback enables `itemBuilder` property access detection
  - Stack-based primary tracking with context-based fallback for deferred execution
  - Zero-configuration - works automatically with all lazy builders

### ⚡ Performance Improvements

#### Benchmark Results (5-run average)
- **Memory Management**: Fastest cleanup (100% baseline, 0.5% faster than Riverpod, 6.7% faster than Provider)
- **Selective Rebuilds**: 22.6-34% faster than competitors
- **Auto-binding**: 0.9-3.9% faster with 100% rebuild efficiency
- **Widget Performance**: Within 1.8% of fastest framework

### 🎯 Key Achievements
- **3 Gold Medals** in memory management, selective rebuilds, and auto-binding
- **100% Rebuild Efficiency** - Only framework achieving perfect selectivity vs 33% for Provider/Riverpod
- **Reliable Results** - Stable averages with engine warm-up for consistent measurements

### 📦 Breaking Changes

None - This is a backward-compatible enhancement release.

---

## 1.1.2

**Documentation & Testing Release** - Enhanced documentation clarity and comprehensive deep nesting test coverage.

This release focuses on improving developer experience through clearer documentation and ensuring robust FairyScope behavior with deep widget tree hierarchies.

### 📚 Documentation Improvements

#### Enhanced Code Examples
- **Disposer naming convention** updated across all examples
  - Renamed from `_disposeListener`, `_disposePropertyListener` to clearer names
  - `disposePropertyChanges` for property change subscriptions
  - `disposeCommandChanges` for command canExecute subscriptions
  - More self-documenting and consistent across the codebase

#### Fixed "Without ComputedProperty" Example
- Added proper disposer captures to the manual implementation example
- Shows complete lifecycle management including dispose() override
- Makes the comparison with ComputedProperty even more compelling (28 lines vs 10 lines)

### 🧪 Testing Enhancements

#### Deep Nesting Test Coverage
- **Added 4-level FairyScope nesting test** to ensure robust hierarchical dependency resolution
  - Tests ViewModel access from first scope in fourth nested scope (3 levels up)
  - Verifies all intermediate scope traversals work correctly
  - Validates identity preservation across deep scope hierarchies
  - **443 tests passing** (up from 442)

### 📦 Version Bump

- Updated version to **1.1.2** across all package files
- No breaking changes - fully backward compatible

---

## 1.1.1

**Memory Leak Prevention Release** - Critical fix for ComputedProperty memory leaks with required parent parameter.

This release addresses a critical memory leak in `ComputedProperty` and introduces a cleaner, more explicit API that makes memory safety impossible to miss.

### 🔒 Memory Leak Fix

#### ComputedProperty Required Parent Parameter
- **Parent parameter is now required and positional** for `ComputedProperty`
  - **Before**: `ComputedProperty<T>(compute, dependencies)` - optional parent, easy to forget
  - **After**: `ComputedProperty<T>(compute, dependencies, this)` - required parent, impossible to forget
  - Prevents memory leaks by ensuring ComputedProperty is always auto-disposed
  - Cleaner, more concise syntax with positional parameter
  - Compiler enforces correct usage - no runtime surprises

#### Why This Matters
ComputedProperty creates circular references with its dependencies:
- ComputedProperty → dependencies (strong reference)
- dependencies._listeners → ComputedProperty._onDependencyChanged (strong reference back)
- Without disposal, this cycle prevents garbage collection

The required parent parameter ensures:
- ✅ **Deterministic disposal** - no magic, no finalizers needed
- ✅ **Zero memory leaks** - impossible to forget disposal
- ✅ **Explicit is better than implicit** - follows Dart/Flutter philosophy
- ✅ **Compile-time safety** - errors caught at compile time, not runtime

### 🔧 API Improvements

#### Simplified ComputedProperty API
```dart
class UserViewModel extends ObservableObject {
  final firstName = ObservableProperty<String>('John');
  final lastName = ObservableProperty<String>('Doe');
  
  // New: Required parent parameter (positional)
  late final fullName = ComputedProperty<String>(
    () => '${firstName.value} ${lastName.value}',
    [firstName, lastName],
    this, // Required - automatic disposal when ViewModel is disposed
  );
}
```

### 📚 Documentation Updates

- Updated all examples to show required parent parameter
- Enhanced ComputedProperty documentation with memory leak prevention
- Updated README with new syntax
- Clarified when parent parameter is needed

### 🧪 Testing

- **442 tests** passing (unchanged)
- Updated 6 parent-child disposal tests
- Removed tests for optional parent behavior
- Added test for post-disposal protection

### 💡 Migration Guide

Update all `ComputedProperty` instances to include the parent parameter:

```dart
// Before (v1.1.0)
late final total = ComputedProperty<double>(
  () => subtotal.value + tax.value,
  [subtotal, tax],
);

// After (v1.1.1)
late final total = ComputedProperty<double>(
  () => subtotal.value + tax.value,
  [subtotal, tax],
  this, // Add parent parameter
);
```

This change applies to all ComputedProperty instances in your ViewModels. The compiler will catch any missing parameters, making migration straightforward.

---

## 1.1.0

**Lifecycle & Disposal Management Release** - Enhanced disposal safety, improved error handling, and better documentation.

This release focuses on robustness and developer experience with comprehensive improvements to lifecycle management across the framework. All components now provide clearer disposal semantics and better error messages.

### 🔄 Lifecycle & Disposal Improvements

#### Enhanced Disposal Safety
- **ObservableObject** now properly extends `ObservableNode` with improved lifecycle management
  - Clearer separation between internal API and public MVVM-style API
  - `clearListeners()` method added to `ObservableNode` for manual listener cleanup
  - Better disposal state tracking prevents operations on disposed objects
  - Enhanced error messages when attempting to use disposed ViewModels

#### FairyLocator Disposal Checks
- **Disposed ViewModel Detection**: `FairyLocator.get<T>()` now checks if ViewModels are disposed before returning
  - Throws informative `StateError` with guidance when accessing disposed ViewModels
  - Provides clear troubleshooting steps in error message
  - Recommends unregistering ViewModels after manual disposal
  - Helps catch lifecycle bugs early in development

Example error message:
```dart
StateError: ViewModel of type MyViewModel has been disposed and cannot be accessed.
This usually happens when:
1. ViewModel was manually disposed but not unregistered
2. App is shutting down
Consider unregistering disposed ViewModels:
  vm.dispose();
  FairyLocator.instance.unregister<MyViewModel>();
```

#### FairyScope Error Handling
- **Improved ViewModel Registration**: Enhanced error handling in `FairyScopeData`
  - Better tracking of owned ViewModels using List-based storage
  - Clearer error messages when ViewModel registration fails
  - Improved retrieval logic with better null safety
  - More robust disposal of scoped ViewModels

#### Disposable Mixin Refinement
- **Consolidated Disposal Logic**: Streamlined `Disposable` mixin implementation
  - Simplified state management with single `_isDisposed` flag
  - `throwIfDisposed()` provides consistent disposal checks
  - Better documentation with corrected class names in examples
  - Cleaner code with reduced redundancy

### 📚 Documentation Enhancements

#### ComputedProperty Documentation
- **Comprehensive Documentation**: Dramatically improved docs showing real-world value
  - "Why You'll Love It" section with before/after comparison
  - Real-world examples: Shopping cart, form validation, business logic
  - Key benefits highlighted with clear use cases
  - Performance notes explaining caching and optimization
  - Shows how ComputedProperty eliminates manual synchronization headaches

#### Code Comments
- **Slimmed Down**: Reduced verbose code comments while maintaining clarity
  - Follows Dart documentation standards
  - Focuses on essential information with concise examples
  - Links to comprehensive README for detailed examples
  - Better balance between inline docs and external documentation

### 🧪 Testing

- **436 tests** passing (up from 401)
- Added **35+ new disposal and lifecycle tests**:
  - FairyScopeData registration, retrieval, and disposal tests
  - FairyLocator disposal check tests
  - ObservableObject disposal state validation
  - Enhanced error handling tests
  - Comprehensive lifecycle edge case coverage

### 🔧 API Improvements

#### ObservableNode
- Added `clearListeners()` method for explicit listener cleanup
- Better error reporting during listener notification
- Consistent API across all observable types

#### Error Messages
- More informative error messages across the framework
- Actionable guidance in StateError exceptions
- Better troubleshooting information for common issues

### 📦 Breaking Changes

None - This is a backward-compatible enhancement release.

### 🎯 Migration Guide

No migration needed. All changes are internal improvements and additions that enhance existing functionality without breaking existing code.

### 💡 Developer Experience

This release significantly improves the debugging experience:
- Disposed ViewModels are caught early with clear error messages
- Better lifecycle tracking helps prevent memory leaks
- Improved documentation makes ComputedProperty's value crystal clear
- More comprehensive tests ensure reliability

---

## 1.0.0 🎉

**Stable Release** - A lightweight MVVM framework for Flutter with strongly-typed, reactive data binding.

This release consolidates all improvements from RC builds (rc.1, rc.2, rc.3) into a stable production-ready package.

### ✨ New Features

#### Async Command Execution State Tracking
- **`isRunning` property** added to async commands for automatic execution state tracking
  - **`AsyncRelayCommand.isRunning`**: Tracks execution state (true while running, false otherwise)
  - **`AsyncRelayCommandWithParam<T>.isRunning`**: Same behavior for parameterized async commands
  - **Automatic concurrent execution prevention**: `canExecute` returns `false` while `isRunning` is `true`
  - Eliminates need for manual loading state management
  - Prevents double-click bugs automatically
  - Enables easy loading indicators in UI

#### Command Widget API Enhancement
- **4th parameter `isRunning`** added to all Command builder signatures for consistency
  - **`Command<TViewModel>`**: Builder now receives `isRunning` (always `false` for sync commands)
  - **`Command.param<TViewModel, TParam>`**: Builder now receives `isRunning` (always `false` for sync commands)
  - Async commands return actual `isRunning` state from the command
  - Consistent API across all command types

#### Overlay ViewModel Bridging
- **`FairyBridge`**: New widget to bridge ViewModels to overlay widget trees
  - Solves the problem of dialogs, bottom sheets, and menus creating separate widget trees
  - Captures parent context's FairyScope and makes it available to overlay
  - Enables `Bind` and `Command` widgets to work seamlessly in overlays
  - Gracefully falls back to FairyLocator if no FairyScope found

#### UI Widgets API Enhancement
- **`Bind.viewModel<TViewModel>`**: Auto-tracking data binding for multiple properties
  - Eliminates need for manual selectors when displaying multiple properties
  - Automatically tracks all accessed properties and rebuilds only when they change
  - Achieves superior selective rebuild efficiency (100% accuracy)
  - 4-10% faster than competitors while maintaining perfect selectivity
- **`Command.param<TViewModel, TParam>`**: Factory constructor for parameterized commands
  - Provides consistent API alongside `Command<TViewModel>`
  - Simplifies parameterized command binding in UI
  - Completes the "Learn just 2 widgets" philosophy

#### Recursive Deep Equality for Collections
- **Built-in recursive deep equality** for all collection types without external dependencies
  - Automatically handles arbitrary nesting depth: `List<Map<String, List<int>>>`
  - Works with `List`, `Map`, `Set`, and `Iterable` at any level
  - Custom types use their `==` operator when nested in collections
  - **Zero configuration needed** - deep equality enabled by default
- **`Equals` utility class** for custom equality implementations
  - `Equals.deepCollectionEquals()` - Recursive equality for any collection type
  - `Equals.deepCollectionHash()` - Recursive hash code generation
  - Collection-specific methods: `listEquals`, `mapEquals`, `setEquals`
  - Hash methods: `listHash`, `mapHash`, `setHash`
- **`ObservableProperty.deepEquality`** parameter (default: `true`)
  - Primitive types use `==`, collections use deep equality automatically
  - Override `==` operator is **optional** for custom types

### 🔄 Breaking Changes

#### Command.param Parameter Type Change
- **BREAKING**: `Command.param` parameter changed from static `TParam` to function `TParam Function()`
  - **Reason**: Enables reactive parameter evaluation on rebuild
  - **Before**: `parameter: todoId,`
  - **After**: `parameter: () => todoId,`
  - For reactive controller values, wrap with `ValueListenableBuilder`

#### Command Builder Signature Update
- **BREAKING**: All Command builder signatures now include 4th `isRunning` parameter
  - **Before**: `builder: (context, execute, canExecute) { ... }`
  - **After**: `builder: (context, execute, canExecute, isRunning) { ... }`
  - Applies to both `Command<TViewModel>` and `Command.param<TViewModel, TParam>`
  - `isRunning` is always present but only meaningful for async commands (false for sync)

#### Removed Extensions
- **BREAKING**: Removed `ObservableObjectExtensions` for creating properties/commands
  - **Before**: `final counter = observableProperty<int>(0);`
  - **After**: `final counter = ObservableProperty<int>(0);`
  - **Reason**: Direct type usage is clearer, more discoverable, and follows Dart conventions
  - Replace all lowercase helpers (`observableProperty`, `computedProperty`, `relayCommand`, etc.) with direct constructors

#### Command Constructor Changes
- **BREAKING**: Removed `parent` parameter from all command constructors
  - **Before**: `RelayCommand(execute, parent: this, canExecute: ...)`
  - **After**: `RelayCommand(execute, canExecute: ...)`
  - **Reason**: Auto-disposal makes parent tracking unnecessary

### 🚀 Performance Improvements

Comprehensive benchmarks show exceptional performance achievements:
- **🥇 Memory Management**: Highly optimized cleanup and disposal system
- **🥇 Selective Rebuilds**: Exceptional performance with explicit `Bind` selectors
- **🥇 Auto-Binding Performance**: `Bind.viewModel` delivers superior speed while maintaining perfect selectivity
- **Unique Achievement**: 100% rebuild efficiency with `Bind.viewModel` - only rebuilds when accessed properties change
- Deep equality optimized with fast-path `identical()` checks and efficient recursive comparison

### 📚 Documentation

- Comprehensive "Learn just 2 widgets" positioning (`Bind` and `Command`)
- Added examples for all new features: `isRunning`, `FairyBridge`, `Bind.viewModel`, `Command.param`
- Updated all Command widget examples with 4th `isRunning` parameter
- Added ValueListenableBuilder pattern for reactive parameters
- Deep equality usage examples for collections and custom types
- Enhanced best practices section with memory leak warnings
- Complete API reference in llms.txt
- Added benchmark results demonstrating performance leadership

### 🧪 Testing

- **401 tests** passing with comprehensive coverage
- Tests for async command execution state tracking
- Tests for `FairyBridge` widget with overlay scenarios
- Tests for `Bind.viewModel` auto-tracking functionality
- Tests for `Command.param` factory constructor
- Tests for recursive deep equality (43 comprehensive tests)
- All breaking changes validated with updated tests

### 🎯 Framework Philosophy

- **"Learn just 2 widgets"**: `Bind` for data, `Command` for actions
- **No code generation**: Zero build_runner dependency
- **Type-safe**: Strong typing throughout the API
- **Automatic disposal**: No memory leaks with proper patterns
- **Zero external dependencies**: Only Flutter SDK required
- **Built-in deep equality**: No external packages needed

---

## 1.0.0-rc.3

### ✨ New Features

#### Async Command Execution State Tracking
- **`isRunning` property** added to async commands for automatic execution state tracking
  - **`AsyncRelayCommand.isRunning`**: Tracks execution state (true while running, false otherwise)
  - **`AsyncRelayCommandWithParam<T>.isRunning`**: Same behavior for parameterized async commands
  - **Automatic concurrent execution prevention**: `canExecute` returns `false` while `isRunning` is `true`
  - Eliminates need for manual loading state management
  - Prevents double-click bugs automatically
  - Enables easy loading indicators in UI

#### Command Widget API Enhancement
- **4th parameter `isRunning`** added to all Command builder signatures for consistency
  - **`Command<TViewModel>`**: Builder now receives `isRunning` (always `false` for sync commands)
  - **`Command.param<TViewModel, TParam>`**: Builder now receives `isRunning` (always `false` for sync commands)
  - Async commands return actual `isRunning` state from the command
  - Consistent API across all command types

```dart
// Async command with loading indicator
Command<DataViewModel>(
  command: (vm) => vm.fetchCommand,
  builder: (context, execute, canExecute, isRunning) {
    if (isRunning) return CircularProgressIndicator();
    return ElevatedButton(
      onPressed: execute,
      child: Text('Fetch Data'),
    );
  },
)

// Sync command (isRunning always false)
Command<TodoViewModel>(
  command: (vm) => vm.deleteCommand,
  builder: (context, execute, canExecute, isRunning) {
    return IconButton(
      onPressed: canExecute ? execute : null,
      icon: Icon(Icons.delete),
    );
  },
)
```

#### Overlay ViewModel Bridging
- **`FairyBridge`**: New widget to bridge ViewModels to overlay widget trees
  - Solves the problem of dialogs, bottom sheets, and menus creating separate widget trees
  - Captures parent context's FairyScope and makes it available to overlay
  - Enables `Bind` and `Command` widgets to work seamlessly in overlays
  - Gracefully falls back to FairyLocator if no FairyScope found

```dart
void _showDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => FairyBridge(
      context: context, // Makes parent FairyScope available
      child: AlertDialog(
        actions: [
          Command<MyViewModel>(
            command: (vm) => vm.saveCommand,
            builder: (ctx, execute, canExecute, isRunning) =>
              TextButton(onPressed: execute, child: Text('Save')),
          ),
        ],
      ),
    ),
  );
}
```

### 🔄 Breaking Changes

#### Command.param Parameter Type Change
- **BREAKING**: `Command.param` parameter changed from static `TParam` to function `TParam Function()`
  - **Reason**: Enables reactive parameter evaluation on rebuild
  - **Before**: `parameter: todoId,`
  - **After**: `parameter: () => todoId,`
  - For reactive controller values, wrap with `ValueListenableBuilder`:

```dart
// Before (static parameter - doesn't react to changes)
Command.param<TodoViewModel, String>(
  parameter: controller.text, // Static value
  builder: (context, execute, canExecute) { ... },
)

// After (reactive parameter)
ValueListenableBuilder<TextEditingValue>(
  valueListenable: controller,
  builder: (context, value, _) {
    return Command.param<TodoViewModel, String>(
      parameter: () => value.text, // Reactive to text changes
      builder: (context, execute, canExecute, isRunning) { ... },
    );
  },
)
```

#### Command Builder Signature Update
- **BREAKING**: All Command builder signatures now include 4th `isRunning` parameter
  - **Before**: `builder: (context, execute, canExecute) { ... }`
  - **After**: `builder: (context, execute, canExecute, isRunning) { ... }`
  - Applies to both `Command<TViewModel>` and `Command.param<TViewModel, TParam>`
  - `isRunning` is always present but only meaningful for async commands (false for sync)

### 🧪 Testing

- **401 tests** passing
- Updated 5 tests for new concurrent execution prevention behavior
- Added tests for `isRunning` state tracking
- Added tests for Command widget `isRunning` parameter

#### 📚 Documentation

- Added comprehensive examples for `isRunning` usage
- Added `FairyBridge` widget documentation and examples
- Updated all Command widget examples with 4th parameter
- Added ValueListenableBuilder pattern for reactive parameters
- Updated llms.txt with new API surface

---

## 1.0.0-rc.2

### ✨ New Features

#### Recursive Deep Equality for Collections
- **Built-in recursive deep equality** for all collection types without external dependencies
  - Automatically handles arbitrary nesting depth: `List<Map<String, List<int>>>`
  - Works with `List`, `Map`, `Set`, and `Iterable` at any level
  - Custom types use their `==` operator when nested in collections
  - **Zero configuration needed** - deep equality enabled by default

#### Equals Utility Class
- **`Equals.deepCollectionEquals(Object? e1, Object? e2)`**: Recursive equality for any collection type
- **`Equals.deepCollectionHash(Object? o)`**: Recursive hash code generation
- **Collection-specific methods**: `listEquals`, `mapEquals`, `setEquals` with deep comparison
- **Hash methods**: `listHash`, `mapHash`, `setHash` for consistent hash codes
- **`Equals.deepEquals<T>()`**: Factory method for `ObservableProperty` equality parameter

### 🔧 API Enhancements

#### ObservableProperty Deep Equality
- **`deepEquality: bool`** parameter (default: `true`) for automatic collection comparison
  - Primitive types: `ObservableProperty<int>(0)` - uses `==`
  - Collections: `ObservableProperty<List<int>>([1, 2, 3])` - uses deep equality
  - Custom types: Override `==` operator is **optional** (only needed for value-based equality)

### 📚 Developer Experience

#### Optional Equality Override
- **Simplified workflow**: No need to override `==` for custom types with collections
  - Collections are compared deeply automatically
  - Override `==` only if you want value-based equality instead of reference equality
  - Use `Equals` utilities in custom `==` implementations when overriding

```dart
// Works automatically without custom ==
final todos = ObservableProperty<List<String>>(['Task 1', 'Task 2']);
todos.value = ['Task 1', 'Task 2'];  // ✅ No rebuild - deep equality

// Custom type - override == is optional
class Project {
  final String name;
  final List<String> tasks;
  
  // OPTIONAL: Override for value-based equality
  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Project &&
      name == other.name &&
      Equals.listEquals(tasks, other.tasks);
}
```

### 🧪 Testing

- **387 tests** passing (up from 344)
- Added **43 comprehensive deep equality tests**:
  - Simple collections (List, Map, Set)
  - Nested structures with 2-3 levels of nesting
  - Mixed nested structures: `List<Map<String, List<int>>>`
  - Sets with nested lists
  - Custom types with and without equality overrides
  - Nested custom types containing collections
  - Performance and memory tests

### 🚀 Performance

- Deep equality optimized with fast-path `identical()` checks
- Recursive comparison with efficient callback pattern
- No performance impact on primitive types
- Benchmarks show excellent overall performance maintained

---

## 1.0.0-rc.1

### 🎉 Major Release Candidate

This release represents a major milestone with significant API improvements, enhanced performance, and comprehensive testing.

### ✨ New Features

#### UI Widgets API Enhancement
- **`Bind.viewModel<TViewModel>`**: New factory constructor for automatic property tracking
  - Eliminates need for manual selectors when displaying multiple properties
  - Automatically tracks all accessed properties and rebuilds only when they change
  - Achieves great selective rebuild efficiency over other state management solutions
  - 4-10% faster than competitors while maintaining perfect selectivity
- **`Command.param<TViewModel, TParam>`**: New factory constructor for parameterized commands
  - Provides consistent API alongside `Command<TViewModel>`
  - Simplifies parameterized command binding in UI
  - Completes the "2 widgets" framework positioning

### 🔄 Breaking Changes

#### Removed Extensions
- **BREAKING**: Removed `ObservableObjectExtensions` for creating properties/commands
  - **Before (Properties)**: `final counter = observableProperty<int>(0);`
  - **After (Properties)**: `final counter = ObservableProperty<int>(0);`
  - **Before (Commands)**: `late final saveCommand = relayCommand(_save);`
  - **After (Commands)**: `late final saveCommand = RelayCommand(_save);`
  - **Reason**: Direct type usage is clearer, more discoverable, and follows Dart conventions
  - **Migration**: Replace all `observableProperty<T>()` with `ObservableProperty<T>()`
  - **Migration**: Replace all `computedProperty<T>()` with `ComputedProperty<T>()`
  - **Migration**: Replace all command helpers (`relayCommand`, `asyncRelayCommand`, etc.) with direct constructors (`RelayCommand`, `AsyncRelayCommand`, etc.)

#### Command Constructor Changes
- **BREAKING**: Removed `parent` parameter from all command constructors
  - **Before**: `RelayCommand(execute, parent: this, canExecute: ...)`
  - **After**: `RelayCommand(execute, canExecute: ...)`
  - **Reason**: Auto-disposal makes parent tracking unnecessary
  - **Migration**: Remove `parent: this` from all command instantiations

### 🚀 Performance Improvements

Comprehensive benchmarks show significant performance achievements:
- **🥇 Memory Management**: Highly optimized cleanup and disposal system
- **🥇 Selective Rebuilds**: Exceptional performance with explicit `Bind` selectors
- **🥇 Auto-tracking Performance**: `Bind.viewModel` delivers superior speed while maintaining perfect selectivity
- **Unique Achievement**: 100% rebuild efficiency with `Bind.viewModel` - only rebuilds when accessed properties change

### 📚 Documentation Improvements

- Updated all examples to use direct type constructors
- Added comprehensive `Bind.viewModel` usage examples
- Added `Command.param` examples throughout documentation
- "2 widgets" framework (Learn just `Bind` and `Command`)
- Enhanced best practices section with memory leak warnings
- Added benchmark results to main README

### 🧪 Testing

- **344 tests** passing (up from 299)
- Added comprehensive tests for new `Bind.viewModel` functionality
- Added tests for `Command.param` factory constructor
- All existing functionality validated with updated API

### 📦 What's Next

The 1.0.0 stable release is planned after community feedback on this RC. Please report any issues or suggestions!

---

## 0.5.0+2

- Improved documentation and fixed minor typos.

## 0.5.0+1

- Improved documentation and fixed minor typos.

## 0.5.0

Initial release of Fairy - A lightweight MVVM framework for Flutter.

### Features

#### Core Primitives
- **ObservableObject**: Base ViewModel class with clean MVVM API
  - `onPropertyChanged()` for manual notifications
  - `propertyChanged(listener)` method returning disposer function
  - `setProperty<T>()` helper for batch updates with change detection
  - **Auto-disposal**: Properties created during construction are automatically disposed
- **ObservableProperty<T>**: Strongly-typed reactive properties
  - Automatic change notifications with custom equality support
  - `propertyChanged(listener)` for subscribing to property changes (returns disposer)
  - Auto-disposal when parent ObservableObject is disposed
- **ComputedProperty<T>**: Derived properties with automatic dependency tracking
  - Read-only computed values based on other properties
  - Automatic updates when dependencies change
  - Auto-disposal when parent ObservableObject is disposed

#### Commands
- **RelayCommand**: Synchronous commands with optional `canExecute` validation
- **AsyncRelayCommand**: Asynchronous commands with automatic `isRunning` state
- **RelayCommandWithParam<T>**: Parameterized commands for actions requiring input
- **AsyncRelayCommandWithParam<T>**: Async parameterized commands
- All commands use named parameters: `execute:`, `canExecute:`, `parent:`
- `notifyCanExecuteChanged()` method to re-evaluate `canExecute` conditions
- `canExecuteChanged(listener)` method for subscribing to `canExecute` changes (returns disposer function)

#### Dependency Injection
- **FairyLocator**: Global singleton registry for app-wide services
  - `registerSingleton<T>()` for singleton registration
  - `registerFactory<T>()` for factory registration
  - `get<T>()` for service resolution
  - `unregister<T>()` for cleanup
- **FairyScope**: Widget-scoped DI with automatic disposal
  - Scoped ViewModels auto-disposed when widget tree is removed
  - Supports both `create` and `instance` parameters
- **Fairy (ViewModelLocator)**: Unified resolution checking scope → global → exception
  - `Fairy.of<T>(context)`: Idiomatic Flutter API for resolving ViewModels (similar to `Provider.of`, `Theme.of`)
  - `Fairy.maybeOf<T>(context)`: Optional resolution returning `null` if not found

#### UI Binding
- **Bind<TViewModel, TValue>**: Automatic one-way/two-way binding detection
  - Returns `ObservableProperty<T>` → two-way binding with `update` callback
  - Returns raw `T` → one-way binding (read-only)
  - Type-safe selector/builder contracts
- **Command<TViewModel>**: Command binding with automatic `canExecute` reactivity
- **CommandWithParam<TViewModel, TParam>**: Parameterized command binding

#### Auto-Disposal System
- **Parent Parameter**: Properties, commands, and computed properties accept optional `parent` parameter
  - Pass `parent: this` in constructor to enable automatic disposal
  - Children are registered with parent and disposed automatically
  - Debug warnings shown when parent is not provided
  - Nested ObservableObject instances must be disposed manually

### Memory Management

- **Auto-disposal**: ObservableProperty, ComputedProperty, and Commands automatically disposed when `parent` parameter is provided
- **Nested ViewModels Exception**: Nested ObservableObject instances require manual disposal
- **Manual Listeners**: Always capture disposer from `propertyChanged()` and `canExecuteChanged()` calls to avoid memory leaks
- Use `Bind` and `Command` widgets for UI (automatic lifecycle management)

### Best Practices

- ⚠️ **Memory Leak Prevention**: Always capture disposer from manual `propertyChanged()` and `canExecuteChanged()` calls
- Pass `parent: this` to properties, commands, and computed properties for auto-disposal
- Nested ViewModels require explicit manual disposal
- Call `command.notifyCanExecuteChanged()` when `canExecute` dependencies change
- Use `command.canExecuteChanged(listener)` to listen to `canExecute` state changes
- Selectors must return stable property references
- Use `FairyScope` for page-level ViewModels (handles disposal automatically)
- Use named parameters for commands: `execute:`, `canExecute:`, `parent:`

### Documentation

- Comprehensive README with quick start guide
- Auto-disposal explanation and migration patterns
- Complete API reference with examples
- Example app demonstrating MVVM patterns

### Testing

- Comprehensive unit and widget tests with 100% passing rate
- Tests cover all core primitives, DI patterns, UI bindings, and auto-disposal
- Test structure mirrors library organization
