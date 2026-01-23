import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';

// Test ViewModels with commands
class TestViewModel extends ObservableObject {
  final canSave = ObservableProperty<bool>(false);
  late final RelayCommand saveCommand;
  int saveCount = 0;

  TestViewModel() {
    saveCommand = RelayCommand(
      _save,
      canExecute: () => canSave.value,
    );
  }

  void _save() {
    saveCount++;
  }

  // canSave auto-disposed by super.dispose()
}

class AsyncTestViewModel extends ObservableObject {
  late final AsyncRelayCommand fetchCommand;
  int fetchCount = 0;

  AsyncTestViewModel() {
    fetchCommand = AsyncRelayCommand(_fetch);
  }

  Future<void> _fetch() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    fetchCount++;
  }
}

class ParamViewModel extends ObservableObject {
  final canProcess = ObservableProperty<bool>(true);
  late final processCommand = RelayCommand.param<String>(
    _process,
    canExecute: (param) => canProcess.value, // Takes parameter
  );
  String? lastProcessed;

  void _process(String value) {
    lastProcessed = value;
  }

  // canProcess auto-disposed by super.dispose()
}

void main() {
  group('Command widget', () {
    testWidgets('should provide execute callback', (tester) async {
      final vm = TestViewModel();
      vm.canSave.value = true; // Enable command

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (_) => vm,
              child: Command<TestViewModel>(
                command: (vm) => vm.saveCommand,
                builder: (context, execute, canExecute, isRunning) {
                  return ElevatedButton(
                    onPressed: canExecute ? execute : null,
                    child: const Text('Save'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(vm.saveCount, equals(0));

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(vm.saveCount, equals(1));
    });

    testWidgets('should reflect canExecute state', (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (_) => vm,
              child: Command<TestViewModel>(
                command: (vm) => vm.saveCommand,
                builder: (context, execute, canExecute, isRunning) {
                  return ElevatedButton(
                    onPressed: canExecute ? execute : null,
                    child: Text(canExecute ? 'Enabled' : 'Disabled'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initially disabled
      expect(find.text('Disabled'), findsOneWidget);
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
    });

    testWidgets('should update when canExecute changes', (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (_) => vm,
              child: Command<TestViewModel>(
                command: (vm) => vm.saveCommand,
                builder: (context, execute, canExecute, isRunning) {
                  return ElevatedButton(
                    onPressed: canExecute ? execute : null,
                    child: Text(canExecute ? 'Enabled' : 'Disabled'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Disabled'), findsOneWidget);

      // Enable command
      vm.canSave.value = true;
      vm.saveCommand.notifyCanExecuteChanged();
      await tester.pump();

      expect(find.text('Enabled'), findsOneWidget);
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull);
    });

    testWidgets('should work with AsyncRelayCommand', (tester) async {
      final vm = AsyncTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (_) => vm,
              child: Command<AsyncTestViewModel>(
                command: (vm) => vm.fetchCommand,
                builder: (context, execute, canExecute, isRunning) {
                  return ElevatedButton(
                    onPressed: canExecute ? execute : null,
                    child: const Text('Fetch'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(vm.fetchCount, equals(0));

      // Trigger async command
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(); // Start execution

      // Wait for completion
      await tester.pumpAndSettle();

      expect(vm.fetchCount, equals(1));
    });

    testWidgets('should disable button during async execution', (tester) async {
      final vm = AsyncTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (_) => vm,
              child: Command<AsyncTestViewModel>(
                command: (vm) => vm.fetchCommand,
                builder: (context, execute, canExecute, isRunning) {
                  return ElevatedButton(
                    onPressed: canExecute ? execute : null,
                    child: isRunning
                        ? const Text('Loading...')
                        : const Text('Fetch'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initially enabled
      expect(find.text('Fetch'), findsOneWidget);
      expect(vm.fetchCount, equals(0));

      // Trigger command
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Button is now disabled during execution (automatic via isRunning)
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
      expect(find.text('Loading...'), findsOneWidget);

      await tester.pumpAndSettle();

      // Command executed and button re-enabled
      expect(vm.fetchCount, equals(1));
      expect(find.text('Fetch'), findsOneWidget);
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull);
    });

    testWidgets('should work with parameterized commands', (tester) async {
      final vm = ParamViewModel();
      const testData = 'Test Data';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (_) => vm,
              child: Command.param<ParamViewModel, String>(
                command: (vm) => vm.processCommand,
                builder: (context, execute, canExecute, isRunning) {
                  return ElevatedButton(
                    onPressed:
                        canExecute(testData) ? () => execute(testData) : null,
                    child: const Text('Process'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(vm.lastProcessed, isNull);

      await tester.tap(find.text('Process'));
      await tester.pump();

      expect(vm.lastProcessed, equals(testData));
    });

    testWidgets('should handle multiple Command widgets on same command',
        (tester) async {
      final vm = TestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (_) => vm,
              child: Column(
                children: [
                  Command<TestViewModel>(
                    command: (vm) => vm.saveCommand,
                    builder: (context, execute, canExecute, isRunning) {
                      return ElevatedButton(
                        onPressed: canExecute ? execute : null,
                        child: const Text('Button 1'),
                      );
                    },
                  ),
                  Command<TestViewModel>(
                    command: (vm) => vm.saveCommand,
                    builder: (context, execute, canExecute, isRunning) {
                      return ElevatedButton(
                        onPressed: canExecute ? execute : null,
                        child: const Text('Button 2'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Enable command
      vm.canSave.value = true;
      vm.saveCommand.notifyCanExecuteChanged();
      await tester.pump();

      // Both buttons should work
      await tester.tap(find.text('Button 1'));
      await tester.pump();
      expect(vm.saveCount, equals(1));

      await tester.tap(find.text('Button 2'));
      await tester.pump();
      expect(vm.saveCount, equals(2));
    });

    testWidgets('should clean up listener on dispose', (tester) async {
      final vm = TestViewModel();

      // Register globally so FairyScope doesn't dispose it
      FairyLocator.registerSingleton<TestViewModel>(vm);
      addTearDown(() {
        FairyLocator.unregister<TestViewModel>();
        vm.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Command<TestViewModel>(
              command: (vm) => vm.saveCommand,
              builder: (context, execute, canExecute, isRunning) {
                return Text(canExecute ? 'Enabled' : 'Disabled');
              },
            ),
          ),
        ),
      );

      expect(find.text('Disabled'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Command should still work after widget disposal
      vm.canSave.value = true;
      vm.saveCommand.notifyCanExecuteChanged();
      expect(() => vm.saveCommand.execute(), returnsNormally);
    });
  });
}
