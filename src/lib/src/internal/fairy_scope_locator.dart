import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/internal/fairy_scope_data.dart';
import 'package:fairy/src/locator/fairy_locator.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:flutter/foundation.dart';

/// Internal implementation of [FairyScopeLocator].
///
/// **Performance:** Uses a three-tier hybrid approach:
/// 1. Current scope — O(1) direct lookup; also materialises lazy factories
///    so sequential intra-scope dependencies work at any point.
/// 2. Flattened parent map — O(1) lookup for already-materialised parent VMs.
///    Populated at construction and updated lazily as new parent VMs are
///    materialised, so subsequent accesses remain O(1).
/// 3. Parent scope list scan — O(n) fallback used only when a parent has a
///    lazy VM that has not been materialised yet; the result is cached in the
///    flat map so the path is never taken twice for the same type.
///
/// **Memory Safety:** Uses weak references in the flat map to prevent
/// retention of disposed parent-scope VMs.  The `_parentScopes` list holds
/// strong references to [FairyScopeData] instances which are owned by their
/// respective [FairyScope] widgets; they are released when those widgets are
/// removed from the tree.
///
/// **Lifetime:** The locator is valid for the entire lifetime of its owning
/// [FairyScope].  It is invalidated in [FairyScope.dispose] so that any
/// stored references throw a clear error after the scope is removed.
@internal
class FairyScopeLocatorImpl implements FairyScopeLocator {
  final FairyScopeData _currentScopeData;

  /// Flat map of already-materialised parent VMs — O(1) lookup path.
  final Map<Type, WeakReference<ObservableObject>> _flattenedParents;

  /// Ordered list of parent [FairyScopeData] instances (nearest first).
  /// Kept to resolve lazy parent VMs that are not yet in [_flattenedParents].
  final List<FairyScopeData> _parentScopes;

  bool _isValid = true;

  FairyScopeLocatorImpl(
    this._currentScopeData,
    List<FairyScopeData> parentScopes,
  )   : _flattenedParents = _flattenEagerParents(parentScopes),
        // Store as unmodifiable copy; references are already stable.
        _parentScopes = List.unmodifiable(parentScopes);

  /// Builds the initial flat map from already-materialised (eager) parent VMs.
  ///
  /// Processes from farthest to nearest so the nearest parent wins on
  /// type conflicts.
  static Map<Type, WeakReference<ObservableObject>> _flattenEagerParents(
    List<FairyScopeData> parentScopes,
  ) {
    final flattened = <Type, WeakReference<ObservableObject>>{};
    for (final parentData in parentScopes.reversed) {
      for (final entry in parentData.registry.entries) {
        flattened[entry.key] = WeakReference<ObservableObject>(entry.value);
      }
    }
    return flattened;
  }

  /// Invalidates this locator.
  ///
  /// Called by [FairyScopeState.dispose] when the owning scope is removed
  /// from the widget tree.  After invalidation, [get] throws a descriptive
  /// [StateError].
  void invalidate() {
    _isValid = false;
  }

  @override
  T get<T extends Object>() {
    assert(_isValid, 'FairyScopeLocator used after its FairyScope was disposed');

    if (!_isValid) {
      throw StateError(
        'FairyScopeLocator can only be used while its FairyScope is active.\n'
        'Do not use the locator after the scope has been removed from the widget tree.\n'
        '\n'
        'This most commonly happens when a ViewModel stores the locator and\n'
        'calls get<T>() after the scope has been disposed.\n'
        '\n'
        'If you need lazy dependency resolution, access the locator only\n'
        'from within your ViewModelFactory create function.',
      );
    }

    // 1. Check current scope — handles both eager and lazy VMs (O(1)).
    //    getByType materialises lazy factories, enabling sequential
    //    intra-scope dependencies.
    final currentResult = _currentScopeData.getByType(T);
    if (currentResult != null) {
      return currentResult as T;
    }

    // 2. Check flattened parent map for already-materialised VMs (O(1)).
    final parentWeakRef = _flattenedParents[T];
    if (parentWeakRef != null) {
      final parentResult = parentWeakRef.target;
      if (parentResult != null) {
        return parentResult as T;
      }
      // Weak reference was collected — remove stale entry and fall through.
      _flattenedParents.remove(T);
    }

    // 3. Scan parent scopes for lazy VMs not yet in the flat map (O(n)).
    //    Nearest parent is checked first (list is nearest-first).
    for (final parentData in _parentScopes) {
      if (parentData.containsByType(T)) {
        final result = parentData.getByType(T)!; // materialises if lazy
        // Cache in flat map so future lookups are O(1).
        _flattenedParents[T] = WeakReference(result);
        return result as T;
      }
    }

    // 4. Fall back to global FairyLocator.
    try {
      return FairyLocator.get<T>();
    } catch (e) {
      throw StateError(
        'No dependency of type $T found in FairyScope hierarchy or FairyLocator.\n'
        'Make sure to:\n'
        '1. Register services with FairyLocator.registerSingleton<$T>(...)\n'
        '2. Or provide ViewModels via parent FairyScope widgets',
      );
    }
  }
}
