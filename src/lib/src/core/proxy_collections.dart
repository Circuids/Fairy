import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// A proxy list that intercepts mutating operations and triggers notifications.
///
/// This class wraps an underlying [List] and calls [_onChange] whenever a
/// mutating operation is performed. It extends [ListBase] to provide full
/// [List] API compatibility.
///
/// Used internally by [ObservableProperty] to enable mutation-level notifications
/// for list collections without requiring reassignment.
@internal
class ProxyList<E> extends ListBase<E> {
  /// Creates a proxy list wrapping the given [_inner] list.
  ///
  /// The [_onChange] callback is invoked after any mutating operation.
  ProxyList(this._inner, this._onChange);

  final List<E> _inner;
  final VoidCallback _onChange;

  /// Returns the underlying list (for internal use only).
  @protected
  List<E> get inner => _inner;

  // ========================================================================
  // NON-MUTATING OPERATIONS (delegate directly, no notification)
  // ========================================================================

  @override
  int get length => _inner.length;

  @override
  E operator [](int index) => _inner[index];

  // ========================================================================
  // MUTATING OPERATIONS (delegate + notify)
  // ========================================================================

  @override
  set length(int newLength) {
    if (_inner.length != newLength) {
      _inner.length = newLength;
      _onChange();
    }
  }

  @override
  void operator []=(int index, E value) {
    final oldValue = _inner[index];
    _inner[index] = value;
    if (oldValue != value) {
      _onChange();
    }
  }

  @override
  void add(E element) {
    _inner.add(element);
    _onChange();
  }

  @override
  void addAll(Iterable<E> iterable) {
    final oldLength = _inner.length;
    _inner.addAll(iterable);
    if (_inner.length != oldLength) {
      _onChange();
    }
  }

  @override
  void clear() {
    if (_inner.isNotEmpty) {
      _inner.clear();
      _onChange();
    }
  }

  @override
  bool remove(Object? element) {
    final result = _inner.remove(element);
    if (result) {
      _onChange();
    }
    return result;
  }

  @override
  E removeAt(int index) {
    final result = _inner.removeAt(index);
    _onChange();
    return result;
  }

  @override
  E removeLast() {
    final result = _inner.removeLast();
    _onChange();
    return result;
  }

  @override
  void removeRange(int start, int end) {
    if (start != end) {
      _inner.removeRange(start, end);
      _onChange();
    }
  }

  @override
  void removeWhere(bool Function(E element) test) {
    final oldLength = _inner.length;
    _inner.removeWhere(test);
    if (_inner.length != oldLength) {
      _onChange();
    }
  }

  @override
  void retainWhere(bool Function(E element) test) {
    final oldLength = _inner.length;
    _inner.retainWhere(test);
    if (_inner.length != oldLength) {
      _onChange();
    }
  }

  @override
  void insert(int index, E element) {
    _inner.insert(index, element);
    _onChange();
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    final oldLength = _inner.length;
    _inner.insertAll(index, iterable);
    if (_inner.length != oldLength) {
      _onChange();
    }
  }

  @override
  void setAll(int index, Iterable<E> iterable) {
    _inner.setAll(index, iterable);
    _onChange();
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    if (start != end) {
      _inner.setRange(start, end, iterable, skipCount);
      _onChange();
    }
  }

  @override
  void fillRange(int start, int end, [E? fill]) {
    if (start != end) {
      _inner.fillRange(start, end, fill);
      _onChange();
    }
  }

  @override
  void replaceRange(int start, int end, Iterable<E> newContents) {
    _inner.replaceRange(start, end, newContents);
    _onChange();
  }

  @override
  void shuffle([Random? random]) {
    if (_inner.length > 1) {
      _inner.shuffle(random);
      _onChange();
    }
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    if (_inner.length > 1) {
      _inner.sort(compare);
      _onChange();
    }
  }
}

/// A proxy map that intercepts mutating operations and triggers notifications.
///
/// This class wraps an underlying [Map] and calls [_onChange] whenever a
/// mutating operation is performed. It extends [MapBase] to provide full
/// [Map] API compatibility.
///
/// Used internally by [ObservableProperty] to enable mutation-level notifications
/// for map collections without requiring reassignment.
@internal
class ProxyMap<K, V> extends MapBase<K, V> {
  /// Creates a proxy map wrapping the given [_inner] map.
  ///
  /// The [_onChange] callback is invoked after any mutating operation.
  ProxyMap(this._inner, this._onChange);

  final Map<K, V> _inner;
  final VoidCallback _onChange;

  /// Returns the underlying map (for internal use only).
  @protected
  Map<K, V> get inner => _inner;

  // ========================================================================
  // NON-MUTATING OPERATIONS (delegate directly, no notification)
  // ========================================================================

  @override
  V? operator [](Object? key) => _inner[key];

  @override
  Iterable<K> get keys => _inner.keys;

  // ========================================================================
  // MUTATING OPERATIONS (delegate + notify)
  // ========================================================================

  @override
  void operator []=(K key, V value) {
    final hadKey = _inner.containsKey(key);
    final oldValue = hadKey ? _inner[key] : null;
    _inner[key] = value;
    if (!hadKey || oldValue != value) {
      _onChange();
    }
  }

  @override
  void clear() {
    if (_inner.isNotEmpty) {
      _inner.clear();
      _onChange();
    }
  }

  @override
  V? remove(Object? key) {
    if (_inner.containsKey(key)) {
      final result = _inner.remove(key);
      _onChange();
      return result;
    }
    return null;
  }

  @override
  void addAll(Map<K, V> other) {
    if (other.isNotEmpty) {
      _inner.addAll(other);
      _onChange();
    }
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    final oldLength = _inner.length;
    _inner.addEntries(newEntries);
    // Notify if any entries were added or updated
    if (_inner.length != oldLength || newEntries.isNotEmpty) {
      _onChange();
    }
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    if (!_inner.containsKey(key)) {
      final value = ifAbsent();
      _inner[key] = value;
      _onChange();
      return value;
    }
    return _inner[key] as V;
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final result = _inner.update(key, update, ifAbsent: ifAbsent);
    _onChange();
    return result;
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    if (_inner.isNotEmpty) {
      _inner.updateAll(update);
      _onChange();
    }
  }

  @override
  void removeWhere(bool Function(K key, V value) test) {
    final oldLength = _inner.length;
    _inner.removeWhere(test);
    if (_inner.length != oldLength) {
      _onChange();
    }
  }
}

/// A proxy set that intercepts mutating operations and triggers notifications.
///
/// This class wraps an underlying [Set] and calls [_onChange] whenever a
/// mutating operation is performed. It extends [SetBase] to provide full
/// [Set] API compatibility.
///
/// Used internally by [ObservableProperty] to enable mutation-level notifications
/// for set collections without requiring reassignment.
@internal
class ProxySet<E> extends SetBase<E> {
  /// Creates a proxy set wrapping the given [_inner] set.
  ///
  /// The [_onChange] callback is invoked after any mutating operation.
  ProxySet(this._inner, this._onChange);

  final Set<E> _inner;
  final VoidCallback _onChange;

  /// Returns the underlying set (for internal use only).
  @protected
  Set<E> get inner => _inner;

  // ========================================================================
  // NON-MUTATING OPERATIONS (delegate directly, no notification)
  // ========================================================================

  @override
  int get length => _inner.length;

  @override
  bool contains(Object? element) => _inner.contains(element);

  @override
  Iterator<E> get iterator => _inner.iterator;

  @override
  E? lookup(Object? element) => _inner.lookup(element);

  @override
  Set<E> toSet() => Set<E>.of(_inner);

  // ========================================================================
  // MUTATING OPERATIONS (delegate + notify)
  // ========================================================================

  @override
  bool add(E value) {
    final result = _inner.add(value);
    if (result) {
      _onChange();
    }
    return result;
  }

  @override
  void addAll(Iterable<E> elements) {
    final oldLength = _inner.length;
    _inner.addAll(elements);
    if (_inner.length != oldLength) {
      _onChange();
    }
  }

  @override
  void clear() {
    if (_inner.isNotEmpty) {
      _inner.clear();
      _onChange();
    }
  }

  @override
  bool remove(Object? value) {
    final result = _inner.remove(value);
    if (result) {
      _onChange();
    }
    return result;
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    final oldLength = _inner.length;
    _inner.removeAll(elements);
    if (_inner.length != oldLength) {
      _onChange();
    }
  }

  @override
  void removeWhere(bool Function(E element) test) {
    final oldLength = _inner.length;
    _inner.removeWhere(test);
    if (_inner.length != oldLength) {
      _onChange();
    }
  }

  @override
  void retainAll(Iterable<Object?> elements) {
    final oldLength = _inner.length;
    _inner.retainAll(elements);
    if (_inner.length != oldLength) {
      _onChange();
    }
  }

  @override
  void retainWhere(bool Function(E element) test) {
    final oldLength = _inner.length;
    _inner.retainWhere(test);
    if (_inner.length != oldLength) {
      _onChange();
    }
  }
}
