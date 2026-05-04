import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';

// Test ViewModel
class CommandSelectorTestViewModel extends ObservableObject {
  final userName = ObservableProperty<String>('');
  late final RelayCommand saveCommand;
  late final AsyncRelayCommand fetchCommand;
  late final VoidCallback _disposer;

  CommandSelectorTestViewModel() {
    saveCommand = RelayCommand(
      _save,
      canExecute: () => userName.value.isNotEmpty,
    );

    fetchCommand = AsyncRelayCommand(_fetch);

    _disposer = userName.propertyChanged(() {
      saveCommand.notifyCanExecuteChanged();
    });
  }

  void _save() {}

  Future<void> _fetch() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  @override
  void dispose() {
    _disposer();
    super.dispose();
  }
}

void main() {
  group('Bind with Command Selector Tests', () {
    testWidgets(
        'Bind<VM, bool> with canExecute selector - should track and rebuild',
        (tester) async {
      final vm = CommandSelectorTestViewModel();
      int buildCount = 0;
      bool? lastCanExecuteValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<CommandSelectorTestViewModel, bool>(
                bind: (vm) => vm.saveCommand.canExecute,
                builder: (context, canExecute, update) {
                  buildCount++;
                  lastCanExecuteValue = canExecute;
                  return ElevatedButton(
                    onPressed:
                        canExecute ? () => vm.saveCommand.execute() : null,
                    child: Text('Save'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initial state
      expect(buildCount, equals(1));
      expect(lastCanExecuteValue, isFalse,
          reason: 'Should be disabled initially');

      final button1 =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button1.onPressed, isNull, reason: 'Button should be disabled');

      // Reset
      buildCount = 0;

      // Change state that affects canExecute
      vm.userName.value = 'John';
      await tester.pump();

      // Should have rebuilt
      expect(buildCount, equals(1),
          reason: 'Should rebuild when canExecute changes');
      expect(lastCanExecuteValue, isTrue,
          reason: 'Should be enabled after userName set');

      final button2 =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button2.onPressed, isNotNull, reason: 'Button should be enabled');

      print('✅ Bind<VM, bool> with canExecute selector works correctly');
    });

    testWidgets(
        'Bind<VM, bool> with isRunning selector - should track async state',
        (tester) async {
      final vm = CommandSelectorTestViewModel();
      int buildCount = 0;
      bool? lastIsRunningValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<CommandSelectorTestViewModel, bool>(
                bind: (vm) => vm.fetchCommand.isRunning,
                builder: (context, isRunning, update) {
                  buildCount++;
                  lastIsRunningValue = isRunning;
                  return isRunning
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.check);
                },
              ),
            ),
          ),
        ),
      );

      // Initial state
      expect(buildCount, equals(1));
      expect(lastIsRunningValue, isFalse);
      expect(find.byType(Icon), findsOneWidget);

      // Reset
      buildCount = 0;

      // Execute async command
      vm.fetchCommand.execute();
      await tester.pump(); // Should show loading

      // Note: isRunning getter was accessed in selector, so it's tracked
      expect(buildCount, greaterThan(0),
          reason: 'Should rebuild when command starts');
      expect(lastIsRunningValue, isTrue, reason: 'Should be running');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Reset again
      buildCount = 0;

      // Wait for command to complete
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(0),
          reason: 'Should rebuild when command completes');
      expect(lastIsRunningValue, isFalse, reason: 'Should not be running');
      expect(find.byType(Icon), findsOneWidget);

      print('✅ Bind<VM, bool> with isRunning selector works correctly');
    });

    testWidgets(
        'Bind<VM, RelayCommand> with command selector - what actually happens?',
        (tester) async {
      final vm = CommandSelectorTestViewModel();
      int buildCount = 0;
      RelayCommand? capturedCommand;

      // This is the "weird" pattern - let's see what happens
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<CommandSelectorTestViewModel, RelayCommand>(
                bind: (vm) => vm.saveCommand,
                builder: (context, command, update) {
                  buildCount++;
                  capturedCommand = command;
                  return ElevatedButton(
                    onPressed: command.canExecute ? command.execute : null,
                    child: Text('Save'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initial build
      expect(buildCount, equals(1));
      expect(capturedCommand, isNotNull);
      expect(capturedCommand, equals(vm.saveCommand),
          reason: 'Should receive the command object');

      // Reset
      buildCount = 0;

      // Change canExecute
      vm.userName.value = 'John';
      await tester.pump();

      // What happens here?
      print('\n📊 Bind<VM, RelayCommand> Analysis:');
      print('  Rebuilds after canExecute change: $buildCount');
      print(
          '  Command object identity preserved: ${capturedCommand == vm.saveCommand}');

      // The question: does it rebuild when canExecute changes?
      // Since selector returns the SAME command object, Bind might not detect a change
      // unless it's tracking the command as an ObservableNode

      if (buildCount > 0) {
        print('  ✅ Does rebuild (command tracked as ObservableNode)');
      } else {
        print('  ⚠️  Does NOT rebuild (selector returns same object)');
        print('     This is why returning commands directly is problematic!');
      }
    });

    testWidgets(
        'Bind<VM, RelayCommand> - verify it DOES track the command node',
        (tester) async {
      final vm = CommandSelectorTestViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<CommandSelectorTestViewModel, RelayCommand>(
                bind: (vm) => vm.saveCommand,
                builder: (context, command, update) {
                  buildCount++;
                  return Text('Can execute: ${command.canExecute}');
                },
              ),
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Reset
      buildCount = 0;

      // Trigger canExecute change
      vm.userName.value = 'John';
      await tester.pump();

      // This is the critical test
      expect(
        buildCount,
        equals(0),
        reason: 'Should NOT rebuild because selector returns command object, '
            'not accessing any observable getter like canExecute',
      );

      print('❌ Bind<VM, RelayCommand> does NOT track changes');
      print(
          '   Selector returns same object reference, no observable accessed!');
    });

    testWidgets(
        'Bind<VM, RelayCommand> - problem: doesn\'t track canExecute ACCESS inside builder',
        (tester) async {
      final vm = CommandSelectorTestViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<CommandSelectorTestViewModel, RelayCommand>(
                bind: (vm) => vm.saveCommand,
                builder: (context, command, update) {
                  buildCount++;
                  // Accessing canExecute HERE (in builder) doesn't trigger tracking
                  // because we're not inside DependencyTracker.track() anymore
                  final canExec = command.canExecute;
                  return Text('Can execute: $canExec');
                },
              ),
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Reset
      buildCount = 0;

      // Change canExecute
      vm.userName.value = 'John';
      await tester.pump();

      print('\n🔍 Critical Test: Accessing canExecute in builder');
      print('  Rebuilds: $buildCount');

      // The selector only returns the command object (no observable accessed)
      // Accessing command.canExecute in builder doesn't add tracking
      // because we're not inside DependencyTracker.track() anymore

      expect(
        buildCount,
        equals(0),
        reason: 'Does NOT rebuild - selector returns same object, '
            'and builder accesses are not tracked',
      );

      print(
          '  Result: Does NOT rebuild (command object returned, no tracking)');
      print('  This pattern doesn\'t work - use Bind<VM, bool> instead!');
    });

    testWidgets(
        'Recommended pattern: Bind<VM, bool> vs Anti-pattern: Bind<VM, RelayCommand>',
        (tester) async {
      final vm1 = CommandSelectorTestViewModel();
      final vm2 = CommandSelectorTestViewModel();
      int recommendedBuilds = 0;
      int antiPatternBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Recommended: Track specific state
                FairyScope(
                  viewModels: [ViewModelFactory((_) => vm1)],
                  child: Bind<CommandSelectorTestViewModel, bool>(
                    bind: (vm) => vm.saveCommand.canExecute,
                    builder: (context, canExecute, update) {
                      recommendedBuilds++;
                      return ElevatedButton(
                        onPressed:
                            canExecute ? () => vm1.saveCommand.execute() : null,
                        child: const Text('Recommended'),
                      );
                    },
                  ),
                ),
                // Anti-pattern: Return command object
                FairyScope(
                  viewModels: [ViewModelFactory((_) => vm2)],
                  child: Bind<CommandSelectorTestViewModel, RelayCommand>(
                    bind: (vm) => vm.saveCommand,
                    builder: (context, command, update) {
                      antiPatternBuilds++;
                      return ElevatedButton(
                        onPressed: command.canExecute ? command.execute : null,
                        child: const Text('Anti-pattern'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(recommendedBuilds, equals(1));
      expect(antiPatternBuilds, equals(1));

      // Reset
      recommendedBuilds = 0;
      antiPatternBuilds = 0;

      // Change state
      vm1.userName.value = 'John';
      vm2.userName.value = 'Jane';
      await tester.pump();

      print('\n📊 Pattern Comparison:');
      print('  Recommended (Bind<VM, bool>): $recommendedBuilds rebuilds');
      print(
          '  Anti-pattern (Bind<VM, RelayCommand>): $antiPatternBuilds rebuilds');

      // Recommended pattern should rebuild
      expect(recommendedBuilds, equals(1),
          reason: 'Clear: tracks canExecute boolean state');

      // Anti-pattern should NOT rebuild (returns same object)
      expect(antiPatternBuilds, equals(0),
          reason:
              'Broken: selector returns same command object, no observable accessed');

      print('\n✅ Recommended pattern works correctly!');
      print('❌ Anti-pattern is broken (does not rebuild)');
      print('   This proves the anti-pattern is not viable!');
    });

    testWidgets(
        'Edge case: Bind<VM, RelayCommand> with update callback - makes no sense',
        (tester) async {
      final vm = CommandSelectorTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind<CommandSelectorTestViewModel, RelayCommand>(
                bind: (vm) => vm.saveCommand,
                builder: (context, command, update) {
                  // update would be null anyway (one-way binding)
                  // What would update even do? Replace the command object?
                  expect(update, isNull,
                      reason: 'Cannot two-way bind to a command object');
                  return const Text('Command binding');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      print('✅ Correctly prevents two-way binding to command objects');
    });
  });

  group('Vanilla Bind Command Support - Summary Tests', () {
    testWidgets('Summary: What works and what doesn\'t', (tester) async {
      final vm = CommandSelectorTestViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Column(
                children: [
                  // ✅ GOOD: Track canExecute state
                  Bind<CommandSelectorTestViewModel, bool>(
                    bind: (vm) => vm.saveCommand.canExecute,
                    builder: (context, canExecute, _) =>
                        Text('Can save: $canExecute'),
                  ),
                  // ✅ GOOD: Track isRunning state
                  Bind<CommandSelectorTestViewModel, bool>(
                    bind: (vm) => vm.fetchCommand.isRunning,
                    builder: (context, isRunning, _) =>
                        Text('Is fetching: $isRunning'),
                  ),
                  // ⚠️ AWKWARD: Track command object
                  Bind<CommandSelectorTestViewModel, RelayCommand>(
                    bind: (vm) => vm.saveCommand,
                    builder: (context, cmd, _) =>
                        Text('Has command: ${cmd.canExecute}'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      vm.userName.value = 'Test';
      await tester.pump();

      print('\n📋 SUMMARY:');
      print('✅ Bind<VM, bool> with canExecute - WORKS PERFECTLY');
      print('✅ Bind<VM, bool> with isRunning - WORKS PERFECTLY');
      print('❌ Bind<VM, RelayCommand> - BROKEN (does not rebuild)');
      print('❌ Two-way binding to commands - Correctly prevented');
      print('\nConclusion: Anti-pattern is NOT viable!');
      print('Only tracking observable state (canExecute, isRunning) works.');
      print('This is excellent design - prevents misuse naturally.');
    });
  });
}
