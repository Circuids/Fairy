import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';

// ViewModel with ObservableProperty containing a list
class ListViewModel extends ObservableObject {
  late final ObservableProperty<List<String>> items;

  ListViewModel() {
    // Use deepEquality: false to treat list as mutable reference
    // If you need deep equality, replace the entire list when mutating
    items = ObservableProperty<List<String>>(
      ['A', 'B', 'C'],
      deepEquality: false, // Disables content comparison
    );
  }

  void addItem(String item) {
    items.value.add(item);
    // With shallow equality, must create a NEW list instance to trigger notification
    items.value = List.from(items.value); // Creates new list with same contents
  }

  void replaceList(List<String> newList) {
    // Replace entire list - works with both deep and shallow equality
    items.value = newList;
  }
}

// ViewModel using deep equality (default) - requires creating new lists
class DeepEqualityListViewModel extends ObservableObject {
  late final ObservableProperty<List<String>> items;

  DeepEqualityListViewModel() {
    items = ObservableProperty<List<String>>(['A', 'B', 'C']);
    // deepEquality: true by default
  }

  void addItem(String item) {
    // With deep equality, must create a NEW list with different contents
    items.value = [...items.value, item]; // Creates new list with added item
  }
}

void main() {
  group('Bind widget - One-Way Binding with List (shallow equality)', () {
    testWidgets(
        'should rebuild when accessing .value and list reference changes',
        (tester) async {
      final vm = ListViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<ListViewModel, List<String>>(
              bind: (vm) =>
                  vm.items.value, // Accessing .value (one-way binding)
              builder: (context, value, update) {
                buildCount++;
                return Column(
                  children: value.map((item) => Text(item)).toList(),
                );
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsNothing);

      // Add item - this should trigger rebuild (shallow equality)
      vm.addItem('D');
      await tester.pump();

      expect(buildCount, equals(2), reason: 'Should rebuild after list change');
      expect(find.text('D'), findsOneWidget,
          reason: 'New item should be visible');
    });

    testWidgets('should rebuild when replacing entire list', (tester) async {
      final vm = ListViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<ListViewModel, List<String>>(
              bind: (vm) => vm.items.value,
              builder: (context, value, update) {
                buildCount++;
                return Column(
                  children: value.map((item) => Text(item)).toList(),
                );
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Replace entire list - this should work
      vm.replaceList(['X', 'Y', 'Z']);
      await tester.pump();

      expect(buildCount, equals(2));
      expect(find.text('X'), findsOneWidget);
      expect(find.text('Y'), findsOneWidget);
      expect(find.text('Z'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });

    testWidgets(
        'TWO-WAY binding should rebuild when accessing ObservableProperty directly',
        (tester) async {
      final vm = ListViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<ListViewModel, List<String>>(
              bind: (vm) =>
                  vm.items, // Accessing ObservableProperty (two-way binding)
              builder: (context, value, update) {
                buildCount++;
                return Column(
                  children: value.map((item) => Text(item)).toList(),
                );
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      // Add item and notify - should rebuild with two-way binding
      vm.addItem('D');
      await tester.pump();

      expect(buildCount, equals(2),
          reason: 'Should rebuild with two-way binding');
      expect(find.text('D'), findsOneWidget);
    });
  });

  group('Bind widget - One-Way Binding with Deep Equality (default)', () {
    testWidgets('should rebuild when list contents actually change',
        (tester) async {
      final vm = DeepEqualityListViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<DeepEqualityListViewModel, List<String>>(
              bind: (vm) => vm.items.value,
              builder: (context, value, update) {
                buildCount++;
                return Column(
                  children: value.map((item) => Text(item)).toList(),
                );
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('D'), findsNothing);

      // Add item using spread operator (creates new list with different contents)
      vm.addItem('D');
      await tester.pump();

      expect(buildCount, equals(2),
          reason: 'Should rebuild when contents actually change');
      expect(find.text('D'), findsOneWidget);
    });
  });
}
