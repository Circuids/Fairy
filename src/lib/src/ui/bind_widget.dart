import 'package:flutter/widgets.dart';
import '../core/observable.dart';
import '../core/observable_node.dart';
import '../internal/dependency_tracker.dart';
import '../locator/fairy_resolver.dart';
import 'bind_viewmodel_widget.dart';

/// A widget that binds ViewModel data to UI with automatic type detection.
///
/// [Bind] is the core data binding widget in Fairy. It automatically detects
/// whether to use one-way or two-way binding based on what the [bind] returns:
///
/// **Two-way binding:** When [bind] returns an [ObservableProperty<TValue>],
/// the widget subscribes to that property and provides an `update` callback.
///
/// **One-way binding:** When [bind] returns a raw [TValue], the widget
/// subscribes to the entire ViewModel and the `update` callback is `null`.
///
/// ## Two-Way Binding Example:
/// ```dart
/// class UserViewModel extends ObservableObject {
///   late final ObservableProperty<String> userName;
///
///   UserViewModel() {
///     userName = ObservableProperty<String>('', parent: this);
///   }
/// }
///
/// Bind<UserViewModel, String>(
///   bind: (vm) => vm.userName,  // Returns ObservableProperty<String>
///   builder: (context, value, update) {
///     return TextField(
///       controller: TextEditingController(text: value),
///       onChanged: update,  // update is non-null for two-way binding
///     );
///   },
/// )
/// ```
///
/// ## One-Way Binding Example:
/// ```dart
/// class CounterViewModel extends ObservableObject {
///   late final ObservableProperty<int> count;
///
///   CounterViewModel() {
///     count = ObservableProperty<int>(0, parent: this);
///   }
///
///   int get doubled => count.value * 2;  // Computed property
/// }
///
/// Bind<CounterViewModel, int>(
///   bind: (vm) => vm.doubled,  // Returns int (raw value)
///   builder: (context, value, update) {
///     return Text('$value');  // update is null for one-way binding
///   },
/// )
/// ```
///
/// **Critical:** Bind functions must return **stable references**. Never create
/// new [ObservableProperty] instances inside bind functions.
class Bind<TViewModel extends ObservableObject, TValue> extends StatefulWidget {
  const Bind({
    required this.bind,
    required this.builder,
    super.key,
    this.oneTime = false,
  });

  /// Bind function that extracts the bindable value from the ViewModel.
  ///
  /// Can return either:
  /// - [ObservableProperty<TValue>] for two-way binding
  /// - [TValue] for one-way binding
  ///
  /// **Must return stable references!** Don't create new objects in bind functions.
  final dynamic Function(TViewModel vm) bind;

  /// Builder function that constructs the UI.
  ///
  /// Parameters:
  /// - [context]: BuildContext
  /// - [value]: The current value of type [TValue]
  /// - [update]: Callback to update the value (non-null for two-way binding, null for one-way)
  final Widget Function(
    BuildContext context,
    TValue value,
    void Function(TValue)? update,
  ) builder;

  /// If true, only evaluates the selector once and never subscribes to changes.
  ///
  /// Useful for initial-value-only scenarios where reactivity isn't needed.
  final bool oneTime;

  /// Creates a binding that automatically observes all [ObservableNode] instances
  /// accessed during the builder function.
  ///
  /// This is Fairy's equivalent to Provider's Consumer or Riverpod's ConsumerWidget.
  /// Unlike the standard [Bind] constructor which requires explicit selectors,
  /// [viewModel] automatically tracks which properties and commands are accessed
  /// and only rebuilds when those specific nodes change.
  ///
  /// **When to use:**
  /// - Multiple properties from same ViewModel
  /// - Dynamic access patterns (conditional branches)
  /// - Command state tracking ([AsyncRelayCommand.isRunning])
  /// - Rapid prototyping
  ///
  /// **When NOT to use:**
  /// - Single property binding (use standard `Bind<TViewModel, TValue>`)
  /// - Performance-critical widgets (explicit selectors are 5-10% faster)
  ///
  /// Example:
  /// ```dart
  /// Bind.BindViewModel<CounterViewModel>(
  ///   builder: (context, vm) {
  ///     return Column(
  ///       children: [
  ///         Text('Count: ${vm.count.value}'),
  ///         Text('Max: ${vm.maxCount.value}'),
  ///         if (vm.saveCommand.isRunning)
  ///           CircularProgressIndicator(),
  ///       ],
  ///     );
  ///   },
  /// )
  /// ```
  static BindViewModel<TViewModel>
      viewModel<TViewModel extends ObservableObject>({
    Key? key,
    required Widget Function(BuildContext context, TViewModel vm) builder,
  }) {
    return BindViewModel<TViewModel>(
      key: key,
      builder: builder,
    );
  }

  /// Creates a binding that automatically observes all [ObservableNode] instances
  /// from two ViewModels accessed during the builder function.
  ///
  /// Example:
  /// ```dart
  /// Bind.BindViewModel2<UserViewModel, SettingsViewModel>(
  ///   builder: (context, user, settings) {
  ///     return Column(
  ///       children: [
  ///         Text('User: ${user.name.value}'),
  ///         Text('Theme: ${settings.theme.value}'),
  ///       ],
  ///     );
  ///   },
  /// )
  /// ```
  static BindViewModel2<TViewModel1, TViewModel2> viewModel2<
      TViewModel1 extends ObservableObject,
      TViewModel2 extends ObservableObject>({
    Key? key,
    required Widget Function(
            BuildContext context, TViewModel1 vm1, TViewModel2 vm2)
        builder,
  }) {
    assert(
      TViewModel1 != TViewModel2,
      'Bind.viewModel2 requires two different ViewModel types. '
      'Use Bind.viewModel instead for a single ViewModel type.',
    );
    return BindViewModel2<TViewModel1, TViewModel2>(
      key: key,
      builder: builder,
    );
  }

  /// Creates a binding that automatically observes all [ObservableNode] instances
  /// from three ViewModels accessed during the builder function.
  ///
  /// Example:
  /// ```dart
  /// Bind.BindViewModel3<UserViewModel, SettingsViewModel, DataViewModel>(
  ///   builder: (context, user, settings, data) {
  ///     return Column(
  ///       children: [
  ///         Text('User: ${user.name.value}'),
  ///         Text('Theme: ${settings.theme.value}'),
  ///         Text('Count: ${data.count.value}'),
  ///       ],
  ///     );
  ///   },
  /// )
  /// ```
  static BindViewModel3<TViewModel1, TViewModel2, TViewModel3> viewModel3<
      TViewModel1 extends ObservableObject,
      TViewModel2 extends ObservableObject,
      TViewModel3 extends ObservableObject>({
    Key? key,
    required Widget Function(
      BuildContext context,
      TViewModel1 vm1,
      TViewModel2 vm2,
      TViewModel3 vm3,
    ) builder,
  }) {
    assert(
      TViewModel1 != TViewModel2 &&
          TViewModel1 != TViewModel3 &&
          TViewModel2 != TViewModel3,
      'Bind.viewModel3 requires three different ViewModel types. '
      'Each type parameter must be unique.',
    );
    return BindViewModel3<TViewModel1, TViewModel2, TViewModel3>(
      key: key,
      builder: builder,
    );
  }

  /// Creates a binding that automatically binds based on Property that's been accessed
  /// from four ViewModels accessed during the builder function.
  ///
  /// Example:
  /// ```dart
  /// Bind.BindViewModel4<UserViewModel, SettingsViewModel, DataViewModel, CounterViewModel>(
  ///   builder: (context, user, settings, data) {
  ///     return Column(
  ///       children: [
  ///         Text('User: ${user.name.value}'),
  ///         Text('Theme: ${settings.theme.value}'),
  ///         Text('Count: ${data.count.value}'),
  ///         Text('Counter: ${counter.value}'),
  ///       ],
  ///     );
  ///   },
  /// )
  /// ```
  static BindViewModel4<TViewModel1, TViewModel2, TViewModel3, TViewModel4>
      viewModel4<
          TViewModel1 extends ObservableObject,
          TViewModel2 extends ObservableObject,
          TViewModel3 extends ObservableObject,
          TViewModel4 extends ObservableObject>({
    Key? key,
    required Widget Function(
      BuildContext context,
      TViewModel1 vm1,
      TViewModel2 vm2,
      TViewModel3 vm3,
      TViewModel4 vm4,
    ) builder,
  }) {
    assert(
      TViewModel1 != TViewModel2 &&
          TViewModel1 != TViewModel3 &&
          TViewModel1 != TViewModel4 &&
          TViewModel2 != TViewModel3 &&
          TViewModel2 != TViewModel4 &&
          TViewModel3 != TViewModel4,
      'Bind.viewModel4 requires four different ViewModel types. '
      'Each type parameter must be unique.',
    );
    return BindViewModel4<TViewModel1, TViewModel2, TViewModel3, TViewModel4>(
      key: key,
      builder: builder,
    );
  }

  @override
  State<Bind<TViewModel, TValue>> createState() =>
      _BindState<TViewModel, TValue>();
}

class _BindState<TViewModel extends ObservableObject, TValue>
    extends State<Bind<TViewModel, TValue>> {
  late TViewModel _viewModel;
  dynamic _selected; // Can be ObservableProperty<TValue> or TValue
  VoidCallback? _listener;
  VoidCallback? _listenerDisposer;
  List<VoidCallback>? _accessedNodesDisposers; // For one-way binding tracking
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) {
      return;
    }
    _initialized = true;

    // Resolve ViewModel from context
    _viewModel = Fairy.of<TViewModel>(context);

    // Evaluate bind with dependency tracking
    final (result, accessedNodes, _) =
        DependencyTracker.track(() => widget.bind(_viewModel));
    _selected = result;

    // Skip subscription for one-time binding
    if (widget.oneTime) {
      return;
    }

    // Subscribe based on what bind returned
    if (_selected is ObservableProperty<TValue>) {
      // Two-way binding: subscribe to the property directly
      _listener = () => setState(() {});
      _listenerDisposer =
          (_selected as ObservableProperty<TValue>).propertyChanged(_listener!);
    } else if (_selected is ComputedProperty<TValue>) {
      // One-way binding with ComputedProperty: subscribe to the computed property
      _listener = () => setState(() {});
      _listenerDisposer =
          (_selected as ComputedProperty<TValue>).propertyChanged(_listener!);
    } else {
      // One-way binding: subscribe to accessed nodes or fallback to ViewModel
      _listener = () => setState(() {
            // Re-evaluate bind on change
            final (newResult, _, _) =
                DependencyTracker.track(() => widget.bind(_viewModel));
            _selected = newResult;
          });

      if (accessedNodes.isNotEmpty) {
        // Subscribe to all nodes that were accessed during selector evaluation
        _accessedNodesDisposers = [];
        for (final node in accessedNodes) {
          node.addListener(_listener!);
          _accessedNodesDisposers!.add(() => node.removeListener(_listener!));
        }
      } else {
        // Fallback: No ObservableProperty accessed, subscribe to ViewModel
        // This handles plain getters that call onPropertyChanged()
        _listenerDisposer = _viewModel.propertyChanged(_listener!);
      }
    }
  }

  @override
  void didUpdateWidget(Bind<TViewModel, TValue> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If bind changed, rebind
    if (oldWidget.bind != widget.bind) {
      _removeListener();

      // Re-evaluate with tracking
      final (result, accessedNodes, _) =
          DependencyTracker.track(() => widget.bind(_viewModel));
      _selected = result;

      if (!widget.oneTime) {
        if (_selected is ObservableProperty<TValue>) {
          _listener = () => setState(() {});
          _listenerDisposer = (_selected as ObservableProperty<TValue>)
              .propertyChanged(_listener!);
        } else if (_selected is ComputedProperty<TValue>) {
          _listener = () => setState(() {});
          _listenerDisposer = (_selected as ComputedProperty<TValue>)
              .propertyChanged(_listener!);
        } else {
          // One-way binding: subscribe to accessed nodes or fallback to ViewModel
          _listener = () => setState(() {
                final (newResult, _, _) =
                    DependencyTracker.track(() => widget.bind(_viewModel));
                _selected = newResult;
              });

          if (accessedNodes.isNotEmpty) {
            _accessedNodesDisposers = [];
            for (final node in accessedNodes) {
              node.addListener(_listener!);
              _accessedNodesDisposers!
                  .add(() => node.removeListener(_listener!));
            }
          } else {
            // Fallback: No ObservableProperty accessed, subscribe to ViewModel
            _listenerDisposer = _viewModel.propertyChanged(_listener!);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    _listenerDisposer?.call();
    _listenerDisposer = null;

    // Dispose all accessed node listeners for one-way binding
    if (_accessedNodesDisposers != null) {
      for (final disposer in _accessedNodesDisposers!) {
        disposer();
      }
      _accessedNodesDisposers = null;
    }

    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in track() to create an isolated session. This prevents
    // property.value accesses from leaking into ancestor Bind.viewModel
    // tracking sessions (which push their session during element updates).
    // The session result is discarded — Bind manages its own subscriptions
    // via propertyChanged in didChangeDependencies.
    final (result, _, _) = DependencyTracker.track(() {
      // Extract value and update callback based on binding type
      if (_selected is ObservableProperty<TValue>) {
        // Two-way binding
        final property = _selected as ObservableProperty<TValue>;
        return widget.builder(
          context,
          property.value,
          (newValue) => property.value = newValue,
        );
      } else if (_selected is ComputedProperty<TValue>) {
        // One-way binding with ComputedProperty
        final computed = _selected as ComputedProperty<TValue>;
        return widget.builder(context, computed.value, null);
      } else {
        // One-way binding
        final value = _selected as TValue;
        return widget.builder(context, value, null);
      }
    });
    return result;
  }
}
