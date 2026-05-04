import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';

// ViewModel with plain properties (no ObservableProperty)
class PlainPropertyViewModel extends ObservableObject {
  String _name = 'John';
  int _age = 30;
  bool _isActive = true;

  String get name => _name;
  int get age => _age;
  bool get isActive => _isActive;

  void updateName(String value) {
    _name = value;
    onPropertyChanged();
  }

  void updateAge(int value) {
    _age = value;
    onPropertyChanged();
  }

  void updateIsActive(bool value) {
    _isActive = value;
    onPropertyChanged();
  }

  void updateAll(String name, int age, bool isActive) {
    _name = name;
    _age = age;
    _isActive = isActive;
    onPropertyChanged(); // Single notification for all changes
  }
}

// ViewModel with mixed properties (plain and ObservableProperty)
class MixedPropertyViewModel extends ObservableObject {
  // Plain property
  String _title = 'Hello';
  String get title => _title;

  void updateTitle(String value) {
    _title = value;
    onPropertyChanged();
  }

  // ObservableProperty
  final counter = ObservableProperty<int>(0);

  // Computed value from plain property
  String get upperTitle => _title.toUpperCase();
}

void main() {
  group('Bind widget - Plain Properties with onPropertyChanged()', () {
    testWidgets('should rebuild when plain String property changes',
        (tester) async {
      final vm = PlainPropertyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<PlainPropertyViewModel, String>(
              bind: (vm) => vm.name, // Plain getter
              builder: (context, value, update) => Text(value),
            ),
          ),
        ),
      );

      expect(find.text('John'), findsOneWidget);

      vm.updateName('Jane');
      await tester.pump();

      expect(find.text('Jane'), findsOneWidget);
    });

    testWidgets('should rebuild when plain int property changes',
        (tester) async {
      final vm = PlainPropertyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<PlainPropertyViewModel, int>(
              bind: (vm) => vm.age, // Plain getter
              builder: (context, value, update) => Text('Age: $value'),
            ),
          ),
        ),
      );

      expect(find.text('Age: 30'), findsOneWidget);

      vm.updateAge(25);
      await tester.pump();

      expect(find.text('Age: 25'), findsOneWidget);
    });

    testWidgets('should rebuild when plain bool property changes',
        (tester) async {
      final vm = PlainPropertyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<PlainPropertyViewModel, bool>(
              bind: (vm) => vm.isActive,
              builder: (context, value, update) =>
                  Text('Active: ${value ? "Yes" : "No"}'),
            ),
          ),
        ),
      );

      expect(find.text('Active: Yes'), findsOneWidget);

      vm.updateIsActive(false);
      await tester.pump();

      expect(find.text('Active: No'), findsOneWidget);
    });

    testWidgets(
        'multiple Bind widgets should all rebuild on single notification',
        (tester) async {
      final vm = PlainPropertyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Column(
              children: [
                Bind<PlainPropertyViewModel, String>(
                  bind: (vm) => vm.name,
                  builder: (context, value, update) => Text('Name: $value'),
                ),
                Bind<PlainPropertyViewModel, int>(
                  bind: (vm) => vm.age,
                  builder: (context, value, update) => Text('Age: $value'),
                ),
                Bind<PlainPropertyViewModel, bool>(
                  bind: (vm) => vm.isActive,
                  builder: (context, value, update) =>
                      Text('Active: ${value ? "Yes" : "No"}'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Name: John'), findsOneWidget);
      expect(find.text('Age: 30'), findsOneWidget);
      expect(find.text('Active: Yes'), findsOneWidget);

      // Single notification for all changes
      vm.updateAll('Jane', 25, false);
      await tester.pump();

      expect(find.text('Name: Jane'), findsOneWidget);
      expect(find.text('Age: 25'), findsOneWidget);
      expect(find.text('Active: No'), findsOneWidget);
    });

    testWidgets('should have null update callback for plain properties',
        (tester) async {
      final vm = PlainPropertyViewModel();
      void Function(String)? capturedUpdate;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<PlainPropertyViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                capturedUpdate = update;
                return Text(value);
              },
            ),
          ),
        ),
      );

      // Plain properties result in one-way binding (null update)
      expect(capturedUpdate, isNull);
    });

    testWidgets('should properly cleanup listeners on disposal',
        (tester) async {
      final vm = PlainPropertyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<PlainPropertyViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) => Text(value),
            ),
          ),
        ),
      );

      expect(find.text('John'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: const SizedBox(),
          ),
        ),
      );

      // Should not crash when ViewModel notifies after widget disposal
      expect(() => vm.updateName('After disposal'), returnsNormally);
    });
  });

  group('Bind widget - Mixed Properties (Plain + ObservableProperty)', () {
    testWidgets('plain property binding should rebuild on onPropertyChanged()',
        (tester) async {
      final vm = MixedPropertyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<MixedPropertyViewModel, String>(
              bind: (vm) => vm.title, // Plain property
              builder: (context, value, update) => Text('Title: $value'),
            ),
          ),
        ),
      );

      expect(find.text('Title: Hello'), findsOneWidget);

      vm.updateTitle('World');
      await tester.pump();

      expect(find.text('Title: World'), findsOneWidget);
    });

    testWidgets(
        'ObservableProperty binding should NOT rebuild on ViewModel notification',
        (tester) async {
      final vm = MixedPropertyViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<MixedPropertyViewModel, int>(
              bind: (vm) => vm.counter, // ObservableProperty
              builder: (context, value, update) {
                buildCount++;
                return Text('Counter: $value');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Change plain property - should NOT rebuild counter binding
      vm.updateTitle('Updated');
      await tester.pump();

      expect(buildCount, 1); // Still 1 - no rebuild

      // Change ObservableProperty - should rebuild
      vm.counter.value = 5;
      await tester.pump();

      expect(buildCount, 2); // Now 2
      expect(find.text('Counter: 5'), findsOneWidget);
    });

    testWidgets('computed plain property should rebuild on onPropertyChanged()',
        (tester) async {
      final vm = MixedPropertyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<MixedPropertyViewModel, String>(
              bind: (vm) => vm.upperTitle, // Computed from plain property
              builder: (context, value, update) => Text(value),
            ),
          ),
        ),
      );

      expect(find.text('HELLO'), findsOneWidget);

      vm.updateTitle('world');
      await tester.pump();

      expect(find.text('WORLD'), findsOneWidget);
    });

    testWidgets('should handle rapid plain property updates', (tester) async {
      final vm = PlainPropertyViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<PlainPropertyViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                buildCount++;
                return Text(value);
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Rapid updates (10 times) in the same frame
      for (var i = 0; i < 10; i++) {
        vm.updateName('Update $i');
      }
      await tester.pump();

      // Flutter coalesces multiple setState calls in the same frame
      expect(buildCount, 2); // Initial + 1 coalesced rebuild
      expect(find.text('Update 9'), findsOneWidget);
    });
  });

  group('Bind.viewModel - Plain Properties with onPropertyChanged()', () {
    testWidgets('should rebuild on any ViewModel notification', (tester) async {
      final vm = PlainPropertyViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<PlainPropertyViewModel>(
              builder: (context, vm) {
                buildCount++;
                return Text('${vm.name} - ${vm.age}');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('John - 30'), findsOneWidget);

      // Update name - should rebuild
      vm.updateName('Jane');
      await tester.pump();

      expect(buildCount, 2);
      expect(find.text('Jane - 30'), findsOneWidget);

      // Update age - should rebuild
      vm.updateAge(25);
      await tester.pump();

      expect(buildCount, 3);
      expect(find.text('Jane - 25'), findsOneWidget);
    });

    testWidgets('should rebuild on updateAll notification', (tester) async {
      final vm = PlainPropertyViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<PlainPropertyViewModel>(
              builder: (context, vm) {
                buildCount++;
                return Text('${vm.name} - ${vm.age} - ${vm.isActive}');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('John - 30 - true'), findsOneWidget);

      // Single notification for multiple changes
      vm.updateAll('Jane', 25, false);
      await tester.pump();

      expect(buildCount, 2); // Only one rebuild
      expect(find.text('Jane - 25 - false'), findsOneWidget);
    });

    testWidgets('should handle mixed properties correctly', (tester) async {
      final vm = MixedPropertyViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<MixedPropertyViewModel>(
              builder: (context, vm) {
                buildCount++;
                return Text('${vm.title} - ${vm.counter.value}');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Hello - 0'), findsOneWidget);

      // Update plain property - should rebuild
      vm.updateTitle('World');
      await tester.pump();

      expect(buildCount, 2);
      expect(find.text('World - 0'), findsOneWidget);

      // Update ObservableProperty - should rebuild
      vm.counter.value = 5;
      await tester.pump();

      expect(buildCount, 3);
      expect(find.text('World - 5'), findsOneWidget);
    });

    testWidgets('should properly cleanup on disposal', (tester) async {
      final vm = PlainPropertyViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<PlainPropertyViewModel>(
              builder: (context, vm) => Text(vm.name),
            ),
          ),
        ),
      );

      expect(find.text('John'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: const SizedBox(),
          ),
        ),
      );

      // Should not crash when ViewModel notifies after widget disposal
      expect(() => vm.updateName('After disposal'), returnsNormally);
    });

    testWidgets('should rebuild even without accessing properties explicitly',
        (tester) async {
      final vm = PlainPropertyViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<PlainPropertyViewModel>(
              builder: (context, vm) {
                buildCount++;
                // Not accessing any properties, just showing static text
                return const Text('Static');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Static'), findsOneWidget);

      // Should rebuild because BindViewModel always subscribes to ViewModel
      vm.updateName('Jane');
      await tester.pump();

      expect(buildCount, 2); // Should rebuild
      expect(find.text('Static'), findsOneWidget);
    });

    testWidgets('multiple Bind.viewModel should all rebuild', (tester) async {
      final vm = PlainPropertyViewModel();
      var buildCount1 = 0;
      var buildCount2 = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Column(
              children: [
                Bind.viewModel<PlainPropertyViewModel>(
                  builder: (context, vm) {
                    buildCount1++;
                    return Text('Name: ${vm.name}');
                  },
                ),
                Bind.viewModel<PlainPropertyViewModel>(
                  builder: (context, vm) {
                    buildCount2++;
                    return Text('Age: ${vm.age}');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(buildCount1, 1);
      expect(buildCount2, 1);

      // Both should rebuild on any notification
      vm.updateName('Jane');
      await tester.pump();

      expect(buildCount1, 2);
      expect(buildCount2, 2);

      vm.updateAge(25);
      await tester.pump();

      expect(buildCount1, 3);
      expect(buildCount2, 3);
    });

    testWidgets('should coalesce rapid updates within same frame',
        (tester) async {
      final vm = PlainPropertyViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<PlainPropertyViewModel>(
              builder: (context, vm) {
                buildCount++;
                return Text(vm.name);
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Rapid updates (10 times) in the same frame
      for (var i = 0; i < 10; i++) {
        vm.updateName('Update $i');
      }
      await tester.pump();

      // BindViewModel coalesces updates - only 1 rebuild for all changes in same frame
      expect(buildCount, 2); // Initial + 1 coalesced rebuild
      expect(find.text('Update 9'), findsOneWidget);
    });

    testWidgets('stress test - create and dispose (30 cycles)', (tester) async {
      final vm = PlainPropertyViewModel();

      for (var i = 0; i < 30; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<PlainPropertyViewModel>(
                builder: (context, vm) => Text(vm.name),
              ),
            ),
          ),
        );

        vm.updateName('Cycle $i');
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

      // After all cycles, ViewModel should work
      expect(() => vm.updateName('Final'), returnsNormally);
    });
  });

  group('Bind widget - Plain Properties Edge Cases', () {
    testWidgets('should work with oneTime flag for plain properties',
        (tester) async {
      final vm = PlainPropertyViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<PlainPropertyViewModel, String>(
              bind: (vm) => vm.name,
              builder: (context, value, update) {
                buildCount++;
                return Text(value);
              },
              oneTime: true,
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('John'), findsOneWidget);

      // Should NOT rebuild with oneTime: true
      vm.updateName('Jane');
      await tester.pump();

      expect(buildCount, 1); // Still 1
      expect(find.text('John'), findsOneWidget); // Still old value
    });

    testWidgets('should handle bind change from plain to plain',
        (tester) async {
      final vm = PlainPropertyViewModel();
      var showName = true;

      Widget buildWidget() {
        return MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Bind<PlainPropertyViewModel, dynamic>(
                      bind: (vm) => showName ? vm.name : vm.age,
                      builder: (context, value, update) => Text('$value'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => showName = !showName),
                      child: const Text('Toggle'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWidget());
      expect(find.text('John'), findsOneWidget);

      // Toggle selector
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('30'), findsOneWidget);

      // Update age - should rebuild
      vm.updateAge(25);
      await tester.pump();
      expect(find.text('25'), findsOneWidget);

      // Toggle back to name
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('John'), findsOneWidget);

      // Update name - should rebuild
      vm.updateName('Jane');
      await tester.pump();
      expect(find.text('Jane'), findsOneWidget);
    });

    testWidgets(
        'stress test - create and dispose with plain properties (30 cycles)',
        (tester) async {
      final vm = PlainPropertyViewModel();

      for (var i = 0; i < 30; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<PlainPropertyViewModel, String>(
                bind: (vm) => vm.name,
                builder: (context, value, update) => Text(value),
              ),
            ),
          ),
        );

        vm.updateName('Cycle $i');
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

      // After all cycles, ViewModel should work
      expect(() => vm.updateName('Final'), returnsNormally);
    });
  });
}
