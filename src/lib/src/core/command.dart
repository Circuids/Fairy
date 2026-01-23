import 'package:fairy/src/core/observable_node.dart';
import 'package:fairy/src/internal/dependency_tracker.dart';
import 'package:flutter/foundation.dart';

/// Callback type for evaluating whether a command can execute.
typedef CanExecute = bool Function();

/// A command that encapsulates an action with optional execution guard logic.
///
/// [RelayCommand] implements the command pattern for ViewModels, allowing you
/// to bind user actions to methods with optional `canExecute` validation.
///
/// The command notifies listeners when `canExecute` might have changed, enabling
/// UI elements (like buttons) to reactively enable/disable themselves.
///
/// Example:
/// ```dart
/// class MyViewModel extends ObservableObject {
///   late final ObservableProperty<String> userName;
///   late final RelayCommand saveCommand;
///   VoidCallback? _disposer;
///
///   MyViewModel() {
///     userName = ObservableProperty<String>('');
///
///     saveCommand = RelayCommand(
///       _save,
///       canExecute: () => userName.value.isNotEmpty,
///     );
///
///     // Refresh command when validation state changes
///     _disposer = userName.propertyChanged(() => saveCommand.notifyCanExecuteChanged());
///   }
///
///   void _save() {
///     // Save logic here
///   }
///
///   @override
///   void dispose() {
///     _disposer?.call();
///     super.dispose();
///   }
/// }
/// ```
class RelayCommand extends ObservableNode {
  final VoidCallback _action;
  final CanExecute? _canExecute;
  final void Function(Object error, StackTrace?)? _onError;

  /// Creates a [RelayCommand] with an action and optional canExecute predicate.
  ///
  /// [execute] is the method to execute when the command runs.
  /// [canExecute] is an optional predicate that determines if the action can run.
  /// If omitted, the command can always execute.
  /// [onError] is an optional callback invoked when the action throws an error.
  RelayCommand(
    VoidCallback execute, {
    CanExecute? canExecute,
    void Function(Object error, StackTrace?)? onError,
  })  : _action = execute,
        _canExecute = canExecute,
        _onError = onError;

  /// Creates a parameterized command with a typed parameter.
  ///
  /// This is the **only** way to create parameterized sync commands.
  ///
  /// [execute] receives a parameter of type [TParam] when executed.
  /// [canExecute] optionally validates whether the action can run with the given parameter.
  /// [onError] is an optional callback invoked when the action throws an error.
  ///
  /// Example:
  /// ```dart
  /// late final deleteCommand = RelayCommand.param<String>(
  ///   (id) => items.removeWhere((item) => item.id == id),
  ///   canExecute: (id) => id.isNotEmpty,
  /// );
  /// ```
  static RelayCommandWithParam<TParam> param<TParam>(
    void Function(TParam) execute, {
    bool Function(TParam)? canExecute,
    void Function(Object error, StackTrace?)? onError,
  }) {
    return RelayCommandWithParam<TParam>(
      execute,
      canExecute: canExecute,
      onError: onError,
    );
  }

  // ========================================================================
  // HIDDEN ObservableNode API (marked @protected for internal framework use)
  // ========================================================================

  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);

  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);

  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();

  /// Whether the command can currently execute.
  ///
  /// Returns `true` if no [canExecute] predicate was provided, or if the
  /// predicate returns `true`.
  ///
  /// **Auto-tracking:** When accessed inside [Bind.viewModel], the command is
  /// automatically tracked and the widget rebuilds when [notifyCanExecuteChanged]
  /// is called.
  bool get canExecute {
    // Report command access for automatic dependency tracking
    DependencyTracker.reportAccess(this);
    return _canExecute?.call() ?? true;
  }

  /// Executes the command's action if [canExecute] is `true`.
  ///
  /// Does nothing if [canExecute] returns `false`.
  /// If the action throws an error and [onError] was provided, the error is caught and passed to [onError].
  void execute() {
    if (canExecute) {
      try {
        _action();
      } catch (error, stackTrace) {
        if (_onError != null) {
          _onError!(error, stackTrace);
        } else {
          rethrow;
        }
      }
    }
  }

  /// Notifies listeners that [canExecute] may have changed.
  ///
  /// Call this method when the conditions for [canExecute] change (e.g., when
  /// a property that affects validation is updated).
  void notifyCanExecuteChanged() => notifyListeners();

  /// Listens for changes to [canExecute].
  ///
  /// Returns a disposal function that removes the listener when called.
  /// This provides a cleaner alternative to manually managing [addListener]
  /// and [removeListener] calls.
  ///
  /// Example:
  /// ```dart
  /// final command = RelayCommand(() { /* ... */ });
  ///
  /// final dispose = command.canExecuteChanged(() {
  ///   print('Can Execute changed!');
  /// });
  ///
  /// // Later, clean up:
  /// dispose();
  /// ```
  VoidCallback canExecuteChanged(VoidCallback listener) {
    addListener(listener);
    return () => removeListener(listener);
  }
}

/// An asynchronous command for long-running operations.
///
/// [AsyncRelayCommand] is designed for async operations like network calls
/// or database queries. Unlike [RelayCommand], it returns a [Future] from
/// [execute] that completes when the async action finishes.
///
/// **Automatic Loading State:** The [isRunning] property automatically tracks
/// execution state. While running, [canExecute] returns `false` to prevent
/// concurrent execution (double-click prevention).
///
/// Example:
/// ```dart
/// class DataViewModel extends ObservableObject {
///   late final ObservableProperty<List<Item>?> data;
///   late final AsyncRelayCommand fetchDataCommand;
///
///   DataViewModel() {
///     data = ObservableProperty<List<Item>?>([]);
///
///     fetchDataCommand = AsyncRelayCommand(
///       _fetchData,
///     );
///   }
///
///   Future<void> _fetchData() async {
///     // isRunning automatically set to true
///     final response = await api.fetchItems();
///     data.value = response;
///     // isRunning automatically set to false
///   }
/// }
///
/// // In UI - use isRunning for loading indicators
/// Command<DataViewModel>(
///   command: (vm) => vm.fetchDataCommand,
///   builder: (context, execute, canExecute, isRunning) {
///     if (isRunning) return CircularProgressIndicator();
///     return ElevatedButton(onPressed: execute, child: Text('Fetch'));
///   },
/// )
/// ```
class AsyncRelayCommand extends ObservableNode {
  final Future<void> Function() _action;
  final CanExecute? _canExecute;
  final void Function(Object error, StackTrace?)? _onError;
  bool _isRunning = false;

  /// Creates an [AsyncRelayCommand] with an async action and optional canExecute predicate.
  ///
  /// [execute] is the asynchronous method to execute when the command runs.
  /// [canExecute] is an optional predicate that determines if the action can run.
  /// [onError] is an optional callback invoked when the action throws an error.
  ///
  /// While the command is executing, [isRunning] is `true` and [canExecute]
  /// automatically returns `false` to prevent concurrent execution.
  AsyncRelayCommand(
    Future<void> Function() execute, {
    CanExecute? canExecute,
    void Function(Object error, StackTrace?)? onError,
  })  : _action = execute,
        _canExecute = canExecute,
        _onError = onError;

  /// Creates a parameterized async command with a typed parameter.
  ///
  /// This is the **only** way to create parameterized async commands.
  ///
  /// [execute] is an async function that receives a parameter of type [TParam].
  /// [canExecute] optionally validates whether the action can run with the given parameter.
  /// [onError] is an optional callback invoked when the action throws an error.
  ///
  /// While the command is executing, [isRunning] is `true` and [canExecute]
  /// automatically returns `false` to prevent concurrent execution.
  ///
  /// Example:
  /// ```dart
  /// late final loadUserCommand = AsyncRelayCommand.param<String>(
  ///   (userId) async => user.value = await api.fetchUser(userId),
  ///   canExecute: (userId) => userId.isNotEmpty,
  /// );
  /// ```
  static AsyncRelayCommandWithParam<TParam> param<TParam>(
    Future<void> Function(TParam) execute, {
    bool Function(TParam)? canExecute,
    void Function(Object error, StackTrace?)? onError,
  }) {
    return AsyncRelayCommandWithParam<TParam>(
      execute,
      canExecute: canExecute,
      onError: onError,
    );
  }

  // ========================================================================
  // HIDDEN ObservableNode API (marked @protected for internal framework use)
  // ========================================================================

  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);

  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);

  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();

  /// Whether the command is currently executing.
  ///
  /// Automatically set to `true` when execution starts and `false` when it completes.
  /// While running, [canExecute] returns `false` to prevent concurrent execution.
  ///
  /// **Auto-tracking:** When accessed inside [Bind.viewModel] or [Bind] selectors,
  /// the command is automatically tracked and the widget rebuilds when execution
  /// state changes.
  bool get isRunning {
    // Report command access for automatic dependency tracking
    DependencyTracker.reportAccess(this);
    return _isRunning;
  }

  /// Whether the command can currently execute.
  ///
  /// Returns `false` if the command is currently running, or if the [canExecute]
  /// predicate returns `false`.
  ///
  /// **Auto-tracking:** When accessed inside [Bind.viewModel], the command is
  /// automatically tracked and the widget rebuilds when [notifyCanExecuteChanged]
  /// is called or when execution state changes.
  bool get canExecute {
    // Report command access for automatic dependency tracking
    DependencyTracker.reportAccess(this);
    return !_isRunning && (_canExecute?.call() ?? true);
  }

  /// Executes the command's async action if [canExecute] is `true`.
  ///
  /// Returns a [Future] that completes when the action completes.
  /// Sets [isRunning] to `true` during execution and `false` when complete.
  /// If the action throws an error and [onError] was provided, the error is caught and passed to [onError].
  Future<void> execute() async {
    if (!canExecute) return;

    _isRunning = true;
    notifyListeners();

    try {
      await _action();
    } catch (error, stackTrace) {
      if (_onError != null) {
        _onError!(error, stackTrace);
      } else {
        rethrow;
      }
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Notifies listeners that [canExecute] may have changed.
  ///
  /// Call this method when the conditions for the [canExecute] predicate change.
  void notifyCanExecuteChanged() => notifyListeners();

  /// Listens for changes to [canExecute].
  ///
  /// Returns a disposal function that removes the listener when called.
  /// This provides a cleaner alternative to manually managing [addListener]
  /// and [removeListener] calls.
  ///
  /// Example:
  /// ```dart
  /// final command = AsyncRelayCommand(() { /* ... */ });
  ///
  /// final dispose = command.canExecuteChanged(() {
  ///   print('Can Execute changed!');
  /// });
  ///
  /// // Later, clean up:
  /// dispose();
  /// ```
  VoidCallback canExecuteChanged(VoidCallback listener) {
    addListener(listener);
    return () => removeListener(listener);
  }
}

/// A command that accepts a typed parameter when executing.
///
/// **Preferred:** Use [RelayCommand.param] factory method for cleaner syntax:
/// ```dart
/// late final deleteCommand = RelayCommand.param<String>(
///   (id) => items.removeWhere((item) => item.id == id),
///   canExecute: (id) => id.isNotEmpty,
/// );
/// ```
///
/// Direct constructor is also available for explicit type annotations:
/// ```dart
/// late final RelayCommandWithParam<String> deleteCommand;
/// ```
class RelayCommandWithParam<TParam> extends ObservableNode {
  final void Function(TParam) _action;
  final bool Function(TParam)? _canExecute;
  final void Function(Object error, StackTrace?)? _onError;

  /// Creates a parameterized relay command.
  ///
  /// [execute] receives a parameter of type [TParam] when executed.
  /// [canExecute] optionally validates whether the action can run with the given parameter.
  /// [onError] is an optional callback invoked when the action throws an error.
  RelayCommandWithParam(
    void Function(TParam) execute, {
    bool Function(TParam)? canExecute,
    void Function(Object error, StackTrace?)? onError,
  })  : _action = execute,
        _canExecute = canExecute,
        _onError = onError;

  // ========================================================================
  // HIDDEN ObservableNode API (marked @protected for internal framework use)
  // ========================================================================

  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);

  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);

  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();

  /// Whether the command can execute with the given [param].
  ///
  /// Returns `true` if no [canExecute] predicate was provided, or if the
  /// predicate returns `true` for the given parameter.
  ///
  /// **Auto-tracking:** When accessed inside [Bind.viewModel], the command is
  /// automatically tracked and the widget rebuilds when [notifyCanExecuteChanged]
  /// is called.
  bool canExecute(TParam param) {
    // Report command access for automatic dependency tracking
    DependencyTracker.reportAccess(this);
    return _canExecute?.call(param) ?? true;
  }

  /// Executes the command's action with the given [param] if [canExecute] is `true`.
  ///
  /// Does nothing if [canExecute] returns `false` for the parameter.
  /// If the action throws an error and [onError] was provided, the error is caught and passed to [onError].
  void execute(TParam param) {
    if (canExecute(param)) {
      try {
        _action(param);
      } catch (error, stackTrace) {
        if (_onError != null) {
          _onError!(error, stackTrace);
        } else {
          rethrow;
        }
      }
    }
  }

  /// Notifies listeners that [canExecute] may have changed.
  ///
  /// Call this method when the conditions affecting [canExecute] change.
  void notifyCanExecuteChanged() => notifyListeners();

  /// Listens for changes to [canExecute].
  ///
  /// Returns a disposal function that removes the listener when called.
  /// This provides a cleaner alternative to manually managing [addListener]
  /// and [removeListener] calls.
  ///
  /// Example:
  /// ```dart
  /// final command = RelayCommandWithParam<String>(() { /* ... */ });
  ///
  /// final dispose = command.canExecuteChanged(() {
  ///   print('Can Execute changed!');
  /// });
  ///
  /// // Later, clean up:
  /// dispose();
  /// ```
  VoidCallback canExecuteChanged(VoidCallback listener) {
    addListener(listener);
    return () => removeListener(listener);
  }
}

/// An asynchronous command that accepts a typed parameter when executing.
///
/// Combines the features of [AsyncRelayCommand] and [RelayCommandWithParam],
/// providing async execution with parameter support and optional [canExecute] validation.
///
/// **Automatic Loading State:** The [isRunning] property automatically tracks
/// execution state. While running, [canExecute] returns `false` to prevent
/// concurrent execution (double-click prevention).
///
/// **Preferred construction:** Use [AsyncRelayCommand.param] factory method:
/// ```dart
/// late final loadUserCommand = AsyncRelayCommand.param<String>(
///   (userId) async => user.value = await api.fetchUser(userId),
///   canExecute: (userId) => userId.isNotEmpty,
/// );
/// ```
///
/// Example:
/// ```dart
/// class UserViewModel extends ObservableObject {
///   late final loadUserCommand = AsyncRelayCommand.param<String>(
///     _loadUser,
///     canExecute: (userId) => userId.isNotEmpty,
///   );
///
///   Future<void> _loadUser(String userId) async {
///     // isRunning automatically set to true
///     final user = await api.fetchUser(userId);
///     // Update state
///     // isRunning automatically set to false
///   }
/// }
///
/// // In UI
/// Command.param<UserViewModel, String>(
/// An async command that accepts a typed parameter when executing.
///
/// **Preferred:** Use [AsyncRelayCommand.param] factory method for cleaner syntax:
/// ```dart
// ignore: unintended_html_in_doc_comment
/// late final loadUserCommand = AsyncRelayCommand.param<String>(
///   (userId) async => user.value = await api.fetchUser(userId),
///   canExecute: (userId) => userId.isNotEmpty,
/// );
/// ```
///
/// Direct constructor is also available for explicit type annotations:
/// ```dart
// ignore: unintended_html_in_doc_comment
/// late final AsyncRelayCommandWithParam<String> loadCommand;
/// ```
class AsyncRelayCommandWithParam<TParam> extends ObservableNode {
  final Future<void> Function(TParam) _action;
  final bool Function(TParam)? _canExecute;
  final void Function(Object error, StackTrace?)? _onError;
  bool _isRunning = false;

  /// Creates an async parameterized command.
  ///
  /// [execute] is an async function that receives a parameter of type [TParam].
  /// [canExecute] optionally validates whether the action can run with the given parameter.
  /// [onError] is an optional callback invoked when the action throws an error.
  ///
  /// While the command is executing, [isRunning] is `true` and [canExecute]
  /// automatically returns `false` to prevent concurrent execution.
  AsyncRelayCommandWithParam(
    Future<void> Function(TParam) execute, {
    bool Function(TParam)? canExecute,
    void Function(Object error, StackTrace?)? onError,
  })  : _action = execute,
        _canExecute = canExecute,
        _onError = onError;

  // ========================================================================
  // HIDDEN ObservableNode API (marked @protected for internal framework use)
  // ========================================================================

  @override
  @protected
  void addListener(VoidCallback listener) => super.addListener(listener);

  @override
  @protected
  void removeListener(VoidCallback listener) => super.removeListener(listener);

  @override
  @protected
  // ignore: unnecessary_overrides
  void notifyListeners() => super.notifyListeners();

  /// Whether the command is currently executing.
  ///
  /// Automatically set to `true` when execution starts and `false` when it completes.
  /// While running, [canExecute] returns `false` to prevent concurrent execution.
  ///
  /// **Auto-tracking:** When accessed inside [Bind.viewModel] or [Bind] selectors,
  /// the command is automatically tracked and the widget rebuilds when execution
  /// state changes.
  bool get isRunning {
    // Report command access for automatic dependency tracking
    DependencyTracker.reportAccess(this);
    return _isRunning;
  }

  /// Whether the command can execute with the given [param].
  ///
  /// Returns `false` if the command is currently running, or if the [canExecute]
  /// predicate returns `false` for the parameter.
  ///
  /// **Auto-tracking:** When accessed inside [Bind.viewModel], the command is
  /// automatically tracked and the widget rebuilds when [notifyCanExecuteChanged]
  /// is called or when execution state changes.
  bool canExecute(TParam param) {
    // Report command access for automatic dependency tracking
    DependencyTracker.reportAccess(this);
    return !_isRunning && (_canExecute?.call(param) ?? true);
  }

  /// Executes the command's async action with the given [param] if [canExecute] is `true`.
  ///
  /// Sets [isRunning] to `true` during execution and `false` when complete.
  /// If the action throws an error and [onError] was provided, the error is caught and passed to [onError].
  Future<void> execute(TParam parameter) async {
    if (!canExecute(parameter)) return;

    _isRunning = true;
    notifyListeners();

    try {
      await _action(parameter);
    } catch (error, stackTrace) {
      if (_onError != null) {
        _onError!(error, stackTrace);
      } else {
        rethrow;
      }
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Notifies listeners that [canExecute] may have changed.
  void notifyCanExecuteChanged() => notifyListeners();

  /// Listens for changes to [canExecute].
  ///
  /// Returns a disposal function that removes the listener when called.
  /// This provides a cleaner alternative to manually managing [addListener]
  /// and [removeListener] calls.
  ///
  /// Example:
  /// ```dart
  /// final command = AsyncRelayCommandWithParam<String>(() { /* ... */ });
  ///
  /// final dispose = command.canExecuteChanged(() {
  ///   print('Can Execute changed!');
  /// });
  ///
  /// // Later, clean up:
  /// dispose();
  /// ```
  VoidCallback canExecuteChanged(VoidCallback listener) {
    addListener(listener);
    return () => removeListener(listener);
  }
}
