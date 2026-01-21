import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';

void main() {
  group('Proxy-Based Mutation Notifications', () {
    group('ObservableProperty.list', () {
      group('mutating operations trigger notifications', () {
        test('add() triggers notification', () {
          final prop = ObservableProperty.list<String>(['a', 'b']);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.add('c');

          expect(notifyCount, 1);
          expect(prop.value, ['a', 'b', 'c']);
        });

        test('addAll() triggers notification when items added', () {
          final prop = ObservableProperty.list<int>([1]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.addAll([2, 3, 4]);

          expect(notifyCount, 1);
          expect(prop.value, [1, 2, 3, 4]);
        });

        test('addAll() does not trigger when empty iterable', () {
          final prop = ObservableProperty.list<int>([1, 2]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.addAll([]);

          expect(notifyCount, 0);
        });

        test('remove() triggers notification when item removed', () {
          final prop = ObservableProperty.list<String>(['a', 'b', 'c']);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final removed = prop.value.remove('b');

          expect(removed, true);
          expect(notifyCount, 1);
          expect(prop.value, ['a', 'c']);
        });

        test('remove() does not trigger when item not found', () {
          final prop = ObservableProperty.list<String>(['a', 'b']);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final removed = prop.value.remove('z');

          expect(removed, false);
          expect(notifyCount, 0);
        });

        test('removeAt() triggers notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final removed = prop.value.removeAt(1);

          expect(removed, 2);
          expect(notifyCount, 1);
          expect(prop.value, [1, 3]);
        });

        test('removeLast() triggers notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final removed = prop.value.removeLast();

          expect(removed, 3);
          expect(notifyCount, 1);
          expect(prop.value, [1, 2]);
        });

        test('removeRange() triggers notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3, 4, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.removeRange(1, 4);

          expect(notifyCount, 1);
          expect(prop.value, [1, 5]);
        });

        test('removeWhere() triggers notification when items removed', () {
          final prop = ObservableProperty.list<int>([1, 2, 3, 4, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.removeWhere((e) => e.isEven);

          expect(notifyCount, 1);
          expect(prop.value, [1, 3, 5]);
        });

        test('removeWhere() does not trigger when no items match', () {
          final prop = ObservableProperty.list<int>([1, 3, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.removeWhere((e) => e.isEven);

          expect(notifyCount, 0);
        });

        test('retainWhere() triggers notification when items removed', () {
          final prop = ObservableProperty.list<int>([1, 2, 3, 4, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.retainWhere((e) => e.isOdd);

          expect(notifyCount, 1);
          expect(prop.value, [1, 3, 5]);
        });

        test('clear() triggers notification when not empty', () {
          final prop = ObservableProperty.list<String>(['a', 'b']);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.clear();

          expect(notifyCount, 1);
          expect(prop.value, isEmpty);
        });

        test('clear() does not trigger when already empty', () {
          final prop = ObservableProperty.list<String>([]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.clear();

          expect(notifyCount, 0);
        });

        test('[]= triggers notification when value changes', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value[1] = 99;

          expect(notifyCount, 1);
          expect(prop.value, [1, 99, 3]);
        });

        test('[]= does not trigger when value is the same', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value[1] = 2; // Same value

          expect(notifyCount, 0);
        });

        test('length= triggers notification when length changes', () {
          final prop = ObservableProperty.list<int?>([1, 2, 3, 4, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.length = 3;

          expect(notifyCount, 1);
          expect(prop.value, [1, 2, 3]);
        });

        test('insert() triggers notification', () {
          final prop = ObservableProperty.list<int>([1, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.insert(1, 2);

          expect(notifyCount, 1);
          expect(prop.value, [1, 2, 3]);
        });

        test('insertAll() triggers notification', () {
          final prop = ObservableProperty.list<int>([1, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.insertAll(1, [2, 3, 4]);

          expect(notifyCount, 1);
          expect(prop.value, [1, 2, 3, 4, 5]);
        });

        test('setAll() triggers notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3, 4]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.setAll(1, [8, 9]);

          expect(notifyCount, 1);
          expect(prop.value, [1, 8, 9, 4]);
        });

        test('setRange() triggers notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3, 4, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.setRange(1, 4, [7, 8, 9]);

          expect(notifyCount, 1);
          expect(prop.value, [1, 7, 8, 9, 5]);
        });

        test('fillRange() triggers notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3, 4, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.fillRange(1, 4, 0);

          expect(notifyCount, 1);
          expect(prop.value, [1, 0, 0, 0, 5]);
        });

        test('replaceRange() triggers notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3, 4, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.replaceRange(1, 4, [99]);

          expect(notifyCount, 1);
          expect(prop.value, [1, 99, 5]);
        });

        test('sort() triggers notification', () {
          final prop = ObservableProperty.list<int>([3, 1, 4, 1, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.sort();

          expect(notifyCount, 1);
          expect(prop.value, [1, 1, 3, 4, 5]);
        });

        test('shuffle() triggers notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3, 4, 5]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.shuffle();

          expect(notifyCount, 1);
        });
      });

      group('non-mutating operations do not trigger notifications', () {
        test('[] does not trigger notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final value = prop.value[1];

          expect(value, 2);
          expect(notifyCount, 0);
        });

        test('length getter does not trigger notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final length = prop.value.length;

          expect(length, 3);
          expect(notifyCount, 0);
        });

        test('contains() does not trigger notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final contains = prop.value.contains(2);

          expect(contains, true);
          expect(notifyCount, 0);
        });

        test('first does not trigger notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final first = prop.value.first;

          expect(first, 1);
          expect(notifyCount, 0);
        });

        test('last does not trigger notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final last = prop.value.last;

          expect(last, 3);
          expect(notifyCount, 0);
        });

        test('isEmpty does not trigger notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final isEmpty = prop.value.isEmpty;

          expect(isEmpty, false);
          expect(notifyCount, 0);
        });

        test('indexOf() does not trigger notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final index = prop.value.indexOf(2);

          expect(index, 1);
          expect(notifyCount, 0);
        });

        test('where() does not trigger notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3, 4]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final evens = prop.value.where((e) => e.isEven).toList();

          expect(evens, [2, 4]);
          expect(notifyCount, 0);
        });

        test('map() does not trigger notification', () {
          final prop = ObservableProperty.list<int>([1, 2, 3]);
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final doubled = prop.value.map((e) => e * 2).toList();

          expect(doubled, [2, 4, 6]);
          expect(notifyCount, 0);
        });
      });
    });

    group('ObservableProperty.map', () {
      group('mutating operations trigger notifications', () {
        test('[]= triggers notification for new key', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value['b'] = 2;

          expect(notifyCount, 1);
          expect(prop.value, {'a': 1, 'b': 2});
        });

        test('[]= triggers notification when value changes', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value['a'] = 99;

          expect(notifyCount, 1);
          expect(prop.value, {'a': 99});
        });

        test('[]= does not trigger when value is the same', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value['a'] = 1; // Same value

          expect(notifyCount, 0);
        });

        test('remove() triggers notification when key exists', () {
          final prop = ObservableProperty.map<String, int>({'a': 1, 'b': 2});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final removed = prop.value.remove('a');

          expect(removed, 1);
          expect(notifyCount, 1);
          expect(prop.value, {'b': 2});
        });

        test('remove() does not trigger when key does not exist', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final removed = prop.value.remove('z');

          expect(removed, null);
          expect(notifyCount, 0);
        });

        test('clear() triggers notification when not empty', () {
          final prop = ObservableProperty.map<String, int>({'a': 1, 'b': 2});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.clear();

          expect(notifyCount, 1);
          expect(prop.value, isEmpty);
        });

        test('clear() does not trigger when already empty', () {
          final prop = ObservableProperty.map<String, int>({});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.clear();

          expect(notifyCount, 0);
        });

        test('addAll() triggers notification', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.addAll({'b': 2, 'c': 3});

          expect(notifyCount, 1);
          expect(prop.value, {'a': 1, 'b': 2, 'c': 3});
        });

        test('putIfAbsent() triggers notification for new key', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final value = prop.value.putIfAbsent('b', () => 2);

          expect(value, 2);
          expect(notifyCount, 1);
          expect(prop.value, {'a': 1, 'b': 2});
        });

        test('putIfAbsent() does not trigger for existing key', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final value = prop.value.putIfAbsent('a', () => 99);

          expect(value, 1);
          expect(notifyCount, 0);
        });

        test('update() triggers notification', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.update('a', (v) => v + 10);

          expect(notifyCount, 1);
          expect(prop.value, {'a': 11});
        });

        test('updateAll() triggers notification', () {
          final prop = ObservableProperty.map<String, int>({'a': 1, 'b': 2});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.updateAll((k, v) => v * 10);

          expect(notifyCount, 1);
          expect(prop.value, {'a': 10, 'b': 20});
        });

        test('removeWhere() triggers notification when items removed', () {
          final prop =
              ObservableProperty.map<String, int>({'a': 1, 'b': 2, 'c': 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.removeWhere((k, v) => v.isEven);

          expect(notifyCount, 1);
          expect(prop.value, {'a': 1, 'c': 3});
        });

        test('removeWhere() does not trigger when no items match', () {
          final prop = ObservableProperty.map<String, int>({'a': 1, 'b': 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.removeWhere((k, v) => v.isEven);

          expect(notifyCount, 0);
        });
      });

      group('non-mutating operations do not trigger notifications', () {
        test('[] does not trigger notification', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final value = prop.value['a'];

          expect(value, 1);
          expect(notifyCount, 0);
        });

        test('containsKey() does not trigger notification', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final contains = prop.value.containsKey('a');

          expect(contains, true);
          expect(notifyCount, 0);
        });

        test('containsValue() does not trigger notification', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final contains = prop.value.containsValue(1);

          expect(contains, true);
          expect(notifyCount, 0);
        });

        test('keys does not trigger notification', () {
          final prop = ObservableProperty.map<String, int>({'a': 1, 'b': 2});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final keys = prop.value.keys.toList();

          expect(keys, ['a', 'b']);
          expect(notifyCount, 0);
        });

        test('values does not trigger notification', () {
          final prop = ObservableProperty.map<String, int>({'a': 1, 'b': 2});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final values = prop.value.values.toList();

          expect(values, [1, 2]);
          expect(notifyCount, 0);
        });

        test('entries does not trigger notification', () {
          final prop = ObservableProperty.map<String, int>({'a': 1});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final entries = prop.value.entries.toList();

          expect(entries.length, 1);
          expect(entries.first.key, 'a');
          expect(entries.first.value, 1);
          expect(notifyCount, 0);
        });
      });
    });

    group('ObservableProperty.set', () {
      group('mutating operations trigger notifications', () {
        test('add() triggers notification for new element', () {
          final prop = ObservableProperty.set<String>({'a', 'b'});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final added = prop.value.add('c');

          expect(added, true);
          expect(notifyCount, 1);
          expect(prop.value, {'a', 'b', 'c'});
        });

        test('add() does not trigger for existing element', () {
          final prop = ObservableProperty.set<String>({'a', 'b'});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final added = prop.value.add('a');

          expect(added, false);
          expect(notifyCount, 0);
        });

        test('addAll() triggers notification when elements added', () {
          final prop = ObservableProperty.set<int>({1, 2});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.addAll({3, 4, 5});

          expect(notifyCount, 1);
          expect(prop.value, {1, 2, 3, 4, 5});
        });

        test('addAll() does not trigger when all elements exist', () {
          final prop = ObservableProperty.set<int>({1, 2, 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.addAll({1, 2, 3});

          expect(notifyCount, 0);
        });

        test('remove() triggers notification when element exists', () {
          final prop = ObservableProperty.set<String>({'a', 'b', 'c'});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final removed = prop.value.remove('b');

          expect(removed, true);
          expect(notifyCount, 1);
          expect(prop.value, {'a', 'c'});
        });

        test('remove() does not trigger when element does not exist', () {
          final prop = ObservableProperty.set<String>({'a', 'b'});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final removed = prop.value.remove('z');

          expect(removed, false);
          expect(notifyCount, 0);
        });

        test('removeAll() triggers notification when elements removed', () {
          final prop = ObservableProperty.set<int>({1, 2, 3, 4, 5});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.removeAll({2, 4});

          expect(notifyCount, 1);
          expect(prop.value, {1, 3, 5});
        });

        test('removeAll() does not trigger when no elements match', () {
          final prop = ObservableProperty.set<int>({1, 3, 5});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.removeAll({2, 4});

          expect(notifyCount, 0);
        });

        test('removeWhere() triggers notification when elements removed', () {
          final prop = ObservableProperty.set<int>({1, 2, 3, 4, 5});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.removeWhere((e) => e.isEven);

          expect(notifyCount, 1);
          expect(prop.value, {1, 3, 5});
        });

        test('removeWhere() does not trigger when no elements match', () {
          final prop = ObservableProperty.set<int>({1, 3, 5});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.removeWhere((e) => e.isEven);

          expect(notifyCount, 0);
        });

        test('retainAll() triggers notification when elements removed', () {
          final prop = ObservableProperty.set<int>({1, 2, 3, 4, 5});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.retainAll({1, 3, 5});

          expect(notifyCount, 1);
          expect(prop.value, {1, 3, 5});
        });

        test('retainWhere() triggers notification when elements removed', () {
          final prop = ObservableProperty.set<int>({1, 2, 3, 4, 5});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.retainWhere((e) => e.isOdd);

          expect(notifyCount, 1);
          expect(prop.value, {1, 3, 5});
        });

        test('clear() triggers notification when not empty', () {
          final prop = ObservableProperty.set<String>({'a', 'b'});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.clear();

          expect(notifyCount, 1);
          expect(prop.value, isEmpty);
        });

        test('clear() does not trigger when already empty', () {
          final prop = ObservableProperty.set<String>({});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          prop.value.clear();

          expect(notifyCount, 0);
        });
      });

      group('non-mutating operations do not trigger notifications', () {
        test('contains() does not trigger notification', () {
          final prop = ObservableProperty.set<int>({1, 2, 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final contains = prop.value.contains(2);

          expect(contains, true);
          expect(notifyCount, 0);
        });

        test('length does not trigger notification', () {
          final prop = ObservableProperty.set<int>({1, 2, 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final length = prop.value.length;

          expect(length, 3);
          expect(notifyCount, 0);
        });

        test('isEmpty does not trigger notification', () {
          final prop = ObservableProperty.set<int>({1, 2, 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final isEmpty = prop.value.isEmpty;

          expect(isEmpty, false);
          expect(notifyCount, 0);
        });

        test('lookup() does not trigger notification', () {
          final prop = ObservableProperty.set<int>({1, 2, 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final found = prop.value.lookup(2);

          expect(found, 2);
          expect(notifyCount, 0);
        });

        test('toSet() does not trigger notification', () {
          final prop = ObservableProperty.set<int>({1, 2, 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final copy = prop.value.toSet();

          expect(copy, {1, 2, 3});
          expect(notifyCount, 0);
        });

        test('iterator does not trigger notification', () {
          final prop = ObservableProperty.set<int>({1, 2, 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final items = <int>[];
          for (final item in prop.value) {
            items.add(item);
          }

          expect(items.toSet(), {1, 2, 3});
          expect(notifyCount, 0);
        });

        test('union() does not trigger notification', () {
          final prop = ObservableProperty.set<int>({1, 2});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final union = prop.value.union({3, 4});

          expect(union, {1, 2, 3, 4});
          expect(notifyCount, 0);
        });

        test('intersection() does not trigger notification', () {
          final prop = ObservableProperty.set<int>({1, 2, 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final intersection = prop.value.intersection({2, 3, 4});

          expect(intersection, {2, 3});
          expect(notifyCount, 0);
        });

        test('difference() does not trigger notification', () {
          final prop = ObservableProperty.set<int>({1, 2, 3});
          var notifyCount = 0;
          prop.propertyChanged(() => notifyCount++);

          final difference = prop.value.difference({2});

          expect(difference, {1, 3});
          expect(notifyCount, 0);
        });
      });
    });

    group('ObservableProperty integration', () {
      test('assigning new list triggers notification if contents differ', () {
        final prop = ObservableProperty.list<int>([1, 2, 3]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = [4, 5, 6];

        expect(notifyCount, 1);
        expect(prop.value, [4, 5, 6]);
      });

      test('assigning identical list with deep equality does not trigger', () {
        final prop = ObservableProperty.list<int>([1, 2, 3]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = [1, 2, 3];

        expect(notifyCount, 0);
      });

      test('assigning identical list without deep equality triggers', () {
        final prop =
            ObservableProperty.list<int>([1, 2, 3], deepEquality: false);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = [1, 2, 3];

        expect(notifyCount, 1);
      });

      test('mutating and then assigning same contents does not double-notify',
          () {
        final prop = ObservableProperty.list<int>([1, 2]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Mutate - triggers notification
        prop.value.add(3);
        expect(notifyCount, 1);

        // Assign same contents - should NOT trigger (deep equality)
        prop.value = [1, 2, 3];
        expect(notifyCount, 1);
      });

      test('new assignment wraps in proxy and mutations continue to work', () {
        final prop = ObservableProperty.list<String>(['a']);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Assign new list
        prop.value = ['x', 'y'];
        expect(notifyCount, 1);

        // Mutation on new list should still trigger
        prop.value.add('z');
        expect(notifyCount, 2);
        expect(prop.value, ['x', 'y', 'z']);
      });
    });

    group('Edge cases', () {
      test('empty list - mutations work correctly', () {
        final prop = ObservableProperty.list<int>([]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value.add(1);
        expect(notifyCount, 1);
        expect(prop.value, [1]);
      });

      test('empty map - mutations work correctly', () {
        final prop = ObservableProperty.map<String, int>({});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value['a'] = 1;
        expect(notifyCount, 1);
        expect(prop.value, {'a': 1});
      });

      test('empty set - mutations work correctly', () {
        final prop = ObservableProperty.set<int>({});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value.add(1);
        expect(notifyCount, 1);
        expect(prop.value, {1});
      });

      test('nested collections - outer mutation triggers', () {
        final prop = ObservableProperty.list<List<int>>([
          [1, 2],
          [3, 4]
        ]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Add a new inner list - triggers
        prop.value.add([5, 6]);
        expect(notifyCount, 1);
      });

      test('large list - mutations work correctly', () {
        final largeList = List.generate(10000, (i) => i);
        final prop = ObservableProperty.list<int>(largeList);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value.add(99999);
        expect(notifyCount, 1);
        expect(prop.value.length, 10001);
        expect(prop.value.last, 99999);
      });
    });
  });
}
