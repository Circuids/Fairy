import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../core/observable.dart';
import '../core/command.dart';
import '../locator/fairy_resolver.dart';

/// A widget that binds a [RelayCommand] or [AsyncRelayCommand] to UI.
///
/// [Command] extracts a command from a ViewModel and subscribes to its changes,
/// automatically rebuilding when [canExecute] changes. It provides both the
/// [execute] callback and [canExecute] state to the builder.
///
/// This widget works with:
/// - [RelayCommand]
/// - [AsyncRelayCommand]
/// - [RelayCommandWithParam<T>]
/// - [AsyncRelayCommandWithParam<T>]
///
/// ## Basic Example (RelayCommand):
/// ```dart
/// class MyViewModel extends ObservableObject {
///   late final ObservableProperty<String> userName;
///   late final RelayCommand saveCommand;
///   VoidCallback? _disposer;
///
///   MyViewModel() {
///     userName = ObservableProperty<String>('', parent: this);
///
///     saveCommand = RelayCommand(
///       execute: _save,
///       canExecute: () => userName.value.isNotEmpty,
///       parent: this,
///     );
///
///     _disposer = userName.propertyChanged(() => saveCommand.notifyCanExecuteChanged());
///   }
///
///   void _save() { /* ... */ }
///
///   @override
///   void dispose() {
///     _disposer?.call();
///     super.dispose();
///   }
/// }
///
/// Command<MyViewModel>(
///   command: (vm) => vm.saveCommand,
///   builder: (context, execute, canExecute) {
///     return ElevatedButton(
///       onPressed: canExecute ? execute : null,
///       child: const Text('Save'),
///     );
///   },
/// )
/// ```
///
/// ## Async Example (AsyncRelayCommand):
/// ```dart
/// class DataViewModel extends ObservableObject {
///   late final AsyncRelayCommand fetchCommand;
///
///   DataViewModel() {
///     fetchCommand = AsyncRelayCommand(
///       execute: _fetchData,
///       parent: this,
///     );
///   }
///
///   Future<void> _fetchData() async { /* ... */ }
/// }
///
/// Command<DataViewModel>(
///   command: (vm) => vm.fetchCommand,
///   builder: (context, execute, canExecute) {
///     final vm = Fairy.of<DataViewModel>(context);
///     if (vm.fetchCommand.isRunning) {
///       return const CircularProgressIndicator();
///     }
///     return ElevatedButton(
///       onPressed: canExecute ? execute : null,
///       child: const Text('Fetch'),
///     );
///   },
/// )
/// ```
class Command<TViewModel extends ObservableObject> extends StatefulWidget {
  const Command({
    required this.command,
    required this.builder,
    super.key,
  });

  /// Creates a command binding for parameterized commands.
  ///
  /// Use when your command requires a parameter at execution time.
  ///
  /// Supports both [RelayCommandWithParam] and [AsyncRelayCommandWithParam].
  ///
  /// The [execute] callback takes a parameter, allowing you to pass dynamic
  /// values from UI callbacks (e.g., `onSelectionChanged`, `onChanged`).
  ///
  /// Example with SegmentedButton:
  /// ```dart
  /// Command.param<TabViewModel, TabType>(
  ///   command: (vm) => vm.selectTabCommand,
  ///   builder: (context, execute, canExecute, isRunning) {
  ///     return SegmentedButton<TabType>(
  ///       segments: [...],
  ///       selected: {vm.selectedTab.value},
  ///       onSelectionChanged: (values) => execute(values.first),
  ///     );
  ///   },
  /// )
  /// ```
  static CommandWithParam<TViewModel, TParam>
      param<TViewModel extends ObservableObject, TParam>({
    Key? key,
    required dynamic Function(TViewModel vm) command,
    required Widget Function(
            BuildContext context,
            void Function(TParam) execute,
            bool Function(TParam) canExecute,
            bool isRunning)
        builder,
  }) {
    return CommandWithParam<TViewModel, TParam>(
      key: key,
      command: command,
      builder: builder,
    );
  }

  /// Selector function that extracts the command from the ViewModel.
  ///
  /// Must return a [RelayCommand] or [AsyncRelayCommand] instance.
  ///
  /// **Important:** Should return a stable reference to the command,
  /// not create a new command instance each time.
  final dynamic Function(TViewModel vm) command;

  /// Builder function that constructs the UI.
  ///
  /// Parameters:
  /// - [context]: BuildContext
  /// - [execute]: Callback to execute the command
  /// - [canExecute]: Whether the command can currently execute
  /// - [isRunning]: Whether the command is currently executing (always `false` for sync commands)
  final Widget Function(
    BuildContext context,
    VoidCallback execute,
    bool canExecute,
    bool isRunning,
  ) builder;

  @override
  State<Command<TViewModel>> createState() => _CommandState<TViewModel>();
}

class _CommandState<TViewModel extends ObservableObject>
    extends State<Command<TViewModel>> {
  late TViewModel _viewModel;
  late dynamic _commandInstance; // RelayCommand or AsyncRelayCommand
  VoidCallback? _listener;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Don't resolve ViewModel here - violates InheritedWidget rules
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      // Resolve ViewModel
      _viewModel = Fairy.of<TViewModel>(context);

      // Extract command
      _commandInstance = widget.command(_viewModel);

      // Subscribe to command changes (canExecute changes)
      _listener = () => setState(() {});
      _commandInstance.addListener(_listener);

      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(Command<TViewModel> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If command selector changed, rebind
    if (oldWidget.command != widget.command) {
      _removeListener();
      _commandInstance = widget.command(_viewModel);
      _listener = () => setState(() {});
      _commandInstance.addListener(_listener);
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    if (_listener != null) {
      _commandInstance.removeListener(_listener);
      _listener = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract execute, canExecute, and isRunning from command
    final VoidCallback execute;
    final bool canExecute;
    final bool isRunning;

    if (_commandInstance is RelayCommand) {
      final cmd = _commandInstance as RelayCommand;
      execute = cmd.execute;
      canExecute = cmd.canExecute;
      isRunning = false; // Sync commands never run asynchronously
    } else if (_commandInstance is AsyncRelayCommand) {
      final cmd = _commandInstance as AsyncRelayCommand;
      execute = cmd.execute;
      canExecute = cmd.canExecute;
      isRunning = cmd.isRunning; // Actual running state for async commands
    } else {
      throw StateError(
        'Command<$TViewModel> selector must return a RelayCommand or AsyncRelayCommand. '
        'Got: ${_commandInstance.runtimeType}. '
        'For parameterized commands, use Command.param<$TViewModel, TParam>() instead.',
      );
    }

    return widget.builder(context, execute, canExecute, isRunning);
  }
}

/// Internal widget that binds a parameterized command to UI.
///
/// Use [Command.param] factory instead of this class directly.
class CommandWithParam<TViewModel extends ObservableObject, TParam>
    extends StatefulWidget {
  const CommandWithParam({
    super.key,
    required this.command,
    required this.builder,
  });

  /// Selector function that extracts the parameterized command.
  final dynamic Function(TViewModel vm) command;

  /// Builder function that constructs the UI.
  ///
  /// Parameters:
  /// - [context]: BuildContext
  /// - [execute]: Callback to execute the command - pass the parameter at call time
  /// - [canExecute]: Function to check if command can execute with a given parameter
  /// - [isRunning]: Whether the command is currently executing (always `false` for sync commands)
  final Widget Function(
    BuildContext context,
    void Function(TParam) execute,
    bool Function(TParam) canExecute,
    bool isRunning,
  ) builder;

  @override
  State<CommandWithParam<TViewModel, TParam>> createState() =>
      _CommandWithParamState<TViewModel, TParam>();
}

class _CommandWithParamState<TViewModel extends ObservableObject, TParam>
    extends State<CommandWithParam<TViewModel, TParam>> {
  late TViewModel _viewModel;
  late dynamic _commandInstance;
  VoidCallback? _listener;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Don't resolve ViewModel here - violates InheritedWidget rules
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _viewModel = Fairy.of<TViewModel>(context);
      _commandInstance = widget.command(_viewModel);
      _listener = () => setState(() {});
      _commandInstance.addListener(_listener);
      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(CommandWithParam<TViewModel, TParam> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.command != widget.command) {
      _removeListener();
      _commandInstance = widget.command(_viewModel);
      _listener = () => setState(() {});
      _commandInstance.addListener(_listener);
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    if (_listener != null) {
      _commandInstance.removeListener(_listener);
      _listener = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final void Function(TParam) execute;
    final bool Function(TParam) canExecute;
    final bool isRunning;

    if (_commandInstance is RelayCommandWithParam<TParam>) {
      final cmd = _commandInstance as RelayCommandWithParam<TParam>;
      execute = cmd.execute;
      canExecute = cmd.canExecute;
      isRunning = false; // Sync commands never run asynchronously
    } else if (_commandInstance is AsyncRelayCommandWithParam<TParam>) {
      final cmd = _commandInstance as AsyncRelayCommandWithParam<TParam>;
      execute = cmd.execute;
      canExecute = cmd.canExecute;
      isRunning = cmd.isRunning; // Actual running state for async commands
    } else {
      throw StateError(
        'Command.param<$TViewModel, $TParam> selector must return a '
        'RelayCommandWithParam<$TParam> or AsyncRelayCommandWithParam<$TParam>. '
        'Got: ${_commandInstance.runtimeType}. '
        'For non-parameterized commands, use Command<$TViewModel>() instead.',
      );
    }

    return widget.builder(context, execute, canExecute, isRunning);
  }
}
