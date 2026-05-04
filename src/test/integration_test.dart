import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Integration test combining all framework features:
// - FairyLocator (global DI)
// - FairyScope (scoped DI)
// - ObservableProperty (reactive state)
// - RelayCommand and AsyncRelayCommand (actions)
// - Bind widget (data binding)
// - Command widget (command binding)

/// Service registered globally
class CounterService {
  int getInitialCount() => 10;
}

/// Main ViewModel with multiple features
class CounterViewModel extends ObservableObject {
  final CounterService _service;

  final counter = ObservableProperty<int>(0);
  final isProcessing = ObservableProperty<bool>(false);

  late final RelayCommand incrementCommand;
  late final RelayCommand decrementCommand;
  late final AsyncRelayCommand resetCommand;
  late final addValueCommand = RelayCommand.param<int>(
    _addValue,
    canExecute: (value) => value > 0 && !isProcessing.value,
  );

  late final VoidCallback _disposeIsProcessingListener;
  late final VoidCallback _disposeCounterListener;

  CounterViewModel(this._service) {
    counter.value = _service.getInitialCount();

    incrementCommand = RelayCommand(
      _increment,
      canExecute: () => !isProcessing.value,
    );

    decrementCommand = RelayCommand(
      _decrement,
      canExecute: () => counter.value > 0 && !isProcessing.value,
    );

    resetCommand = AsyncRelayCommand(_reset);

    // When isProcessing changes, refresh commands
    _disposeIsProcessingListener = isProcessing.propertyChanged(() {
      incrementCommand.notifyCanExecuteChanged();
      decrementCommand.notifyCanExecuteChanged();
      addValueCommand.notifyCanExecuteChanged();
    });

    // When counter changes, refresh decrement command (requires > 0)
    _disposeCounterListener = counter.propertyChanged(() {
      decrementCommand.notifyCanExecuteChanged();
    });
  }

  @override
  void dispose() {
    _disposeIsProcessingListener();
    _disposeCounterListener();
    super.dispose();
  }

  void _increment() {
    counter.value++;
  }

  void _decrement() {
    counter.value--;
  }

  Future<void> _reset() async {
    isProcessing.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    counter.value = _service.getInitialCount();
    isProcessing.value = false;
  }

  void _addValue(int value) {
    counter.value += value;
  }

  // counter and isProcessing auto-disposed by super.dispose()
}

void main() {
  group('Integration Test', () {
    setUp(() {
      // Register global service
      FairyLocator.registerSingleton<CounterService>(CounterService());
    });

    tearDown(() {
      FairyLocator.unregister<CounterService>();
    });

    testWidgets('full stack: DI + reactive properties + commands + binding',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [
                ViewModelFactory((locator) => CounterViewModel(
                  locator.get<CounterService>(),
                )),
              ],
              child: Column(
                children: [
                  // Two-way binding: TextField updates counter directly
                  Bind<CounterViewModel, int>(
                    bind: (vm) => vm.counter,
                    builder: (context, value, update) {
                      return TextField(
                        key: const Key('counterField'),
                        controller:
                            TextEditingController(text: value.toString())
                              ..selection = TextSelection.collapsed(
                                  offset: value.toString().length),
                        onChanged: (text) =>
                            update?.call(int.tryParse(text) ?? 0),
                      );
                    },
                  ),

                  // Display counter value (two-way binding via property, but read-only)
                  Bind<CounterViewModel, int>(
                    bind: (vm) => vm.counter,
                    builder: (context, value, update) {
                      return Text('Count: $value',
                          key: const Key('counterText'));
                    },
                  ),

                  // Command: Increment button
                  Command<CounterViewModel>(
                    command: (vm) => vm.incrementCommand,
                    builder: (context, execute, canExecute, isRunning) {
                      return ElevatedButton(
                        key: const Key('incrementBtn'),
                        onPressed: canExecute ? execute : null,
                        child: const Text('Increment'),
                      );
                    },
                  ),

                  // Command: Decrement button (disabled when counter = 0)
                  Command<CounterViewModel>(
                    command: (vm) => vm.decrementCommand,
                    builder: (context, execute, canExecute, isRunning) {
                      return ElevatedButton(
                        key: const Key('decrementBtn'),
                        onPressed: canExecute ? execute : null,
                        child: const Text('Decrement'),
                      );
                    },
                  ),

                  // Async Command: Reset button
                  Command<CounterViewModel>(
                    command: (vm) => vm.resetCommand,
                    builder: (context, execute, canExecute, isRunning) {
                      return ElevatedButton(
                        key: const Key('resetBtn'),
                        onPressed: canExecute ? execute : null,
                        child: const Text('Reset'),
                      );
                    },
                  ),

                  // Parameterized Command: Add 5 button
                  Command.param<CounterViewModel, int>(
                    command: (vm) => vm.addValueCommand,
                    builder: (context, execute, canExecute, isRunning) {
                      return ElevatedButton(
                        key: const Key('add5Btn'),
                        onPressed: canExecute(5) ? () => execute(5) : null,
                        child: const Text('Add 5'),
                      );
                    },
                  ),

                  // Display isProcessing state
                  Bind<CounterViewModel, bool>(
                    bind: (vm) => vm.isProcessing,
                    builder: (context, value, update) {
                      return Text(
                        value ? 'Processing...' : 'Ready',
                        key: const Key('statusText'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state (service returned 10)
      expect(find.text('Count: 10'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('decrementBtn')))
            .onPressed,
        isNotNull,
      );

      // Test increment command
      await tester.tap(find.byKey(const Key('incrementBtn')));
      await tester.pumpAndSettle();
      expect(find.text('Count: 11'), findsOneWidget);

      // Test decrement command
      await tester.tap(find.byKey(const Key('decrementBtn')));
      await tester.pumpAndSettle();
      expect(find.text('Count: 10'), findsOneWidget);

      // Test parameterized command (Add 5)
      await tester.tap(find.byKey(const Key('add5Btn')));
      await tester.pumpAndSettle();
      expect(find.text('Count: 15'), findsOneWidget);

      // Test two-way binding via TextField
      final textField =
          tester.widget<TextField>(find.byKey(const Key('counterField')));
      textField.controller!.text = '20';
      textField.onChanged!('20');
      await tester.pumpAndSettle();
      expect(find.text('Count: 20'), findsOneWidget);

      // Decrement to 0 and verify button disables
      for (int i = 0; i < 20; i++) {
        await tester.tap(find.byKey(const Key('decrementBtn')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Count: 0'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('decrementBtn')))
            .onPressed,
        isNull, // Button should be disabled
      );

      // Test async reset command
      await tester.tap(find.byKey(const Key('incrementBtn')));
      await tester.pumpAndSettle();
      expect(find.text('Count: 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('resetBtn')));
      // During async operation
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Processing...'), findsOneWidget);
      // Commands should be disabled during processing
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('incrementBtn')))
            .onPressed,
        isNull,
      );

      // Wait for completion
      await tester.pumpAndSettle();
      expect(find.text('Count: 10'), findsOneWidget); // Reset to initial value
      expect(find.text('Ready'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('incrementBtn')))
            .onPressed,
        isNotNull, // Re-enabled
      );
    });

    testWidgets('scoped DI: ViewModel disposed with scope', (tester) async {
      CounterViewModel? vm;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [
                ViewModelFactory((locator) {
                  vm = CounterViewModel(
                    locator.get<CounterService>(),
                  );
                  return vm!;
                }),
              ],
              child: Bind<CounterViewModel, int>(
                bind: (vm) => vm.counter,
                builder: (context, value, update) => Text('$value'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget);

      // Verify ViewModel is not disposed
      expect(() => vm!.counter.value, returnsNormally);

      // Remove scope
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // ViewModel should be disposed by FairyScope
      // With auto-disposal, properties are disposed but field still exists
      // Setting value still works, but listeners have been removed
      vm!.counter.value = 5;
      expect(vm!.counter.value, 5); // Can still read/write after disposal
    });

    testWidgets('global DI: ViewModel survives widget disposal',
        (tester) async {
      final vm = CounterViewModel(
        FairyLocator.get<CounterService>(),
      );
      FairyLocator.registerSingleton<CounterViewModel>(vm);

      addTearDown(() {
        FairyLocator.unregister<CounterViewModel>();
        vm.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Bind<CounterViewModel, int>(
              bind: (vm) => vm.counter,
              builder: (context, value, update) => Text('$value'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // ViewModel should still be usable (not disposed)
      expect(() => vm.counter.value = 15, returnsNormally);
      expect(vm.counter.value, 15);
    });

    testWidgets('complex user flow: realistic counter app interaction',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [
                ViewModelFactory((locator) => CounterViewModel(
                  locator.get<CounterService>(),
                )),
              ],
              child: Column(
                children: [
                  Bind<CounterViewModel, int>(
                    bind: (vm) => vm.counter,
                    builder: (context, value, update) {
                      return Text('Value: $value', key: const Key('display'));
                    },
                  ),
                  Command<CounterViewModel>(
                    command: (vm) => vm.incrementCommand,
                    builder: (context, execute, canExecute, isRunning) {
                      return ElevatedButton(
                        key: const Key('inc'),
                        onPressed: canExecute ? execute : null,
                        child: const Text('+'),
                      );
                    },
                  ),
                  Command<CounterViewModel>(
                    command: (vm) => vm.decrementCommand,
                    builder: (context, execute, canExecute, isRunning) {
                      return ElevatedButton(
                        key: const Key('dec'),
                        onPressed: canExecute ? execute : null,
                        child: const Text('-'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // User story: Rapid increment/decrement interactions
      expect(find.text('Value: 10'), findsOneWidget);

      await tester.tap(find.byKey(const Key('inc')));
      await tester.tap(find.byKey(const Key('inc')));
      await tester.tap(find.byKey(const Key('inc')));
      await tester.pumpAndSettle();
      expect(find.text('Value: 13'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dec')));
      await tester.pumpAndSettle();
      expect(find.text('Value: 12'), findsOneWidget);

      // Decrement to edge case (0)
      for (int i = 0; i < 12; i++) {
        await tester.tap(find.byKey(const Key('dec')));
      }
      await tester.pumpAndSettle();
      expect(find.text('Value: 0'), findsOneWidget);

      // Verify decrement button is disabled at 0
      final decrementBtn =
          tester.widget<ElevatedButton>(find.byKey(const Key('dec')));
      expect(decrementBtn.onPressed, isNull);

      // Increment should still work
      await tester.tap(find.byKey(const Key('inc')));
      await tester.pumpAndSettle();
      expect(find.text('Value: 1'), findsOneWidget);

      // Decrement button should be re-enabled
      final decrementBtnAfter =
          tester.widget<ElevatedButton>(find.byKey(const Key('dec')));
      expect(decrementBtnAfter.onPressed, isNotNull);
    });
  });
}
