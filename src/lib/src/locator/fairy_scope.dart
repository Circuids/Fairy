import 'package:fairy/src/internal/fairy_scope_data.dart';
import 'package:fairy/src/internal/fairy_scope_locator.dart';
import 'package:flutter/widgets.dart';

import '../core/observable.dart';
import 'fairy_locator.dart';

/// Describes how a ViewModel should be created and registered within a
/// [FairyScope].
///
/// Use [ViewModelFactory] to declare ViewModels in [FairyScope.viewModels].
///
/// ViewModels are **lazy by default** — they are not instantiated until first
/// accessed via [Bind], [Command], or [Fairy.of].  This reduces startup memory
/// usage and avoids constructing ViewModels for routes that may never be
/// visited.
///
/// Use [ViewModelFactory.eager] to force immediate instantiation when the scope
/// mounts (e.g. for ViewModels that kick off background work or must register
/// themselves globally at startup).
///
/// **Dependency injection** — The factory receives a [FairyScopeLocator] that
/// can resolve services from [FairyLocator] and ViewModels from any ancestor
/// [FairyScope].  The locator remains valid for the lifetime of the scope, so
/// lazy factories can safely use it when they are finally invoked.
///
/// Example:
/// ```dart
/// FairyScope(
///   viewModels: [
///     // Lazy (default) — created on first Bind/Command access
///     ViewModelFactory((_) => CounterViewModel()),
///
///     // Lazy with dependency injection
///     ViewModelFactory((locator) => UserViewModel(
///       api: locator.get<ApiService>(),
///       appVm: locator.get<AppViewModel>(), // from parent FairyScope
///     )),
///
///     // Eager — created immediately when the scope mounts
///     ViewModelFactory.eager((_) => AnalyticsViewModel()),
///   ],
///   child: MyPage(),
/// )
/// ```
class ViewModelFactory<T extends ObservableObject> {
  /// The factory function that creates the ViewModel.
  ///
  /// The [FairyScopeLocator] allows resolving dependencies from ancestor
  /// scopes and [FairyLocator] at the time the ViewModel is created.
  final T Function(FairyScopeLocator locator) create;

  /// Whether the ViewModel is created on first access (`true`, default) or
  /// immediately when the [FairyScope] mounts (`false`).
  final bool lazy;

  /// Creates a lazy ViewModel factory.
  ///
  /// The ViewModel is instantiated on first access via [Bind], [Command],
  /// or [Fairy.of].
  const ViewModelFactory(this.create, {this.lazy = true});

  /// Creates an eager ViewModel factory.
  ///
  /// The ViewModel is instantiated immediately when the [FairyScope] mounts.
  /// Use this when the ViewModel must run initialisation side-effects at
  /// scope-mount time (e.g. starting background tasks, subscribing to streams).
  const ViewModelFactory.eager(this.create) : lazy = false;

  /// Registers this ViewModel in [data], using [locator] for dependency
  /// resolution and [autoDispose] to decide ownership.
  ///
  /// This method is library-private; it is called exclusively from
  /// [_FairyScopeState.initState].
  void _registerOn(
    FairyScopeData data,
    FairyScopeLocator locator,
    bool autoDispose,
  ) {
    if (lazy) {
      // Register a lazy factory; instantiation is deferred until first get<T>().
      data.registerLazy(T, () => create(locator), owned: autoDispose);
    } else {
      // Eager: create now and register by runtime type.
      final instance = create(locator);
      data.registerDynamic(instance, owned: autoDispose);
    }
  }
}

/// Provides access to dependencies during ViewModel construction.
///
/// A [FairyScopeLocator] is passed to each [ViewModelFactory.create] function
/// and remains valid for the entire lifetime of the owning [FairyScope].
/// This means **lazy** factories can call [get] when they are finally invoked
/// (which may be well after scope mount time).
///
/// Resolution order for [get]:
/// 1. ViewModels already registered in the current [FairyScope] (eager and
///    already-materialised lazy VMs)
/// 2. ViewModels in ancestor [FairyScope] widgets (nearest first), including
///    lazy VMs that are materialised on demand
/// 3. Global services registered in [FairyLocator]
///
/// **Important:** Do not use the locator after the owning [FairyScope] has
/// been removed from the widget tree — it will be invalidated at that point
/// and [get] will throw a [StateError].
///
/// Example:
/// ```dart
/// FairyScope(
///   viewModels: [
///     ViewModelFactory((locator) => CounterViewModel(
///       apiService: locator.get<ApiService>(),    // From FairyLocator
///       appVm:      locator.get<AppViewModel>(),  // From parent FairyScope
///     )),
///   ],
///   child: CounterPage(),
/// )
/// ```
abstract class FairyScopeLocator {
  /// Resolves a dependency of type [T].
  ///
  /// Throws [StateError] if no dependency of type [T] is found, or if the
  /// locator has been invalidated (i.e. the owning scope was disposed).
  T get<T extends Object>();
}

/// A widget that provides scoped dependency injection for ViewModels.
///
/// [FairyScope] creates a widget subtree where ViewModels declared in
/// [viewModels] are available to descendants via [FairyScope.of],
/// [Bind], and [Command] widgets.
///
/// **Key Features:**
/// - **Lazy by default** — ViewModels are not instantiated until first
///   accessed, reducing startup memory and time.
/// - **Eager opt-in** — Use [ViewModelFactory.eager] for ViewModels that
///   must run side-effects at scope-mount time.
/// - **Scoped lifecycle** — ViewModels are automatically disposed when the
///   scope is removed from the tree (when [autoDispose] is `true`).
/// - **Dependency injection** — [ViewModelFactory] functions receive a
///   [FairyScopeLocator] valid for the scope's lifetime so lazy factories
///   can resolve dependencies at creation time.
/// - **Hierarchical resolution** — Access parent-scope VMs and global
///   services transparently.
///
/// Example with a single ViewModel (lazy, no dependencies):
/// ```dart
/// FairyScope(
///   viewModels: [ViewModelFactory((_) => CounterViewModel())],
///   child: CounterPage(),
/// )
/// ```
///
/// Example with multiple ViewModels and injection:
/// ```dart
/// FairyScope(
///   viewModels: [
///     ViewModelFactory((_) => UserViewModel()),
///     ViewModelFactory((locator) => DashboardViewModel(
///       user: locator.get<UserViewModel>(),
///     )),
///   ],
///   child: DashboardPage(),
/// )
/// ```
class FairyScope extends StatefulWidget {
  /// The widget subtree that can access the scoped ViewModels.
  final Widget child;

  /// Ordered list of [ViewModelFactory] descriptors.
  ///
  /// Factories are registered in list order.  Later factories can use the
  /// [FairyScopeLocator] to depend on ViewModels from earlier entries in the
  /// same list (even when those are lazy, because the locator materialises
  /// them on demand).
  ///
  /// Defaults to an empty list (no ViewModels).
  final List<ViewModelFactory> viewModels;

  /// Whether to automatically dispose ViewModels owned by this scope when it
  /// is removed from the widget tree.
  ///
  /// Defaults to `true`.  Set to `false` only when the ViewModels' lifecycle
  /// is managed externally (e.g. they are also registered in [FairyLocator]).
  final bool autoDispose;

  const FairyScope({
    super.key,
    required this.child,
    this.viewModels = const [],
    this.autoDispose = true,
  });

  /// Retrieves the [FairyScopeData] from the nearest [FairyScope] ancestor.
  ///
  /// Returns `null` if no [FairyScope] is found in the widget tree.
  ///
  /// Example:
  /// ```dart
  /// final scopeData = FairyScope.of(context);
  /// if (scopeData != null && scopeData.contains<MyViewModel>()) {
  ///   final vm = scopeData.get<MyViewModel>();
  /// }
  /// ```
  static FairyScopeData? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FairyScopeInherited>()?.data;

  @override
  State<FairyScope> createState() => _FairyScopeState();
}

class _FairyScopeState extends State<FairyScope> {
  late final FairyScopeData _data;
  late final FairyScopeLocatorImpl _locator;

  @override
  void initState() {
    super.initState();
    _data = FairyScopeData();

    // Pre-collect parent scopes ONCE during initialisation to avoid repeated
    // tree traversal on every get<T>() call.
    final List<FairyScopeData> parentScopes = [];
    context.visitAncestorElements((ancestor) {
      if (ancestor.widget is _FairyScopeInherited) {
        final scopeData = (ancestor.widget as _FairyScopeInherited).data;
        // Safety: exclude the current scope (should not occur, but defensive).
        if (scopeData != _data) {
          parentScopes.add(scopeData);
        }
      }
      return true; // Continue visiting all ancestors
    });

    // Build the locator without holding a BuildContext reference (memory safe).
    _locator = FairyScopeLocatorImpl(_data, parentScopes);

    // Register all ViewModels.  Lazy ones register a deferred factory;
    // eager ones are instantiated immediately.
    for (final factory in widget.viewModels) {
      factory._registerOn(_data, _locator, widget.autoDispose);
    }

    // NOTE: The locator is intentionally NOT invalidated here.
    // Lazy ViewModelFactory.create functions capture the locator and may call
    // locator.get<T>() when the ViewModel is first accessed — which happens
    // during the build phase, long after initState completes.
    // The locator is invalidated in dispose() instead.
  }

  @override
  void dispose() {
    // Invalidate the locator first so any post-disposal accesses throw clearly.
    _locator.invalidate();
    // Then dispose owned ViewModels (clears registry and lazy factories).
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FairyScopeInherited(
        data: _data,
        child: widget.child,
      );
}

/// InheritedWidget that provides [FairyScopeData] to the widget tree.
class _FairyScopeInherited extends InheritedWidget {
  const _FairyScopeInherited({
    required this.data,
    required super.child,
  });
  final FairyScopeData data;

  @override
  bool updateShouldNotify(_FairyScopeInherited old) => false;
}
