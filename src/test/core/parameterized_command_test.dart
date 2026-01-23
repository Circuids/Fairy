import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/command.dart';

void main() {
  group('RelayCommand.param<TParam>', () {
    group('initialization', () {
      test('should create command with action only', () {
        var executedWith = '';
        final command = RelayCommand.param<String>((param) {
          executedWith = param;
        });

        expect(command.canExecute('test'), isTrue);

        command.execute('hello');
        expect(executedWith, equals('hello'));

        command.dispose();
      });

      test('should create command with action and canExecute', () {
        var executedWith = 0;
        final command = RelayCommand.param<int>(
          (param) => executedWith = param,
          canExecute: (param) => param > 0,
        );

        expect(command.canExecute(5), isTrue);
        expect(command.canExecute(-1), isFalse);

        command.execute(42);
        expect(executedWith, equals(42));

        command.dispose();
      });

      test('should default canExecute to true when not provided', () {
        final command = RelayCommand.param<String>((param) {});

        expect(command.canExecute('any'), isTrue);
        expect(command.canExecute('value'), isTrue);

        command.dispose();
      });
    });

    group('execute()', () {
      test('should execute action with parameter when canExecute is true', () {
        var executedWith = '';
        final command = RelayCommand.param<String>((param) {
          executedWith = param;
        });

        command.execute('test');
        expect(executedWith, equals('test'));

        command.execute('another');
        expect(executedWith, equals('another'));

        command.dispose();
      });

      test('should NOT execute action when canExecute is false', () {
        var executeCount = 0;
        final command = RelayCommand.param<int>(
          (param) => executeCount++,
          canExecute: (param) => param > 0,
        );

        // Negative parameter - should not execute
        command.execute(-5);
        expect(executeCount, equals(0));

        // Positive parameter - should execute
        command.execute(5);
        expect(executeCount, equals(1));

        command.dispose();
      });

      test('should pass parameter correctly to action', () {
        final capturedParams = <String>[];
        final command = RelayCommand.param<String>((param) {
          capturedParams.add(param);
        });

        command.execute('first');
        command.execute('second');
        command.execute('third');

        expect(capturedParams, equals(['first', 'second', 'third']));

        command.dispose();
      });

      test('should handle exceptions in action', () {
        final command = RelayCommand.param<String>((param) {
          throw Exception('Error: $param');
        });

        expect(() => command.execute('test'), throwsException);

        command.dispose();
      });
    });

    group('canExecute()', () {
      test('should return true when no predicate provided', () {
        final command = RelayCommand.param<int>((param) {});

        expect(command.canExecute(0), isTrue);
        expect(command.canExecute(100), isTrue);
        expect(command.canExecute(-100), isTrue);

        command.dispose();
      });

      test('should evaluate predicate with parameter', () {
        final command = RelayCommand.param<int>(
          (param) {},
          canExecute: (param) => param > 0 && param < 100,
        );

        expect(command.canExecute(-1), isFalse);
        expect(command.canExecute(0), isFalse);
        expect(command.canExecute(1), isTrue);
        expect(command.canExecute(50), isTrue);
        expect(command.canExecute(99), isTrue);
        expect(command.canExecute(100), isFalse);

        command.dispose();
      });

      test('should re-evaluate predicate on each call', () {
        var threshold = 10;
        final command = RelayCommand.param<int>(
          (param) {},
          canExecute: (param) => param > threshold,
        );

        expect(command.canExecute(5), isFalse);
        expect(command.canExecute(15), isTrue);

        threshold = 20;
        expect(command.canExecute(15), isFalse);
        expect(command.canExecute(25), isTrue);

        command.dispose();
      });

      test('should work with complex validation logic', () {
        final validIds = {'id1', 'id2', 'id3'};
        final command = RelayCommand.param<String>(
          (param) {},
          canExecute: (param) => validIds.contains(param),
        );

        expect(command.canExecute('id1'), isTrue);
        expect(command.canExecute('id2'), isTrue);
        expect(command.canExecute('invalid'), isFalse);

        command.dispose();
      });
    });

    group('type safety', () {
      test('should enforce type safety with String parameter', () {
        final capturedParams = <String>[];
        final command = RelayCommand.param<String>((param) {
          capturedParams.add(param);
        });

        command.execute('hello');
        command.execute('world');

        expect(capturedParams, equals(['hello', 'world']));

        command.dispose();
      });

      test('should enforce type safety with int parameter', () {
        final capturedParams = <int>[];
        final command = RelayCommand.param<int>((param) {
          capturedParams.add(param);
        });

        command.execute(1);
        command.execute(42);
        command.execute(-5);

        expect(capturedParams, equals([1, 42, -5]));

        command.dispose();
      });

      test('should work with custom types', () {
        final capturedUsers = <User>[];
        final command = RelayCommand.param<User>((param) {
          capturedUsers.add(param);
        });

        final user1 = User('Alice', 30);
        final user2 = User('Bob', 25);

        command.execute(user1);
        command.execute(user2);

        expect(capturedUsers.length, equals(2));
        expect(capturedUsers[0].name, equals('Alice'));
        expect(capturedUsers[1].name, equals('Bob'));

        command.dispose();
      });

      test('should work with nullable types', () {
        final capturedParams = <String?>[];
        final command = RelayCommand.param<String?>((param) {
          capturedParams.add(param);
        });

        command.execute('value');
        command.execute(null);
        command.execute('another');

        expect(capturedParams, equals(['value', null, 'another']));

        command.dispose();
      });
    });

    group('refresh()', () {
      test('should notify listeners when refresh is called', () {
        var notificationCount = 0;
        final command = RelayCommand.param<String>((param) {});

        command.canExecuteChanged(() => notificationCount++);

        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1));

        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(2));

        command.dispose();
      });

      test('should be used to update canExecute state', () {
        var validIds = <String>{'id1', 'id2'};
        final canExecuteResults = <bool>[];

        final command = RelayCommand.param<String>(
          (param) {},
          canExecute: (param) => validIds.contains(param),
        );

        command.canExecuteChanged(() {
          canExecuteResults.add(command.canExecute('id3'));
        });

        expect(command.canExecute('id3'), isFalse);

        // Update valid IDs and refresh
        validIds.add('id3');
        command.notifyCanExecuteChanged();

        expect(canExecuteResults.last, isTrue);

        command.dispose();
      });
    });

    group('listener management', () {
      test('should support multiple listeners', () {
        final command = RelayCommand.param<int>((param) {});
        final callOrder = <int>[];

        command.canExecuteChanged(() => callOrder.add(1));
        command.canExecuteChanged(() => callOrder.add(2));
        command.canExecuteChanged(() => callOrder.add(3));

        command.notifyCanExecuteChanged();

        expect(callOrder, equals([1, 2, 3]));

        command.dispose();
      });

      test('should not notify removed listeners', () {
        var notificationCount = 0;
        final command = RelayCommand.param<String>((param) {});

        void listener() {
          notificationCount++;
        }

        final dispose = command.canExecuteChanged(listener);
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1));

        dispose(); // Remove listener
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1)); // Still 1

        command.dispose();
      });
    });

    group('disposal', () {
      test('should not notify after disposal', () {
        final command = RelayCommand.param<int>((param) {});
        var notificationCount = 0;

        command.canExecuteChanged(() => notificationCount++);
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1));

        command.dispose();

        // ObservableNode allows notifying after disposal (listeners cleared)
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1)); // Still 1, not incremented
      });
    });

    group('integration scenarios', () {
      test('should work in delete item scenario', () {
        final viewModel = TodoViewModel();

        // Add some todos
        viewModel.addTodo('1', 'Task 1');
        viewModel.addTodo('2', 'Task 2');
        viewModel.addTodo('3', 'Task 3');

        expect(viewModel.todos.length, equals(3));

        // Should be able to delete existing todo
        expect(viewModel.deleteCommand.canExecute('1'), isTrue);
        viewModel.deleteCommand.execute('1');
        expect(viewModel.todos.length, equals(2));

        // Should not be able to delete non-existing todo
        expect(viewModel.deleteCommand.canExecute('999'), isFalse);
        viewModel.deleteCommand.execute('999');
        expect(viewModel.todos.length, equals(2)); // Still 2

        viewModel.dispose();
      });
    });
  });

  group('AsyncRelayCommand.param<TParam>', () {
    group('initialization', () {
      test('should create async command with action only', () async {
        var executedWith = '';
        final command = AsyncRelayCommand.param<String>((param) async {
          executedWith = param;
        });

        expect(command.canExecute('test'), isTrue);

        await command.execute('hello');
        expect(executedWith, equals('hello'));

        command.dispose();
      });

      test('should create async command with action and canExecute', () async {
        var executedWith = 0;
        final command = AsyncRelayCommand.param<int>(
          (param) async => executedWith = param,
          canExecute: (param) => param > 0,
        );

        expect(command.canExecute(5), isTrue);
        expect(command.canExecute(-1), isFalse);

        await command.execute(42);
        expect(executedWith, equals(42));

        command.dispose();
      });

      test('should default canExecute to true when not provided', () {
        final command = AsyncRelayCommand.param<String>((param) async {});

        expect(command.canExecute('any'), isTrue);

        command.dispose();
      });
    });

    group('execute()', () {
      test('should execute async action with parameter', () async {
        var executedWith = '';
        final command = AsyncRelayCommand.param<String>((param) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          executedWith = param;
        });

        await command.execute('test');
        expect(executedWith, equals('test'));

        await command.execute('another');
        expect(executedWith, equals('another'));

        command.dispose();
      });

      test('should NOT execute when canExecute is false', () async {
        var executeCount = 0;
        final command = AsyncRelayCommand.param<int>(
          (param) async => executeCount++,
          canExecute: (param) => param > 0,
        );

        await command.execute(-5);
        expect(executeCount, equals(0));

        await command.execute(5);
        expect(executeCount, equals(1));

        command.dispose();
      });

      test('should handle exceptions gracefully', () async {
        final command = AsyncRelayCommand.param<String>((param) async {
          throw Exception('Error: $param');
        });

        expect(command.canExecute('test'), isTrue);

        try {
          await command.execute('test');
        } catch (_) {
          // Expected
        }

        // canExecute should still work after exception
        expect(command.canExecute('test'), isTrue);

        command.dispose();
      });
    });

    group('concurrent execution', () {
      test(
          'should prevent concurrent execution (automatic re-entry prevention)',
          () async {
        var executionCount = 0;
        final command = AsyncRelayCommand.param<String>((param) async {
          executionCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });

        final future1 = command.execute('test1');
        final future2 = command.execute('test2'); // Should be ignored
        final future3 = command.execute('test3'); // Should be ignored

        await Future.wait([future1, future2, future3]);

        // Only the first execution should run due to automatic re-entry prevention
        expect(executionCount, equals(1));
        expect(command.isRunning, isFalse);

        command.dispose();
      });

      test('should allow execution after previous completes', () async {
        var executionCount = 0;
        final capturedParams = <int>[];

        final command = AsyncRelayCommand.param<int>((param) async {
          executionCount++;
          capturedParams.add(param);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });

        await command.execute(1);
        expect(executionCount, equals(1));

        await command.execute(2);
        expect(executionCount, equals(2));

        await command.execute(3);
        expect(executionCount, equals(3));

        expect(capturedParams, equals([1, 2, 3]));

        command.dispose();
      });
    });

    group('type safety', () {
      test('should enforce type safety with typed parameters', () async {
        final capturedParams = <User>[];
        final command = AsyncRelayCommand.param<User>((param) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          capturedParams.add(param);
        });

        await command.execute(User('Alice', 30));
        await command.execute(User('Bob', 25));

        expect(capturedParams.length, equals(2));
        expect(capturedParams[0].name, equals('Alice'));
        expect(capturedParams[1].name, equals('Bob'));

        command.dispose();
      });
    });

    group('refresh()', () {
      test('should notify listeners when refresh is called', () {
        var notificationCount = 0;
        final command = AsyncRelayCommand.param<String>((param) async {});

        command.canExecuteChanged(() => notificationCount++);

        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1));

        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(2));

        command.dispose();
      });

      test('should be used to update canExecute state', () {
        var threshold = 10;
        final command = AsyncRelayCommand.param<int>(
          (param) async {},
          canExecute: (param) => param > threshold,
        );

        expect(command.canExecute(5), isFalse);
        expect(command.canExecute(15), isTrue);

        threshold = 20;
        command.notifyCanExecuteChanged();

        expect(command.canExecute(15), isFalse);
        expect(command.canExecute(25), isTrue);

        command.dispose();
      });
    });

    group('disposal', () {
      test('should not notify after disposal', () {
        final command = AsyncRelayCommand.param<int>((param) async {});
        var notificationCount = 0;

        command.canExecuteChanged(() => notificationCount++);
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1));

        command.dispose();

        // ObservableNode allows notifying after disposal (listeners cleared)
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1)); // Still 1, not incremented
      });
    });

    group('integration scenarios', () {
      test('should work in async data loading scenario', () async {
        final viewModel = AsyncUserViewModel();

        expect(viewModel.currentUser, isNull);

        await viewModel.loadUserCommand.execute('user123');

        expect(viewModel.currentUser, isNotNull);
        expect(viewModel.currentUser!.name, equals('User: user123'));

        viewModel.dispose();
      });

      test('should handle rapid execute attempts correctly', () async {
        var executionCount = 0;
        final command = AsyncRelayCommand.param<String>((param) async {
          executionCount++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });

        final futures = <Future<void>>[];
        for (var i = 0; i < 10; i++) {
          futures.add(command.execute('param$i'));
        }

        await Future.wait(futures);

        // Only the first execution should run due to automatic re-entry prevention
        expect(executionCount, equals(1));
        expect(command.isRunning, isFalse);

        command.dispose();
      });
    });
  });

  // Tests for .param<T>() factory methods (v3.0.0)
  group('RelayCommand.param<T>() factory', () {
    test('should create parameterized sync command via factory method', () {
      var executedWith = '';
      final command = RelayCommand.param<String>(
        (id) => executedWith = id,
        canExecute: (id) => id.isNotEmpty,
      );

      // Test functionality - parameterized commands accept typed parameters
      expect(command.canExecute('test'), isTrue);
      expect(command.canExecute(''), isFalse);

      command.execute('hello');
      expect(executedWith, 'hello');

      command.dispose();
    });

    test('should support onError callback', () {
      Object? caughtError;
      final command = RelayCommand.param<String>(
        (id) => throw Exception('Test error'),
        onError: (error, stackTrace) => caughtError = error,
      );

      command.execute('test');
      expect(caughtError, isA<Exception>());

      command.dispose();
    });

    test('should work in ViewModel pattern', () {
      final vm = _ParamFactoryTestViewModel();

      expect(vm.deleteCommand.canExecute('item1'), isTrue);
      expect(vm.deleteCommand.canExecute(''), isFalse);

      vm.deleteCommand.execute('item123');
      expect(vm.executedWith, 'item123');

      vm.dispose();
    });
  });

  group('AsyncRelayCommand.param<T>() factory', () {
    test('should create parameterized async command via factory method',
        () async {
      var executedWith = '';
      final command = AsyncRelayCommand.param<String>(
        (id) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          executedWith = id;
        },
        canExecute: (id) => id.isNotEmpty,
      );

      // Test functionality - parameterized async commands accept typed parameters
      expect(command.canExecute('test'), isTrue);
      expect(command.canExecute(''), isFalse);
      expect(command.isRunning, isFalse);

      final future = command.execute('async-hello');
      expect(command.isRunning, isTrue);

      await future;
      expect(command.isRunning, isFalse);
      expect(executedWith, 'async-hello');

      command.dispose();
    });

    test('should support onError callback', () async {
      Object? caughtError;
      final command = AsyncRelayCommand.param<String>(
        (id) async => throw Exception('Async test error'),
        onError: (error, stackTrace) => caughtError = error,
      );

      await command.execute('test');
      expect(caughtError, isA<Exception>());

      command.dispose();
    });

    test('should work in ViewModel pattern', () async {
      final vm = _ParamFactoryTestViewModel();

      expect(vm.loadCommand.canExecute('user1'), isTrue);
      expect(vm.loadCommand.canExecute(''), isFalse);
      expect(vm.loadCommand.isRunning, isFalse);

      final future = vm.loadCommand.execute('user456');
      expect(vm.loadCommand.isRunning, isTrue);

      await future;
      expect(vm.loadCommand.isRunning, isFalse);
      expect(vm.asyncExecutedWith, 'user456');

      vm.dispose();
    });

    test('should prevent concurrent execution', () async {
      var executionCount = 0;
      final command = AsyncRelayCommand.param<String>(
        (id) async {
          executionCount++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        },
      );

      // Start first execution
      final future1 = command.execute('first');
      expect(command.isRunning, isTrue);

      // Try to start second execution while first is running
      final future2 = command.execute('second');

      await Future.wait([future1, future2]);

      // Only first execution should have run
      expect(executionCount, equals(1));

      command.dispose();
    });
  });
}

// Test helper classes

class User {
  final String name;
  final int age;

  User(this.name, this.age);
}

class Todo {
  final String id;
  final String title;

  Todo(this.id, this.title);
}

class TodoViewModel {
  final todos = <Todo>[];
  late final deleteCommand = RelayCommand.param<String>(
    _deleteTodo,
    canExecute: (id) => todos.any((t) => t.id == id),
  );

  void addTodo(String id, String title) {
    todos.add(Todo(id, title));
  }

  void _deleteTodo(String id) {
    todos.removeWhere((t) => t.id == id);
  }

  void dispose() {
    deleteCommand.dispose();
  }
}

class AsyncUserViewModel {
  User? currentUser;
  late final loadUserCommand = AsyncRelayCommand.param<String>(_loadUser);

  Future<void> _loadUser(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    currentUser = User('User: $userId', 25);
  }

  void dispose() {
    loadUserCommand.dispose();
  }
}

/// Tests for the .param<T>() factory methods introduced in v3.0.0
class _ParamFactoryTestViewModel {
  var executedWith = '';
  late final deleteCommand = RelayCommand.param<String>(
    (id) => executedWith = id,
    canExecute: (id) => id.isNotEmpty,
  );

  var asyncExecutedWith = '';
  late final loadCommand = AsyncRelayCommand.param<String>(
    (id) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      asyncExecutedWith = id;
    },
    canExecute: (id) => id.isNotEmpty,
  );

  void dispose() {
    deleteCommand.dispose();
    loadCommand.dispose();
  }
}
