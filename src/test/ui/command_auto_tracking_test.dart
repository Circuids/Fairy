import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';

// Test ViewModels
class CommandTrackingViewModel extends ObservableObject {
  final userName = ObservableProperty<String>('');
  late final RelayCommand saveCommand;
  late final VoidCallback _disposer;
  int saveCount = 0;

  CommandTrackingViewModel() {
    saveCommand = RelayCommand(
      _save,
      canExecute: () => userName.value.isNotEmpty,
    );

    _disposer = userName.propertyChanged(() {
      saveCommand.notifyCanExecuteChanged();
    });
  }

  void _save() {
    saveCount++;
  }

  @override
  void dispose() {
    _disposer();
    super.dispose();
  }
}

class AsyncCommandTrackingViewModel extends ObservableObject {
  final isEnabled = ObservableProperty<bool>(false);
  late final AsyncRelayCommand fetchCommand;
  late final VoidCallback _disposer;
  int fetchCount = 0;

  AsyncCommandTrackingViewModel() {
    fetchCommand = AsyncRelayCommand(
      _fetch,
      canExecute: () => isEnabled.value,
    );

    _disposer = isEnabled.propertyChanged(() {
      fetchCommand.notifyCanExecuteChanged();
    });
  }

  Future<void> _fetch() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    fetchCount++;
  }

  @override
  void dispose() {
    _disposer();
    super.dispose();
  }
}

class ParamCommandTrackingViewModel extends ObservableObject {
  final allowedIds = ObservableProperty<Set<String>>({});
  late final deleteCommand = RelayCommand.param<String>(
    _delete,
    canExecute: (id) => allowedIds.value.contains(id),
  );
  late final VoidCallback _disposer;
  String? lastDeleted;

  ParamCommandTrackingViewModel() {
    _disposer = allowedIds.propertyChanged(() {
      deleteCommand.notifyCanExecuteChanged();
    });
  }

  void _delete(String id) {
    lastDeleted = id;
  }

  @override
  void dispose() {
    _disposer();
    super.dispose();
  }
}

class AsyncParamCommandTrackingViewModel extends ObservableObject {
  final processing = ObservableProperty<bool>(false);
  late final processCommand = AsyncRelayCommand.param<int>(
    _process,
    canExecute: (value) => !processing.value && value > 0,
  );
  late final VoidCallback _disposer;
  int? lastProcessed;

  AsyncParamCommandTrackingViewModel() {
    _disposer = processing.propertyChanged(() {
      processCommand.notifyCanExecuteChanged();
    });
  }

  Future<void> _process(int value) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    lastProcessed = value;
  }

  @override
  void dispose() {
    _disposer();
    super.dispose();
  }
}

void main() {
  group('Command Auto-Tracking in Bind.viewModel', () {
    testWidgets(
        'RelayCommand.canExecute should trigger rebuild when accessed in Bind.viewModel',
        (tester) async {
      final vm = CommandTrackingViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<CommandTrackingViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  return ElevatedButton(
                    // Accessing canExecute should register tracking
                    onPressed: vm.saveCommand.canExecute
                        ? vm.saveCommand.execute
                        : null,
                    child: Text('Save'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Button should be disabled initially
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      // Change userName - should trigger canExecute change
      vm.userName.value = 'John';
      await tester.pump();

      // Should rebuild because canExecute was tracked
      expect(buildCount, equals(2));

      // Button should now be enabled
      final button2 =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button2.onPressed, isNotNull);

      // Verify command executes
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(vm.saveCount, equals(1));
    });

    testWidgets(
        'AsyncRelayCommand.canExecute should trigger rebuild when accessed in Bind.viewModel',
        (tester) async {
      final vm = AsyncCommandTrackingViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<AsyncCommandTrackingViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  return ElevatedButton(
                    // Accessing canExecute should register tracking
                    onPressed: vm.fetchCommand.canExecute
                        ? vm.fetchCommand.execute
                        : null,
                    child: vm.fetchCommand.isRunning
                        ? CircularProgressIndicator()
                        : Text('Fetch'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Button should be disabled initially
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      // Enable command
      vm.isEnabled.value = true;
      await tester.pump();

      // Should rebuild
      expect(buildCount, equals(2));

      // Button should now be enabled
      final button2 =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button2.onPressed, isNotNull);

      // Trigger execution
      await tester.tap(find.text('Fetch'));
      await tester.pump();

      // Should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for completion
      await tester.pumpAndSettle();
      expect(vm.fetchCount, equals(1));
    });

    testWidgets(
        'RelayCommand.param canExecute should trigger rebuild when accessed in Bind.viewModel',
        (tester) async {
      final vm = ParamCommandTrackingViewModel();
      int buildCount = 0;
      const testId = 'item-1';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<ParamCommandTrackingViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  // Accessing canExecute(param) should register tracking
                  final enabled = vm.deleteCommand.canExecute(testId);
                  return ElevatedButton(
                    onPressed:
                        enabled ? () => vm.deleteCommand.execute(testId) : null,
                    child: Text('Delete'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Button should be disabled initially
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      // Allow the ID
      vm.allowedIds.value = {testId};
      await tester.pump();

      // Should rebuild
      expect(buildCount, equals(2));

      // Button should now be enabled
      final button2 =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button2.onPressed, isNotNull);

      // Execute command
      await tester.tap(find.text('Delete'));
      await tester.pump();
      expect(vm.lastDeleted, equals(testId));
    });

    testWidgets(
        'AsyncRelayCommand.param canExecute should trigger rebuild when accessed in Bind.viewModel',
        (tester) async {
      final vm = AsyncParamCommandTrackingViewModel();
      int buildCount = 0;
      const testValue = 42;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<AsyncParamCommandTrackingViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  // Accessing canExecute(param) should register tracking
                  final enabled = vm.processCommand.canExecute(testValue);
                  return ElevatedButton(
                    onPressed: enabled
                        ? () => vm.processCommand.execute(testValue)
                        : null,
                    child: vm.processCommand.isRunning
                        ? CircularProgressIndicator()
                        : Text('Process'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Button should be enabled initially (testValue > 0)
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);

      // Disable by setting processing
      vm.processing.value = true;
      await tester.pump();

      // Should rebuild
      expect(buildCount, equals(2));

      // Button should now be disabled
      final button2 =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button2.onPressed, isNull);

      // Re-enable
      vm.processing.value = false;
      await tester.pump();

      expect(buildCount, equals(3));

      // Execute
      await tester.tap(find.text('Process'));
      await tester.pump();

      // Should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(vm.lastProcessed, equals(testValue));
    });

    testWidgets(
        'Multiple commands should all be tracked independently in Bind.viewModel',
        (tester) async {
      final vm1 = CommandTrackingViewModel();
      final vm2 = AsyncCommandTrackingViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [
                (_) => vm1,
                (_) => vm2,
              ],
              child: Bind.viewModel2<CommandTrackingViewModel,
                  AsyncCommandTrackingViewModel>(
                builder: (context, saveVM, fetchVM) {
                  buildCount++;
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: saveVM.saveCommand.canExecute
                            ? saveVM.saveCommand.execute
                            : null,
                        child: Text('Save'),
                      ),
                      ElevatedButton(
                        onPressed: fetchVM.fetchCommand.canExecute
                            ? fetchVM.fetchCommand.execute
                            : null,
                        child: Text('Fetch'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Enable first command
      vm1.userName.value = 'John';
      await tester.pump();
      expect(buildCount, equals(2));

      // Enable second command
      vm2.isEnabled.value = true;
      await tester.pump();
      expect(buildCount, equals(3));
    });

    testWidgets(
        'Command widget should still work with auto-tracking (backward compatibility)',
        (tester) async {
      final vm = CommandTrackingViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Command<CommandTrackingViewModel>(
                command: (vm) => vm.saveCommand,
                builder: (context, execute, canExecute, isRunning) {
                  buildCount++;
                  return ElevatedButton(
                    onPressed: canExecute ? execute : null,
                    child: Text('Save'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Button should be disabled
      var button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      // Enable command
      vm.userName.value = 'John';
      await tester.pump();

      // Should rebuild
      expect(buildCount, equals(2));

      // Button should be enabled
      button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);

      // Execute
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(vm.saveCount, equals(1));
    });

    testWidgets(
        'isRunning should trigger rebuilds for AsyncRelayCommand in Bind.viewModel',
        (tester) async {
      final vm = AsyncCommandTrackingViewModel();
      vm.isEnabled.value = true; // Enable command
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<AsyncCommandTrackingViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: vm.fetchCommand.canExecute
                            ? vm.fetchCommand.execute
                            : null,
                        child: Text('Fetch'),
                      ),
                      if (vm.fetchCommand.isRunning) Text('Loading...'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('Loading...'), findsNothing);

      // Start async operation
      await tester.tap(find.text('Fetch'));
      await tester.pump();

      // Should rebuild and show loading
      expect(buildCount, greaterThan(1));
      expect(find.text('Loading...'), findsOneWidget);

      // Wait for completion
      await tester.pumpAndSettle();

      // Should rebuild again and hide loading
      expect(find.text('Loading...'), findsNothing);
      expect(vm.fetchCount, equals(1));
    });
  });
}
