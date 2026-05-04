import 'package:fairy/src/core/observable.dart';
import 'package:flutter/foundation.dart';

/// Entry combining ViewModel instance with ownership tracking.
/// Eliminates double map lookups during disposal.
class _VMEntry {
  final ObservableObject instance;
  final bool owned;

  _VMEntry(this.instance, this.owned);
}

/// Pairs a lazy factory with its ownership flag so disposal respects autoDispose.
typedef _LazyEntry = ({ObservableObject Function() factory, bool owned});

/// Data holder for managing scoped ViewModels within a [FairyScope].
///
/// This class maintains a local registry of ViewModels and tracks which ones
/// were created by the scope (and therefore should be disposed by it).
///
/// **Internal API:** This class is intended for internal use by FairyScope only.
/// Do not use it directly in application code.
@internal
class FairyScopeData {
  final Map<Type, _VMEntry> _registry = {};
  final Map<Type, _LazyEntry> _lazyFactories = {};

  /// Exposed for backward compatibility - returns just the instances
  Map<Type, ObservableObject> get registry {
    return Map.fromEntries(
      _registry.entries.map((e) => MapEntry(e.key, e.value.instance)),
    );
  }

  /// Registers a ViewModel instance of type [T].
  ///
  /// [owned] indicates whether this scope created the instance and is
  /// responsible for disposing it.
  ///
  /// Throws [StateError] if a ViewModel of type [T] is already registered.
  void register<T extends ObservableObject>(T instance, {bool owned = false}) {
    if (_registry.containsKey(T)) {
      throw StateError(
        'ViewModel of type $T is already registered in this FairyScope.\n'
        'Each scope can only contain one instance of each ViewModel type.\n'
        'If you need multiple instances, use different ViewModel classes.',
      );
    }
    _registry[T] = _VMEntry(instance, owned);
  }

  /// Registers a ViewModel instance using its runtime type.
  ///
  /// This is useful when iterating over a list of ViewModels where the
  /// compile-time type is not available.
  ///
  /// Throws [StateError] if a ViewModel of this type is already registered.
  void registerDynamic(ObservableObject instance, {bool owned = false}) {
    final type = instance.runtimeType;
    if (_registry.containsKey(type)) {
      throw StateError(
        'ViewModel of type $type is already registered in this FairyScope.\n'
        'Each scope can only contain one instance of each ViewModel type.\n'
        'If you need multiple instances, use different ViewModel classes.',
      );
    }
    _registry[type] = _VMEntry(instance, owned);
  }

  /// Registers a lazy ViewModel factory.
  ///
  /// The ViewModel will be created on first access via [get] or [getByType].
  /// The [owned] flag controls whether the scope disposes the ViewModel when
  /// it is removed — this mirrors [FairyScope.autoDispose].
  void registerLazy(
    Type type,
    ObservableObject Function() factory, {
    bool owned = true,
  }) {
    if (_registry.containsKey(type) || _lazyFactories.containsKey(type)) {
      throw StateError(
        'ViewModel of type $type is already registered in this FairyScope.\n'
        'Each scope can only contain one instance of each ViewModel type.\n'
        'If you need multiple instances, use different ViewModel classes.',
      );
    }
    _lazyFactories[type] = (factory: factory, owned: owned);
  }

  /// Retrieves a ViewModel of type [T].
  ///
  /// If the ViewModel was registered as lazy, it will be created on first access.
  /// Throws [StateError] if no ViewModel of type [T] is registered.
  T get<T extends ObservableObject>() {
    // Materialize lazy factory on first access
    if (_lazyFactories.containsKey(T)) {
      final entry = _lazyFactories[T]!;
      final instance = entry.factory();
      _registry[T] = _VMEntry(instance, entry.owned);
      _lazyFactories.remove(T);
    }

    if (!_registry.containsKey(T)) {
      throw StateError('No ViewModel of type $T found in FairyScope');
    }
    final entry = _registry[T]!;
    final instance = entry.instance;

    if (instance.isDisposed) {
      throw StateError(
        'ViewModel of type $T has been disposed and cannot be accessed.\n'
        'This usually happens when:\n'
        '1. FairyScope was removed from the widget tree\n'
        '2. ViewModel was manually disposed\n'
        '3. Widget is trying to access VM during disposal phase',
      );
    }
    return instance as T;
  }

  /// Checks if a ViewModel of type [T] is registered (either eager or lazy).
  bool contains<T extends ObservableObject>() =>
      _registry.containsKey(T) || _lazyFactories.containsKey(T);

  /// Type-erased containment check (works for any [Type] value, not just
  /// generic-bound [T]).
  ///
  /// Used by [FairyScopeLocatorImpl] which accepts `Object`-bounded type
  /// parameters and needs to check both eager and lazy registrations.
  @internal
  bool containsByType(Type type) =>
      _registry.containsKey(type) || _lazyFactories.containsKey(type);

  /// Type-erased get that materializes lazy factories on first access.
  ///
  /// Returns the ViewModel instance for [type], or `null` if not found.
  /// Used by [FairyScopeLocatorImpl] for cross-type-bound lazy resolution.
  @internal
  ObservableObject? getByType(Type type) {
    // Materialize lazy factory if present
    if (_lazyFactories.containsKey(type)) {
      final lazyEntry = _lazyFactories[type]!;
      final instance = lazyEntry.factory();
      _registry[type] = _VMEntry(instance, lazyEntry.owned);
      _lazyFactories.remove(type);
    }

    final registryEntry = _registry[type];
    if (registryEntry == null) return null;

    if (registryEntry.instance.isDisposed) {
      throw StateError(
        'ViewModel of type $type has been disposed and cannot be accessed.\n'
        'This usually happens when:\n'
        '1. FairyScope was removed from the widget tree\n'
        '2. ViewModel was manually disposed\n'
        '3. Widget is trying to access VM during disposal phase',
      );
    }
    return registryEntry.instance;
  }

  /// Disposes all ViewModels that this scope owns.
  ///
  /// Only disposes ViewModels that were created by this scope (marked as owned).
  /// ViewModels are disposed in reverse registration order (LIFO - last in, first out).
  void dispose() {
    // Dispose in reverse order - single pass, no double lookups
    final entries = _registry.entries.toList();
    for (var i = entries.length - 1; i >= 0; i--) {
      final entry = entries[i].value;
      if (entry.owned && !entry.instance.isDisposed) {
        entry.instance.dispose();
      }
    }
    _registry.clear();
    _lazyFactories.clear();
  }
}
