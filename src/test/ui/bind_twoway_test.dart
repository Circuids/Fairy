import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:fairy/src/ui/bind_widget.dart';

void main() {
  group('Bind widget - Two-Way Binding', () {
    testWidgets('should detect ObservableProperty and enable two-way binding',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                expect(update, isNotNull); // Two-way binding
                return Text(value);
              },
            ),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);
    });

    testWidgets(
        'should provide non-null update callback for ObservableProperty',
        (tester) async {
      final vm = TestViewModel();
      void Function(String)? capturedUpdate;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                capturedUpdate = update;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedUpdate, isNotNull);
    });

    testWidgets('should update UI when ObservableProperty changes',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                return Text(value);
              },
            ),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);

      // Change property value
      vm.name.value = 'Updated';
      await tester.pump();

      expect(find.text('Updated'), findsOneWidget);
      expect(find.text('Initial'), findsNothing);
    });

    testWidgets('should allow updating value via callback', (tester) async {
      final vm = TestViewModel();
      void Function(String)? updateCallback;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                updateCallback = update;
                return Text(value);
              },
            ),
          ),
        ),
      );

      expect(vm.name.value, equals('Initial'));

      // Update via callback
      updateCallback!('Changed');
      await tester.pump();

      expect(vm.name.value, equals('Changed'));
      expect(find.text('Changed'), findsOneWidget);
    });

    testWidgets('should work with TextField using update callback',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<TestViewModel, String>(
                bind: (vm) => vm.name,
                builder: (context, value, update) {
                  return TextField(
                    key: const Key('textfield'),
                    controller: TextEditingController(text: value),
                    onChanged: update,
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(vm.name.value, equals('Initial'));

      // Enter text
      await tester.enterText(find.byKey(const Key('textfield')), 'New Value');
      await tester.pump();

      expect(vm.name.value, equals('New Value'));
    });

    testWidgets('should work with int ObservableProperty', (tester) async {
      final vm = CounterViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<CounterViewModel, int>(
              bind: (vm) => vm.count,
              builder: (context, value, update) {
                return Column(
                  children: [
                    Text('Count: $value'),
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

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
      expect(vm.count.value, equals(1));
    });

    testWidgets('should work with nullable ObservableProperty', (tester) async {
      final vm = NullableViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<NullableViewModel, String?>(
              bind: (vm) => vm.optionalName,
              builder: (context, value, update) {
                return Column(
                  children: [
                    Text(value ?? 'null'),
                    ElevatedButton(
                      onPressed: () => update!('Set'),
                      child: const Text('Set Value'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('null'), findsOneWidget);

      await tester.tap(find.text('Set Value'));
      await tester.pump();

      expect(find.text('Set'), findsOneWidget);
      expect(vm.optionalName.value, equals('Set'));
    });

    testWidgets('should update when property changes multiple times',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                return Text(value);
              },
            ),
          ),
        ),
      );

      for (var i = 1; i <= 5; i++) {
        vm.name.value = 'Update $i';
        await tester.pump();
        expect(find.text('Update $i'), findsOneWidget);
      }
    });

    testWidgets('should handle rapid updates correctly', (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                return Text(value);
              },
            ),
          ),
        ),
      );

      // Rapid updates without pumping
      vm.name.value = 'A';
      vm.name.value = 'B';
      vm.name.value = 'C';
      vm.name.value = 'Final';

      await tester.pump();

      // Should show final value
      expect(find.text('Final'), findsOneWidget);
    });

    testWidgets('should clean up listener on dispose', (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                return Text(value);
              },
            ),
          ),
        ),
      );

      // Widget is active, listeners attached
      expect(find.text('Initial'), findsOneWidget);

      // Change value to verify listener is working
      vm.name.value = 'Test';
      await tester.pump();
      expect(find.text('Test'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // After disposal, changing property should not cause issues
      expect(() => vm.name.value = 'After Dispose', returnsNormally);
    });

    testWidgets('should work with multiple Bind widgets on same property',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Column(
              children: [
                Bind<TestViewModel, String>(
                  bind: (vm) => vm.name,
                  builder: (context, value, update) {
                    return Text('Widget 1: $value');
                  },
                ),
                Bind<TestViewModel, String>(
                  bind: (vm) => vm.name,
                  builder: (context, value, update) {
                    return Text('Widget 2: $value');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Widget 1: Initial'), findsOneWidget);
      expect(find.text('Widget 2: Initial'), findsOneWidget);

      vm.name.value = 'Both Updated';
      await tester.pump();

      expect(find.text('Widget 1: Both Updated'), findsOneWidget);
      expect(find.text('Widget 2: Both Updated'), findsOneWidget);
    });

    testWidgets('should work with bool ObservableProperty', (tester) async {
      final vm = BoolViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<BoolViewModel, bool>(
                bind: (vm) => vm.isEnabled,
                builder: (context, value, update) {
                  return Checkbox(
                    value: value,
                    onChanged: (newValue) => update!(newValue!),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(vm.isEnabled.value, isFalse);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(vm.isEnabled.value, isTrue);
    });

    testWidgets('should work with custom object ObservableProperty',
        (tester) async {
      final vm = CustomObjectViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<CustomObjectViewModel, User>(
              bind: (vm) => vm.user,
              builder: (context, value, update) {
                return Column(
                  children: [
                    Text('${value.name}, ${value.age}'),
                    ElevatedButton(
                      onPressed: () => update!(User('Bob', 35)),
                      child: const Text('Change User'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Alice, 30'), findsOneWidget);

      await tester.tap(find.text('Change User'));
      await tester.pump();

      expect(find.text('Bob, 35'), findsOneWidget);
      expect(vm.user.value.name, equals('Bob'));
    });

    testWidgets('should handle bind returning different property instance',
        (tester) async {
      final vm = TestViewModel();
      var useFirstProperty = true;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Bind<TestViewModel, String>(
                      bind: (vm) => useFirstProperty ? vm.name : vm.description,
                      builder: (context, value, update) {
                        return Text(value);
                      },
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          setState(() => useFirstProperty = !useFirstProperty),
                      child: const Text('Toggle'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);

      await tester.tap(find.text('Toggle'));
      await tester.pump();

      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets('should not rebuild when unrelated property changes',
        (tester) async {
      final vm = TestViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<TestViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                buildCount++;
                return Text(value);
              },
            ),
          ),
        ),
      );

      final initialBuildCount = buildCount;

      // Change different property
      vm.description.value = 'Changed Description';
      await tester.pump();

      // Should not rebuild
      expect(buildCount, equals(initialBuildCount));
    });
  });
}

// Test ViewModels

class TestViewModel extends ObservableObject {
  final name = ObservableProperty<String>('Initial');
  final description = ObservableProperty<String>('Description');
}

class CounterViewModel extends ObservableObject {
  final count = ObservableProperty<int>(0);
}

class NullableViewModel extends ObservableObject {
  final optionalName = ObservableProperty<String?>(null);
}

class BoolViewModel extends ObservableObject {
  final isEnabled = ObservableProperty<bool>(false);
}

class User {
  final String name;
  final int age;

  User(this.name, this.age);
}

class CustomObjectViewModel extends ObservableObject {
  final user = ObservableProperty<User>(User('Alice', 30));
}
