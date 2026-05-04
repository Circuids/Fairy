import 'package:flutter/material.dart';
import 'package:fairy/fairy.dart';
import 'package:flutter_test/flutter_test.dart';

// ViewModel for tuple testing
class TupleTestViewModel extends ObservableObject {
  late final ObservableProperty<int> counter;
  late final ObservableProperty<String> message;
  late final ObservableProperty<bool> isEnabled;

  TupleTestViewModel() {
    counter = ObservableProperty<int>(0);
    message = ObservableProperty<String>('Hello');
    isEnabled = ObservableProperty<bool>(true);
  }
}

void main() {
  group('Bind widget - Tuple Selectors (All .value Pattern)', () {
    testWidgets('should track both properties when both accessed via .value',
        (tester) async {
      final vm = TupleTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, (int, String)>(
              // CRITICAL: Must access .value for ALL properties in tuple
              // Tuples do NOT support mixed ObservableProperty/value
              bind: (vm) => (vm.counter.value, vm.message.value),
              builder: (context, tuple, update) {
                final (count, msg) = tuple;
                return Text('$count - $msg');
              },
            ),
          ),
        ),
      );

      expect(find.text('0 - Hello'), findsOneWidget);

      // Test: First property change
      vm.counter.value = 42;
      await tester.pump();
      expect(find.text('42 - Hello'), findsOneWidget);

      // Test: Second property change
      vm.message.value = 'Updated';
      await tester.pump();
      expect(find.text('42 - Updated'), findsOneWidget);

      // Test: Both changes
      vm.counter.value = 100;
      vm.message.value = 'Complete';
      await tester.pump();
      expect(find.text('100 - Complete'), findsOneWidget);
    });

    testWidgets('should track three properties all accessed via .value',
        (tester) async {
      final vm = TupleTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, (int, String, bool)>(
              bind: (vm) => (
                vm.counter.value,
                vm.message.value,
                vm.isEnabled.value,
              ),
              builder: (context, tuple, update) {
                final (count, msg, enabled) = tuple;
                return Text('$count - $msg - $enabled');
              },
            ),
          ),
        ),
      );

      expect(find.text('0 - Hello - true'), findsOneWidget);

      // All three should trigger rebuilds
      vm.counter.value = 5;
      await tester.pump();
      expect(find.text('5 - Hello - true'), findsOneWidget);

      vm.message.value = 'Test';
      await tester.pump();
      expect(find.text('5 - Test - true'), findsOneWidget);

      vm.isEnabled.value = false;
      await tester.pump();
      expect(find.text('5 - Test - false'), findsOneWidget);
    });

    testWidgets('should not rebuild when unaccessed property changes',
        (tester) async {
      final vm = TupleTestViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, (int, String)>(
              // Only accesses counter and message
              bind: (vm) => (vm.counter.value, vm.message.value),
              builder: (context, tuple, update) {
                buildCount++;
                final (count, msg) = tuple;
                return Text('$count - $msg');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Change unaccessed property (isEnabled)
      vm.isEnabled.value = false;
      await tester.pump();

      // Should NOT rebuild
      expect(buildCount, 1);

      // Change accessed property
      vm.counter.value = 1;
      await tester.pump();

      // Should rebuild
      expect(buildCount, 2);
    });

    testWidgets(
        'tuple with computed expressions should track source properties',
        (tester) async {
      final vm = TupleTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, (int, String)>(
              bind: (vm) => (
                vm.counter.value * 2, // Computed from counter
                vm.message.value.toUpperCase(), // Computed from message
              ),
              builder: (context, tuple, update) {
                final (doubled, upper) = tuple;
                return Text('$doubled - $upper');
              },
            ),
          ),
        ),
      );

      expect(find.text('0 - HELLO'), findsOneWidget);

      // Changing counter should trigger recomputation
      vm.counter.value = 5;
      await tester.pump();
      expect(find.text('10 - HELLO'), findsOneWidget);

      // Changing message should trigger recomputation
      vm.message.value = 'world';
      await tester.pump();
      expect(find.text('10 - WORLD'), findsOneWidget);
    });

    testWidgets('nested tuple access should work', (tester) async {
      final vm = TupleTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, ((int, String), bool)>(
              bind: (vm) => (
                (vm.counter.value, vm.message.value),
                vm.isEnabled.value,
              ),
              builder: (context, tuple, update) {
                final ((count, msg), enabled) = tuple;
                return Text('$count - $msg - $enabled');
              },
            ),
          ),
        ),
      );

      expect(find.text('0 - Hello - true'), findsOneWidget);

      vm.counter.value = 1;
      await tester.pump();
      expect(find.text('1 - Hello - true'), findsOneWidget);

      vm.message.value = 'World';
      await tester.pump();
      expect(find.text('1 - World - true'), findsOneWidget);

      vm.isEnabled.value = false;
      await tester.pump();
      expect(find.text('1 - World - false'), findsOneWidget);
    });

    testWidgets('tuple bindings should clean up all tracked properties',
        (tester) async {
      final vm = TupleTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, (int, String, bool)>(
              bind: (vm) => (
                vm.counter.value,
                vm.message.value,
                vm.isEnabled.value,
              ),
              builder: (context, tuple, update) {
                final (count, msg, enabled) = tuple;
                return Text('$count - $msg - $enabled');
              },
            ),
          ),
        ),
      );

      expect(find.text('0 - Hello - true'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: const SizedBox(),
          ),
        ),
      );

      // All properties should be modifiable without errors
      expect(() => vm.counter.value = 100, returnsNormally);
      expect(() => vm.message.value = 'Disposed', returnsNormally);
      expect(() => vm.isEnabled.value = false, returnsNormally);
    });

    testWidgets('stress test - create and dispose tuple bindings',
        (tester) async {
      final vm = TupleTestViewModel();

      for (var i = 0; i < 30; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<TupleTestViewModel, (int, String)>(
                bind: (vm) => (vm.counter.value, vm.message.value),
                builder: (context, tuple, update) {
                  final (count, msg) = tuple;
                  return Text('$count - $msg');
                },
              ),
            ),
          ),
        );

        // Trigger updates
        vm.counter.value = i;
        await tester.pump();

        // Remove widget
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: const SizedBox(),
            ),
          ),
        );
      }

      // After all cycles, properties should work
      expect(() => vm.counter.value = 999, returnsNormally);
      expect(() => vm.message.value = 'Final', returnsNormally);
    });
  });

  group('Bind widget - Two-Way Binding (Without .value)', () {
    testWidgets(
        'should support two-way binding when returning ObservableProperty directly',
        (tester) async {
      final vm = TupleTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, int>(
              // Two-way binding: returns ObservableProperty<int>
              bind: (vm) => vm.counter,
              builder: (context, value, update) {
                return Column(
                  children: [
                    Text('Counter: $value'),
                    ElevatedButton(
                      onPressed: () => update!(value + 1),
                      child: const Text('Increment'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Counter: 0'), findsOneWidget);

      // Test: Change via update callback (two-way)
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Counter: 1'), findsOneWidget);
      expect(vm.counter.value, 1);

      // Test: Change via ViewModel directly
      vm.counter.value = 42;
      await tester.pump();
      expect(find.text('Counter: 42'), findsOneWidget);

      // Test: Two-way update again
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Counter: 43'), findsOneWidget);
      expect(vm.counter.value, 43);
    });

    testWidgets('should support two-way binding with String property',
        (tester) async {
      final vm = TupleTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, String>(
              // Two-way binding: returns ObservableProperty<String>
              bind: (vm) => vm.message,
              builder: (context, value, update) {
                return Column(
                  children: [
                    Text('Message: $value'),
                    ElevatedButton(
                      onPressed: () => update!('$value!'),
                      child: const Text('Add Exclamation'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Message: Hello'), findsOneWidget);

      // Test: Two-way update
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Message: Hello!'), findsOneWidget);
      expect(vm.message.value, 'Hello!');

      // Test: Direct ViewModel change
      vm.message.value = 'Updated';
      await tester.pump();
      expect(find.text('Message: Updated'), findsOneWidget);

      // Test: Two-way update again
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Message: Updated!'), findsOneWidget);
      expect(vm.message.value, 'Updated!');
    });

    testWidgets('two-way binding should properly dispose listeners',
        (tester) async {
      final vm = TupleTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, int>(
              bind: (vm) => vm.counter,
              builder: (context, value, update) => Text('$value'),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

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

    testWidgets('should distinguish two-way vs one-way binding behavior',
        (tester) async {
      final vm = TupleTestViewModel();

      // Test two-way binding first
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, int>(
              // Two-way: returns ObservableProperty
              bind: (vm) => vm.counter,
              builder: (context, value, update) {
                return ElevatedButton(
                  onPressed: () => update!(value + 1),
                  child: Text('Two-way: $value'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Two-way: 0'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Two-way: 1'), findsOneWidget);
      expect(vm.counter.value, 1); // ViewModel updated

      // Now test one-way binding
      vm.counter.value = 0; // Reset
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, int>(
              // One-way: returns raw value
              bind: (vm) => vm.counter.value,
              builder: (context, value, update) {
                return ElevatedButton(
                  onPressed: () {
                    // This update won't affect ViewModel in one-way mode
                    // (though it may not error, it just won't propagate)
                    update!(value + 1);
                  },
                  child: Text('One-way: $value'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('One-way: 0'), findsOneWidget);

      // Change via ViewModel - should update UI
      vm.counter.value = 5;
      await tester.pump();
      expect(find.text('One-way: 5'), findsOneWidget);
    });
  });

  group('Bind widget - Tuple WITHOUT .value (Verifying Limitation)', () {
    testWidgets(
        'LIMITATION: tuple with ObservableProperty instances throws type error',
        (tester) async {
      final vm = TupleTestViewModel();

      // This test verifies that tuples do NOT support returning ObservableProperty instances
      // The selector returns (ObservableProperty<int>, ObservableProperty<String>)
      // but Bind expects (int, String), causing a type cast error

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, (int, String)>(
              // Returns (ObservableProperty<int>, ObservableProperty<String>)
              bind: (vm) => (vm.counter, vm.message),
              builder: (context, tuple, update) {
                final (count, msg) = tuple;
                return Text('$count - $msg');
              },
            ),
          ),
        ),
      );

      // The widget builds but throws TypeError during build
      // This validates the limitation is real
      expect(tester.takeException(), isA<TypeError>());
    });

    testWidgets(
        'LIMITATION: mixed tuple (one .value, one ObservableProperty) throws type error',
        (tester) async {
      final vm = TupleTestViewModel();

      // This verifies mixed access also doesn't work
      // Returns (int, ObservableProperty<String>) but expects (int, String)

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, (int, String)>(
              // Returns (int, ObservableProperty<String>)
              bind: (vm) => (vm.counter.value, vm.message),
              builder: (context, tuple, update) {
                final (count, msg) = tuple;
                return Text('$count - $msg');
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isA<TypeError>());
    });

    testWidgets('LIMITATION: reverse mixed tuple also throws type error',
        (tester) async {
      final vm = TupleTestViewModel();

      // Returns (ObservableProperty<int>, String) but expects (int, String)

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, (int, String)>(
              // Returns (ObservableProperty<int>, String)
              bind: (vm) => (vm.counter, vm.message.value),
              builder: (context, tuple, update) {
                final (count, msg) = tuple;
                return Text('$count - $msg');
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isA<TypeError>());
    });

    testWidgets(
        'LIMITATION: three-item tuple with ObservableProperty throws type error',
        (tester) async {
      final vm = TupleTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TupleTestViewModel, (int, String, bool)>(
              // Returns (ObservableProperty<int>, ObservableProperty<String>, ObservableProperty<bool>)
              bind: (vm) => (vm.counter, vm.message, vm.isEnabled),
              builder: (context, tuple, update) {
                final (count, msg, enabled) = tuple;
                return Text('$count - $msg - $enabled');
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isA<TypeError>());
    });

    test('DOCUMENTATION: Why tuples without .value do not work', () {
      // This test documents the technical reason for the limitation

      // When Bind<VM, TValue> processes the selector result:
      // 1. It checks if result is ObservableProperty<T> (for two-way binding)
      // 2. Otherwise, it casts: `_selected as TValue`
      //
      // For tuples:
      // - selector: (vm) => (vm.counter, vm.message)
      //   Returns: (ObservableProperty<int>, ObservableProperty<String>)
      //   Cast to: (int, String)
      //   Result: TypeError! ❌
      //
      // - selector: (vm) => (vm.counter.value, vm.message.value)
      //   Returns: (int, String)
      //   Cast to: (int, String)
      //   Result: Success! ✅
      //
      // The automatic ObservableProperty unwrapping ONLY works for top-level
      // return values, NOT for ObservableProperty instances nested inside tuples.
      //
      // To support tuples without .value would require:
      // - Runtime type introspection
      // - Recursive unwrapping of tuple contents
      // - Complex type casting logic
      // - Performance overhead

      expect(true, isTrue); // Documentation test
    });
  });

  group('Bind widget - Tuple Limitations (Quick Reference)', () {
    test('README: Tuples do NOT support mixed ObservableProperty/value', () {
      // Quick reference for valid and invalid patterns:

      // ❌ INVALID: Cannot return tuple of ObservableProperty instances
      // Bind<VM, (int, String)>(
      //   selector: (vm) => (vm.counter, vm.message),  // ERROR!
      //   ...
      // )

      // ❌ INVALID: Cannot mix .value with ObservableProperty in tuple
      // Bind<VM, (int, String)>(
      //   selector: (vm) => (vm.counter.value, vm.message),  // ERROR!
      //   ...
      // )

      // ✅ VALID: Must access .value for ALL properties in tuple
      // Bind<VM, (int, String)>(
      //   selector: (vm) => (vm.counter.value, vm.message.value),  // ✅
      //   ...
      // )

      expect(true, isTrue); // Documentation test
    });
  });
}
