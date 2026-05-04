import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';

// Test ViewModel to track listener counts
class DoubleSubscriptionTestViewModel extends ObservableObject {
  final userName = ObservableProperty<String>('');
  late final RelayCommand saveCommand;
  late final AsyncRelayCommand fetchCommand;
  late final VoidCallback _disposer;

  // Track how many times listeners are notified
  int saveCommandNotifyCount = 0;
  int fetchCommandNotifyCount = 0;

  DoubleSubscriptionTestViewModel() {
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

// Custom command that tracks listener add/remove
class TrackedRelayCommand extends RelayCommand {
  int listenerAddCount = 0;
  int listenerRemoveCount = 0;
  int notifyCount = 0;

  TrackedRelayCommand(
    super.execute, {
    super.canExecute,
  });

  @override
  void addListener(VoidCallback listener) {
    listenerAddCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerRemoveCount++;
    super.removeListener(listener);
  }

  @override
  void notifyListeners() {
    notifyCount++;
    super.notifyListeners();
  }
}

class TrackedViewModel extends ObservableObject {
  final userName = ObservableProperty<String>('');
  late final TrackedRelayCommand saveCommand;
  late final VoidCallback _disposer;

  TrackedViewModel() {
    saveCommand = TrackedRelayCommand(
      _save,
      canExecute: () => userName.value.isNotEmpty,
    );

    _disposer = userName.propertyChanged(() {
      saveCommand.notifyCanExecuteChanged();
    });
  }

  void _save() {}

  @override
  void dispose() {
    _disposer();
    super.dispose();
  }
}

void main() {
  group('Command Double Subscription Tests', () {
    testWidgets(
        'Command widget inside Bind.viewModel - check if double subscription occurs',
        (tester) async {
      final vm = TrackedViewModel();
      int bindRebuildCount = 0;
      int commandRebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<TrackedViewModel>(
                builder: (context, vm) {
                  bindRebuildCount++;
                  return Command<TrackedViewModel>(
                    command: (vm) => vm.saveCommand,
                    builder: (context, execute, canExecute, isRunning) {
                      commandRebuildCount++;
                      return ElevatedButton(
                        onPressed: canExecute ? execute : null,
                        child: Text('Save'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initial build
      expect(bindRebuildCount, equals(1));
      expect(commandRebuildCount, equals(1));

      // Check how many listeners are attached to the command
      print('Listeners added: ${vm.saveCommand.listenerAddCount}');

      // Should button be disabled initially?
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull,
          reason: 'Button should be disabled initially');

      // Reset counters
      bindRebuildCount = 0;
      commandRebuildCount = 0;
      vm.saveCommand.notifyCount = 0;

      // Trigger canExecute change
      vm.userName.value = 'John';
      await tester.pump();

      // Check rebuilds
      print('After canExecute change:');
      print('  Bind.viewModel rebuilds: $bindRebuildCount');
      print('  Command widget rebuilds: $commandRebuildCount');
      print('  Command notifyListeners called: ${vm.saveCommand.notifyCount}');

      // If double subscription exists:
      // - notifyListeners called once
      // - BOTH widgets rebuild
      // Expected: bindRebuildCount = 1, commandRebuildCount = 1 (double rebuild)

      // Button should now be enabled
      final button2 =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button2.onPressed, isNotNull,
          reason: 'Button should be enabled after userName set');
    });

    testWidgets('Direct command access in Bind.viewModel - single subscription',
        (tester) async {
      final vm = TrackedViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<TrackedViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  return ElevatedButton(
                    // Direct access (no Command widget)
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

      // Initial build
      expect(buildCount, equals(1));

      print(
          'Direct access - Listeners added: ${vm.saveCommand.listenerAddCount}');

      // Reset
      buildCount = 0;
      vm.saveCommand.notifyCount = 0;

      // Trigger change
      vm.userName.value = 'John';
      await tester.pump();

      print('After canExecute change (direct access):');
      print('  Bind.viewModel rebuilds: $buildCount');
      print('  Command notifyListeners called: ${vm.saveCommand.notifyCount}');

      // Expected: buildCount = 1 (single rebuild)
    });

    testWidgets(
        'Command widget standalone (no Bind.viewModel) - single subscription',
        (tester) async {
      final vm = TrackedViewModel();
      int commandRebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Command<TrackedViewModel>(
                command: (vm) => vm.saveCommand,
                builder: (context, execute, canExecute, isRunning) {
                  commandRebuildCount++;
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

      expect(commandRebuildCount, equals(1));

      print(
          'Standalone Command - Listeners added: ${vm.saveCommand.listenerAddCount}');

      // Reset
      commandRebuildCount = 0;
      vm.saveCommand.notifyCount = 0;

      // Trigger change
      vm.userName.value = 'John';
      await tester.pump();

      print('After canExecute change (standalone Command):');
      print('  Command widget rebuilds: $commandRebuildCount');
      print('  Command notifyListeners called: ${vm.saveCommand.notifyCount}');

      // Expected: commandRebuildCount = 1 (single rebuild)
    });

    testWidgets('Measure performance impact of double subscription',
        (tester) async {
      final vm = TrackedViewModel();
      int totalRebuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<TrackedViewModel>(
                builder: (context, vm) {
                  totalRebuilds++;
                  return Column(
                    children: [
                      Command<TrackedViewModel>(
                        command: (vm) => vm.saveCommand,
                        builder: (context, execute, canExecute, isRunning) {
                          totalRebuilds++;
                          return ElevatedButton(
                            onPressed: canExecute ? execute : null,
                            child: Text('Save'),
                          );
                        },
                      ),
                      Text('Username: ${vm.userName.value}'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initial build: Bind + Command = 2
      expect(totalRebuilds, equals(2));

      print('\n=== Performance Test ===');
      print('Listeners attached: ${vm.saveCommand.listenerAddCount}');

      // Reset
      totalRebuilds = 0;

      // Trigger multiple changes rapidly
      const changeCount = 10;
      for (int i = 0; i < changeCount; i++) {
        vm.userName.value = 'User$i';
      }
      await tester.pumpAndSettle();

      print('After $changeCount rapid changes:');
      print('  Total rebuilds: $totalRebuilds');
      print('  notifyListeners calls: ${vm.saveCommand.notifyCount}');
      print('  Rebuilds per change: ${totalRebuilds / changeCount}');

      // If double subscription: rebuilds per change ≈ 2 (Bind + Command both rebuild)
      // If single subscription: rebuilds per change ≈ 1
    });

    testWidgets('Verify Command widget cleanup with Bind.viewModel parent',
        (tester) async {
      final vm = TrackedViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<TrackedViewModel>(
                builder: (context, vm) {
                  return Command<TrackedViewModel>(
                    command: (vm) => vm.saveCommand,
                    builder: (context, execute, canExecute, isRunning) {
                      return ElevatedButton(
                        onPressed: canExecute ? execute : null,
                        child: Text('Save'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      final addedCount = vm.saveCommand.listenerAddCount;
      print('Listeners added: $addedCount');

      // Dispose widget tree
      await tester.pumpWidget(Container());

      print('After disposal:');
      print('  Listeners removed: ${vm.saveCommand.listenerRemoveCount}');

      // All listeners should be cleaned up
      expect(
        vm.saveCommand.listenerRemoveCount,
        equals(addedCount),
        reason: 'All added listeners should be removed on disposal',
      );
    });

    testWidgets('Compare: Nested Command vs Direct Access - rebuild counts',
        (tester) async {
      final vm1 = TrackedViewModel();
      final vm2 = TrackedViewModel();
      int nestedRebuilds = 0;
      int directRebuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Scenario 1: Nested Command in Bind.viewModel
                FairyScope(
                  viewModels: [ViewModelFactory((_) => vm1)],
                  child: Bind.viewModel<TrackedViewModel>(
                    builder: (context, vm) {
                      nestedRebuilds++;
                      return Command<TrackedViewModel>(
                        command: (vm) => vm.saveCommand,
                        builder: (context, execute, canExecute, isRunning) {
                          nestedRebuilds++;
                          return ElevatedButton(
                            onPressed: canExecute ? execute : null,
                            child: Text('Nested'),
                          );
                        },
                      );
                    },
                  ),
                ),
                // Scenario 2: Direct access in Bind.viewModel
                FairyScope(
                  viewModels: [ViewModelFactory((_) => vm2)],
                  child: Bind.viewModel<TrackedViewModel>(
                    builder: (context, vm) {
                      directRebuilds++;
                      return ElevatedButton(
                        onPressed: vm.saveCommand.canExecute
                            ? vm.saveCommand.execute
                            : null,
                        child: Text('Direct'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial builds
      print('\n=== Initial State ===');
      print('Nested (Command widget): $nestedRebuilds rebuilds');
      print('Direct access: $directRebuilds rebuilds');
      print('Nested listeners: ${vm1.saveCommand.listenerAddCount}');
      print('Direct listeners: ${vm2.saveCommand.listenerAddCount}');

      // Reset
      nestedRebuilds = 0;
      directRebuilds = 0;

      // Trigger changes
      vm1.userName.value = 'John';
      vm2.userName.value = 'Jane';
      await tester.pump();

      print('\n=== After canExecute Change ===');
      print('Nested rebuilds: $nestedRebuilds');
      print('Direct rebuilds: $directRebuilds');

      // Analysis:
      // If double subscription in nested: nestedRebuilds = 2
      // Direct should always be: directRebuilds = 1
    });

    testWidgets('Stress test: 50 rapid rebuilds - measure efficiency impact',
        (tester) async {
      final nestedVm = TrackedViewModel();
      final directVm = TrackedViewModel();
      final standaloneVm = TrackedViewModel();

      int nestedBindRebuilds = 0;
      int nestedCommandRebuilds = 0;
      int directRebuilds = 0;
      int standaloneRebuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Scenario 1: Nested (double subscription)
                Expanded(
                  child: FairyScope(
                    viewModels: [ViewModelFactory((_) => nestedVm)],
                    child: Bind.viewModel<TrackedViewModel>(
                      builder: (context, vm) {
                        nestedBindRebuilds++;
                        return Command<TrackedViewModel>(
                          command: (vm) => vm.saveCommand,
                          builder: (context, execute, canExecute, isRunning) {
                            nestedCommandRebuilds++;
                            return ElevatedButton(
                              onPressed: canExecute ? execute : null,
                              child: Text('Nested: ${vm.userName.value}'),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                // Scenario 2: Direct access (single subscription)
                Expanded(
                  child: FairyScope(
                    viewModels: [ViewModelFactory((_) => directVm)],
                    child: Bind.viewModel<TrackedViewModel>(
                      builder: (context, vm) {
                        directRebuilds++;
                        return ElevatedButton(
                          onPressed: vm.saveCommand.canExecute
                              ? vm.saveCommand.execute
                              : null,
                          child: Text('Direct: ${vm.userName.value}'),
                        );
                      },
                    ),
                  ),
                ),
                // Scenario 3: Standalone Command (single subscription)
                Expanded(
                  child: FairyScope(
                    viewModels: [ViewModelFactory((_) => standaloneVm)],
                    child: Column(
                      children: [
                        Command<TrackedViewModel>(
                          command: (vm) => vm.saveCommand,
                          builder: (context, execute, canExecute, isRunning) {
                            standaloneRebuilds++;
                            return ElevatedButton(
                              onPressed: canExecute ? execute : null,
                              child: Text('Standalone'),
                            );
                          },
                        ),
                        Bind<TrackedViewModel, String>(
                          bind: (vm) => vm.userName,
                          builder: (context, userName, update) {
                            return Text('Name: $userName');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial builds
      final nestedInitialBuilds = nestedBindRebuilds + nestedCommandRebuilds;
      final directInitialBuilds = directRebuilds;
      final standaloneInitialBuilds = standaloneRebuilds;

      print('\n=== STRESS TEST: 50 Rapid Rebuilds ===\n');
      print('Initial State:');
      print(
          '  Nested - Listeners: ${nestedVm.saveCommand.listenerAddCount}, Builds: $nestedInitialBuilds');
      print(
          '  Direct - Listeners: ${directVm.saveCommand.listenerAddCount}, Builds: $directInitialBuilds');
      print(
          '  Standalone - Listeners: ${standaloneVm.saveCommand.listenerAddCount}, Builds: $standaloneInitialBuilds');

      // Reset counters
      nestedBindRebuilds = 0;
      nestedCommandRebuilds = 0;
      directRebuilds = 0;
      standaloneRebuilds = 0;
      nestedVm.saveCommand.notifyCount = 0;
      directVm.saveCommand.notifyCount = 0;
      standaloneVm.saveCommand.notifyCount = 0;

      // Record start time
      final stopwatch = Stopwatch()..start();

      // Trigger 50 rapid changes
      const changeCount = 50;
      for (int i = 0; i < changeCount; i++) {
        nestedVm.userName.value = 'User$i';
        directVm.userName.value = 'User$i';
        standaloneVm.userName.value = 'User$i';
      }

      // Wait for all frames to settle
      await tester.pumpAndSettle();

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      // Calculate totals
      final nestedTotalRebuilds = nestedBindRebuilds + nestedCommandRebuilds;
      final directTotalRebuilds = directRebuilds;
      final standaloneTotalRebuilds = standaloneRebuilds;

      print('\nAfter $changeCount rapid changes:');
      print('\n📊 Nested (Command in Bind.viewModel):');
      print('  Listeners: 2 (double subscription)');
      print('  Bind.viewModel rebuilds: $nestedBindRebuilds');
      print('  Command widget rebuilds: $nestedCommandRebuilds');
      print('  Total rebuilds: $nestedTotalRebuilds');
      print('  notifyListeners calls: ${nestedVm.saveCommand.notifyCount}');
      print(
          '  Rebuilds per change: ${(nestedTotalRebuilds / changeCount).toStringAsFixed(2)}');

      print('\n📊 Direct Access (Bind.viewModel only):');
      print('  Listeners: 1 (single subscription)');
      print('  Total rebuilds: $directTotalRebuilds');
      print('  notifyListeners calls: ${directVm.saveCommand.notifyCount}');
      print(
          '  Rebuilds per change: ${(directTotalRebuilds / changeCount).toStringAsFixed(2)}');

      print('\n📊 Standalone Command:');
      print('  Listeners: 1 (single subscription)');
      print('  Total rebuilds: $standaloneTotalRebuilds');
      print('  notifyListeners calls: ${standaloneVm.saveCommand.notifyCount}');
      print(
          '  Rebuilds per change: ${(standaloneTotalRebuilds / changeCount).toStringAsFixed(2)}');

      print('\n⏱️  Performance:');
      print('  Total time: ${elapsedMs}ms');
      print(
          '  Time per change: ${(elapsedMs / changeCount).toStringAsFixed(2)}ms');

      print('\n📈 Efficiency Analysis:');
      final nestedOverhead = ((nestedTotalRebuilds - directTotalRebuilds) /
          directTotalRebuilds *
          100);
      print(
          '  Nested vs Direct overhead: ${nestedOverhead.toStringAsFixed(1)}%');
      print(
          '  Nested vs Standalone overhead: ${((nestedTotalRebuilds - standaloneTotalRebuilds) / standaloneTotalRebuilds * 100).toStringAsFixed(1)}%');

      // Verify that Flutter's optimization kicks in
      // Even with double subscription, rebuilds should be heavily batched
      expect(
        nestedTotalRebuilds,
        lessThan(changeCount * 2), // Should be much less than 2x per change
        reason: 'Flutter should batch rebuilds even with double subscription',
      );

      // All three approaches should have similar performance
      // due to Flutter's optimization
      expect(
        nestedTotalRebuilds,
        lessThan(directTotalRebuilds * 3), // At most 3x overhead
        reason:
            'Double subscription overhead should be minimal due to Flutter optimization',
      );

      print('\n✅ Conclusion:');
      if (nestedTotalRebuilds <= directTotalRebuilds * 1.5) {
        print('  Impact: NEGLIGIBLE (≤50% overhead)');
        print(
            '  Flutter\'s build optimization effectively mitigates double subscription');
      } else if (nestedTotalRebuilds <= directTotalRebuilds * 2.5) {
        print('  Impact: MINOR (≤150% overhead)');
        print('  Acceptable trade-off for improved DX');
      } else {
        print('  Impact: SIGNIFICANT (>150% overhead)');
        print('  Consider implementing prevention logic');
      }
    });
  });
}
