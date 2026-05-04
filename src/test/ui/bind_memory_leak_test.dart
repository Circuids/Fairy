import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';

// Simple ViewModel for testing
class TestViewModel extends ObservableObject {
  late final ObservableProperty<int> counter;
  late final ObservableProperty<String> message;
  late final ObservableProperty<List<String>> items;

  TestViewModel() {
    counter = ObservableProperty<int>(0);
    message = ObservableProperty<String>('Hello');
    items = ObservableProperty<List<String>>([]);
  }
}

void main() {
  group('Bind widget - Memory Leak Prevention', () {
    testWidgets(
        'one-way binding should clean up listeners when widget is disposed',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, int>(
              bind: (vm) => vm.counter.value,
              builder: (context, value, update) => Text('$value'),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      // Update to verify binding works
      vm.counter.value = 42;
      await tester.pump();
      expect(find.text('42'), findsOneWidget);

      // Remove Bind widget by replacing with empty widget (keeps FairyScope)
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: const SizedBox(),
          ),
        ),
      );

      // After disposal, property modifications should work normally
      expect(() => vm.counter.value = 100, returnsNormally);
    });

    testWidgets(
        'one-way binding with multiple properties should clean up all listeners',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Column(
              children: [
                Bind<TestViewModel, int>(
                  bind: (vm) => vm.counter.value,
                  builder: (context, value, update) => Text('Counter: $value'),
                ),
                Bind<TestViewModel, String>(
                  bind: (vm) => vm.message.value,
                  builder: (context, value, update) => Text('Message: $value'),
                ),
                Bind<TestViewModel, List<String>>(
                  bind: (vm) => vm.items.value,
                  builder: (context, value, update) =>
                      Text('Items: ${value.length}'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Counter: 0'), findsOneWidget);
      expect(find.text('Message: Hello'), findsOneWidget);
      expect(find.text('Items: 0'), findsOneWidget);

      // Remove all Bind widgets
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: const SizedBox(),
          ),
        ),
      );

      // All properties should work after disposal
      expect(() => vm.counter.value = 42, returnsNormally);
      expect(() => vm.message.value = 'Updated', returnsNormally);
      expect(() => vm.items.value = ['a', 'b'], returnsNormally);
    });

    testWidgets('bind change should clean up old listeners and create new ones',
        (tester) async {
      final vm = TestViewModel();
      var useCounter = true;

      Widget buildWidget() {
        return MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, dynamic>(
              bind: (vm) => useCounter ? vm.counter.value : vm.message.value,
              builder: (context, value, update) => Text('$value'),
            ),
          ),
        );
      }

      // Initial build with counter selector
      await tester.pumpWidget(buildWidget());
      expect(find.text('0'), findsOneWidget);

      // Change to message selector
      useCounter = false;
      await tester.pumpWidget(buildWidget());
      expect(find.text('Hello'), findsOneWidget);

      // Message changes should trigger rebuild
      vm.message.value = 'Updated';
      await tester.pump();
      expect(find.text('Updated'), findsOneWidget);

      // Counter changes should NOT trigger rebuild anymore
      vm.counter.value = 99;
      await tester.pump();
      expect(find.text('Updated'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: const SizedBox(),
          ),
        ),
      );

      // Both properties should work after disposal
      expect(() => vm.counter.value = 200, returnsNormally);
      expect(() => vm.message.value = 'Final', returnsNormally);
    });

    testWidgets('two-way binding should clean up listeners properly',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, int>(
              bind: (vm) => vm.counter,
              builder: (context, value, update) => Text('$value'),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      // Update and verify binding works
      vm.counter.value = 42;
      await tester.pump();
      expect(find.text('42'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: const SizedBox(),
          ),
        ),
      );

      // Property should work after disposal
      expect(() => vm.counter.value = 100, returnsNormally);
    });

    testWidgets('one-way binding with list should clean up properly',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, List<String>>(
              bind: (vm) => vm.items.value,
              builder: (context, value, update) =>
                  Text('Count: ${value.length}'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      // Update list
      vm.items.value = ['a', 'b', 'c'];
      await tester.pump();
      expect(find.text('Count: 3'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: const SizedBox(),
          ),
        ),
      );

      // List property should work after disposal
      expect(() => vm.items.value = ['x', 'y'], returnsNormally);
    });

    testWidgets('stress test - create and dispose many bindings',
        (tester) async {
      final vm = TestViewModel();

      // Create and dispose bindings multiple times
      for (var i = 0; i < 50; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Column(
                children: [
                  Bind<TestViewModel, int>(
                    bind: (vm) => vm.counter.value,
                    builder: (context, value, update) =>
                        Text('Counter: $value'),
                  ),
                  Bind<TestViewModel, String>(
                    bind: (vm) => vm.message.value,
                    builder: (context, value, update) =>
                        Text('Message: $value'),
                  ),
                  Bind<TestViewModel, List<String>>(
                    bind: (vm) => vm.items.value,
                    builder: (context, value, update) =>
                        Text('Items: ${value.length}'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Remove all widgets
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: const SizedBox(),
            ),
          ),
        );
      }

      // After all cycles, properties should still work
      expect(() => vm.counter.value = 999, returnsNormally);
      expect(() => vm.message.value = 'Final', returnsNormally);
      expect(() => vm.items.value = ['end'], returnsNormally);
    });

    testWidgets(
        'mixed one-way and two-way bindings should clean up independently',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Column(
              children: [
                // One-way binding
                Bind<TestViewModel, int>(
                  bind: (vm) => vm.counter.value,
                  builder: (context, value, update) => Text('One-way: $value'),
                ),
                // Two-way binding
                Bind<TestViewModel, String>(
                  bind: (vm) => vm.message,
                  builder: (context, value, update) => Text('Two-way: $value'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('One-way: 0'), findsOneWidget);
      expect(find.text('Two-way: Hello'), findsOneWidget);

      // Remove widgets
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: const SizedBox(),
          ),
        ),
      );

      // Both should be cleanly disposed
      expect(() => vm.counter.value = 42, returnsNormally);
      expect(() => vm.message.value = 'Updated', returnsNormally);
    });

    testWidgets('rapid rebuild and disposal should not leak', (tester) async {
      final vm = TestViewModel();

      for (var i = 0; i < 20; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<TestViewModel, int>(
                bind: (vm) => vm.counter.value,
                builder: (context, value, update) => Text('$value'),
              ),
            ),
          ),
        );

        // Trigger some updates
        vm.counter.value = i;
        await tester.pump();
        vm.counter.value = i + 1;
        await tester.pump();
        vm.counter.value = i + 2;
        await tester.pump();

        // Dispose by replacing with empty widget
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: const SizedBox(),
            ),
          ),
        );
      }

      // After all that, property should still work
      expect(() => vm.counter.value = 1000, returnsNormally);
    });
  });
}
