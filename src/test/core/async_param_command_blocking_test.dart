import 'dart:async';

import 'package:fairy/src/core/command.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests documenting that AsyncRelayCommand.param<T> blocks ALL calls
/// (including different parameters) while running. This is the behavior
/// that causes the voice-selection bug: tapping voice "B" while voice "A"
/// is still being persisted silently drops the "B" call.
void main() {
  group('AsyncRelayCommand.param<T> — blocking behavior while running', () {
    // ================================================================
    // Test 1: Different-parameter call is blocked while running
    // ================================================================
    test('blocks execute("B") while execute("A") is still running', () async {
      final receivedParams = <String>[];
      final completer = Completer<void>();

      final command = AsyncRelayCommand.param<String>((param) async {
        receivedParams.add(param);
        await completer.future;
      });

      // Start "A"
      final futureA = command.execute('A');
      expect(command.isRunning, isTrue);

      // Attempt "B" while "A" is running
      final futureB = command.execute('B');

      // "B" was silently dropped — only "A" was passed to the action
      expect(receivedParams, equals(['A']));

      // Complete "A"
      completer.complete();
      await futureA;
      await futureB;

      expect(command.isRunning, isFalse);

      // Now "B" should work
      final completer2 = Completer<void>();
      final futureB2 = command.execute('B');
      // This time "B" should have been received
      expect(receivedParams, equals(['A', 'B']));

      completer2.complete(); // not used by this action, just let it finish
      await futureB2;

      command.dispose();
    });

    // ================================================================
    // Test 2: canExecute returns false for ANY parameter while running
    // ================================================================
    test('canExecute returns false for any parameter while running', () async {
      final completer = Completer<void>();

      final command = AsyncRelayCommand.param<String>((param) async {
        await completer.future;
      });

      // Before execution — all parameters are executable
      expect(command.canExecute('A'), isTrue);
      expect(command.canExecute('B'), isTrue);

      // Start "A"
      final future = command.execute('A');

      // While running, canExecute is false for every parameter
      expect(command.canExecute('A'), isFalse);
      expect(command.canExecute('B'), isFalse);
      expect(command.canExecute('C'), isFalse);

      // Complete
      completer.complete();
      await future;

      // After completion — all parameters are executable again
      expect(command.canExecute('A'), isTrue);
      expect(command.canExecute('B'), isTrue);

      command.dispose();
    });

    // ================================================================
    // Test 3: Same-parameter double-tap is correctly blocked
    // ================================================================
    test('same parameter double-tap is blocked (desired behavior)', () async {
      var callCount = 0;
      final completer = Completer<void>();

      final command = AsyncRelayCommand.param<String>((param) async {
        callCount++;
        await completer.future;
      });

      // First tap
      final future1 = command.execute('A');
      // Second tap with same parameter
      final future2 = command.execute('A');

      // Action should have been called exactly once
      expect(callCount, equals(1));

      completer.complete();
      await future1;
      await future2;

      command.dispose();
    });

    // ================================================================
    // Test 4: Rapid sequential taps — voice selection scenario
    // ================================================================
    test('rapid sequential taps: only first executes, rest are dropped',
        () async {
      final selectedId = ObservableProperty<String?>(null);

      final command = AsyncRelayCommand.param<String>((param) async {
        selectedId.value = param;
        await Future.delayed(const Duration(milliseconds: 50));
      });

      // Simulate rapid taps on three different voices
      final f1 = command.execute('algieba');
      final f2 = command.execute('fenrir');
      final f3 = command.execute('leda');

      await f1;
      await f2;
      await f3;

      // Current behavior: only "algieba" executed; "fenrir" and "leda" dropped
      // (For a responsive UI, "leda" (latest-wins) would be better)
      expect(selectedId.value, equals('algieba'));

      selectedId.dispose();
      command.dispose();
    });

    // ================================================================
    // Test 5: Listener notification count during blocked calls
    // ================================================================
    test('blocked calls do not fire listener notifications', () async {
      final completer = Completer<void>();
      var notificationCount = 0;

      final command = AsyncRelayCommand.param<String>((param) async {
        await completer.future;
      });

      final dispose = command.canExecuteChanged(() {
        notificationCount++;
      });

      // execute("A") → isRunning becomes true → 1 notification
      final futureA = command.execute('A');
      expect(notificationCount, equals(1));

      // execute("B") while running → silently dropped → 0 extra notifications
      final futureB = command.execute('B');
      expect(notificationCount, equals(1));

      // Complete "A" → isRunning becomes false → 1 more notification
      completer.complete();
      await futureA;
      await futureB;

      expect(notificationCount, equals(2));

      dispose();
      command.dispose();
    });

    // ================================================================
    // Test 6: canExecute predicate short-circuits when _isRunning is true
    // ================================================================
    test('canExecute predicate is not evaluated while command is running',
        () async {
      var predicateCallCount = 0;
      final completer = Completer<void>();

      final command = AsyncRelayCommand.param<String>(
        (param) async {
          await completer.future;
        },
        canExecute: (param) {
          predicateCallCount++;
          return true;
        },
      );

      // execute("A") evaluates canExecute once
      final future = command.execute('A');
      final callsAfterExecute = predicateCallCount;

      // Reset counter
      predicateCallCount = 0;

      // While running, query canExecute("B")
      final result = command.canExecute('B');

      // _isRunning is true → short-circuits to false without calling predicate
      expect(result, isFalse);
      expect(predicateCallCount, equals(0),
          reason:
              '_isRunning short-circuits canExecute before user predicate runs');

      completer.complete();
      await future;

      // After completion, predicate IS evaluated
      predicateCallCount = 0;
      expect(command.canExecute('B'), isTrue);
      expect(predicateCallCount, equals(1));

      command.dispose();
    });
  });
}
