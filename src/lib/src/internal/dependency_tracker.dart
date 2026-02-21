import 'package:fairy/src/core/observable_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Internal dependency tracker using stack-based sessions with
/// InheritedWidget fallback for lazy builders.
///
/// NOT exported - implementation detail of Bind.viewModel's automatic tracking.
///
/// Stack-based (not Zone-based) for performance and stability.
/// InheritedWidget fallback enables deferred callbacks (ListView.builder)
/// to report property accesses.
///
/// Custom [InheritedElement] with [performRebuild] override ensures
/// build-phase child updates (SliverMultiBoxAdaptorElement.performRebuild)
/// capture accesses via the stack, isolating each widget's session correctly.
@internal
class DependencyTracker {
  // Stack of active tracking sessions (Flutter is single-threaded)
  static final List<_TrackingSession> _stack = [];

  // Stack of active context elements for layout-phase fallback.
  // Each _TrackingContextElement pushes itself on mount and pops on unmount.
  // The LAST element in the list is the most deeply nested, which is the
  // correct target for layout-phase deferred callbacks since layout
  // runs bottom-up (leaf → root).
  static final List<_TrackingContextElement> _contextStack = [];

  /// Whether there is an active tracking session.
  /// Optimizes reportAccess() by allowing early returns.
  static bool get isTracking => _stack.isNotEmpty;

  /// Reports ObservableNode access during current session.
  ///
  /// No-op if no session is active. Supports two modes:
  /// 1. Stack-based (primary): Synchronous build execution and
  ///    build-phase child updates (via performRebuild override)
  /// 2. Context-stack fallback: Layout-phase deferred callbacks
  ///    walk the context stack to find the correct session
  static void reportAccess(ObservableNode node) {
    // Stack-based session (primary - synchronous build + performRebuild)
    if (_stack.isNotEmpty) {
      _stack.last._accessed.add(node);
      return;
    }

    // Context-stack fallback (layout-phase deferred callbacks).
    // During layout, invokeLayoutCallback runs from within a specific
    // SliverMultiBoxAdaptorElement. The last context in _contextStack
    // is the most deeply nested tracking context — which is the correct
    // parent for that sliver element.
    if (_contextStack.isNotEmpty) {
      final element = _contextStack.last;
      final session = (element.widget as _TrackingContextWidget).session;
      session._accessed.add(node);
    }
  }

  /// Runs function within tracking session.
  ///
  /// Returns: (result, accessed nodes, optional session for deferred tracking).
  /// Exceptions preserve partial tracking before re-throwing.
  ///
  /// When [wrapWithContext] is true, wraps result with an InheritedWidget
  /// that enables both build-phase and layout-phase deferred tracking.
  static (T result, Set<ObservableNode> accessed, _TrackingSession? session)
      track<T>(
    T Function() fn, {
    bool wrapWithContext = false,
  }) {
    final session = _TrackingSession();
    _stack.add(session);

    try {
      final result = fn();

      // Wrap with tracking widgets to enable deferred callback tracking:
      // 1. _TrackingContextWidget (InheritedWidget): Custom element pushes
      //    session during update/performRebuild for build-phase tracking
      // 2. _TrackingLayoutWidget: Auto-detects box/sliver context and
      //    inserts RenderProxyBox for initial layout-phase tracking
      if (wrapWithContext && result is Widget) {
        return (
          _TrackingContextWidget(
            session: session,
            child: _TrackingLayoutWidget(
              session: session,
              child: result,
            ),
          ) as T,
          Set.from(session._accessed), // Snapshot for comparison
          session // For checking deferred accesses
        );
      }

      return (result, session._accessed, null);
    } catch (error) {
      // CRITICAL: Preserve partial tracking before re-throwing
      rethrow;
    } finally {
      // CRITICAL: Always pop session, even on exception
      final popped = _stack.removeLast();

      assert(
        identical(popped, session),
        'DependencyTracker stack corrupted',
      );
    }
  }

  /// Returns currently accessed nodes for exception handling.
  /// Used by BindObserver for partial tracking on build exceptions.
  static Set<ObservableNode> captureAccessed() {
    return _stack.isEmpty ? const {} : _stack.last._accessed;
  }
}

/// Tracking session collecting accessed ObservableNodes.
/// Stack-isolated - nested builds don't interfere.
class _TrackingSession {
  final Set<ObservableNode> _accessed = {};

  /// Snapshot of accessed nodes for deferred access comparison.
  Set<ObservableNode> getAccessedSnapshot() => Set.from(_accessed);
}

/// InheritedWidget propagating tracking session down the tree.
/// Enables deferred callbacks (itemBuilder) to report accesses.
///
/// Uses a custom [_TrackingContextElement] that:
/// 1. Pushes session onto stack during [update] and [performRebuild] —
///    covers build-phase child updates (SliverMultiBoxAdaptorElement)
/// 2. Registers on [_contextStack] on mount — covers layout-phase
///    deferred callbacks as fallback
///
/// The performRebuild override ensures each widget's session is correctly
/// isolated on the stack during the recursive element tree update,
/// preventing cross-widget tracking corruption when multiple Bind.viewModel
/// widgets exist in the same tree.
class _TrackingContextWidget extends InheritedWidget {
  final _TrackingSession session;

  const _TrackingContextWidget({
    required this.session,
    required super.child,
  });

  @override
  bool updateShouldNotify(_TrackingContextWidget oldWidget) {
    return false; // Session identity never changes
  }

  @override
  InheritedElement createElement() {
    return _TrackingContextElement(this);
  }
}

/// Custom InheritedElement that provides two tracking mechanisms:
///
/// 1. **Build phase** (via [update] + [performRebuild] overrides): Pushes
///    session onto [DependencyTracker._stack] during element updates and
///    rebuilds, including recursive child updates. This ensures that
///    [SliverMultiBoxAdaptorElement.performRebuild] (which rebuilds
///    existing sliver children via itemBuilder) captures property
///    accesses in the correct session — even with multiple Bind.viewModel
///    widgets in the tree.
///
/// 2. **Layout phase** (via [_contextStack] on mount/unmount): Registers
///    on a context stack for layout-phase deferred callback fallback
///    (e.g. new items created via [invokeLayoutCallback]).
class _TrackingContextElement extends InheritedElement {
  _TrackingContextElement(_TrackingContextWidget super.widget);

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    DependencyTracker._contextStack.add(this);
  }

  @override
  void unmount() {
    DependencyTracker._contextStack.remove(this);
    super.unmount();
  }

  @override
  void update(_TrackingContextWidget newWidget) {
    // Push session onto stack during update. When the parent rebuilds
    // (e.g. BindViewModelState.build), it creates a new _TrackingContextWidget
    // with a new session. The super.update() call triggers updateChild on
    // descendant elements, which may call SliverMultiBoxAdaptorElement.update()
    // → performRebuild() → itemBuilder. Wrapping this in the session push
    // ensures those itemBuilder accesses are captured correctly.
    final session = newWidget.session;
    DependencyTracker._stack.add(session);
    try {
      super.update(newWidget);
    } finally {
      DependencyTracker._stack.removeLast();
    }
  }

  @override
  void performRebuild() {
    // Push session onto stack during initial build (mount).
    // This covers the first frame where the element is newly created
    // and performRebuild is called to build descendant elements.
    final session = (widget as _TrackingContextWidget).session;
    DependencyTracker._stack.add(session);
    try {
      super.performRebuild();
    } finally {
      DependencyTracker._stack.removeLast();
    }
  }
}

/// Auto-detecting layout wrapper that inserts a [_BoxTrackingLayout]
/// (RenderProxyBox) in box contexts to capture layout-phase property
/// accesses during the initial build.
///
/// In sliver contexts (where inserting a RenderProxyBox would cause a
/// type mismatch), the wrapper is skipped and the [_contextStack]
/// fallback handles layout-phase tracking.
///
/// The RenderProxyBox approach works for the initial build because the
/// entire render tree is dirty and layout flows top-down through the
/// parent chain (including through relayout boundaries like RenderViewport).
/// For subsequent rebuilds, the [_TrackingContextElement.update] override
/// captures build-phase accesses instead.
class _TrackingLayoutWidget extends StatelessWidget {
  final _TrackingSession session;
  final Widget child;

  const _TrackingLayoutWidget({
    required this.session,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // In sliver context, skip box wrapping — the _contextStack fallback
    // handles layout-phase tracking for sliver scenarios.
    if (_isInSliverContext(context)) {
      return child;
    }
    return _BoxTrackingLayout(session: session, child: child);
  }

  /// Detects whether this widget is in a context that expects sliver children.
  /// If so, inserting a RenderProxyBox (a RenderBox) would cause a type error.
  static bool _isInSliverContext(BuildContext context) {
    final parent = context.findAncestorRenderObjectOfType<RenderObject>();
    if (parent == null) return false;

    // RenderViewport is a RenderBox whose children must be RenderSlivers
    if (parent is RenderViewport) return true;

    // RenderSliver subtypes: some expect sliver children, some expect box.
    // RenderSliverMultiBoxAdaptor (SliverList, SliverGrid, etc.) has box
    // children — box wrapper is safe there. For all other RenderSliver
    // subtypes (SliverPadding, SliverOpacity, etc.), assume sliver children
    // and skip the box wrapper. This is the safer default: skipping the
    // wrapper just loses the layout-phase optimization (falling back to
    // _contextStack), while inserting it incorrectly would crash.
    if (parent is RenderSliver && parent is! RenderSliverMultiBoxAdaptor) {
      return true;
    }

    return false;
  }
}

/// RenderObjectWidget that creates a [_BoxTrackingRenderBox] to push the
/// tracking session during [performLayout]. This captures property accesses
/// from deferred callbacks (itemBuilder, separatorBuilder) that execute
/// during the layout phase of the initial build.
class _BoxTrackingLayout extends SingleChildRenderObjectWidget {
  final _TrackingSession session;

  const _BoxTrackingLayout({
    required this.session,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _BoxTrackingRenderBox(session);
  }

  @override
  void updateRenderObject(
      BuildContext context, _BoxTrackingRenderBox renderObject) {
    renderObject.session = session;
  }
}

/// RenderProxyBox that pushes the tracking session onto the stack during
/// [performLayout]. When the child render tree is laid out (including
/// through RenderViewport → SliverList), any property accesses from
/// itemBuilder callbacks are captured in the correct session.
///
/// This is effective for the initial build because the entire render tree
/// is dirty and layout flows synchronously from parent to child through
/// all relayout boundaries. For subsequent builds, RenderViewport may
/// be laid out independently (since it IS a relayout boundary), so this
/// render object's [performLayout] may not be called — the
/// [_TrackingContextElement.update] override handles that case instead.
class _BoxTrackingRenderBox extends RenderProxyBox {
  _TrackingSession session;

  _BoxTrackingRenderBox(this.session);

  @override
  void performLayout() {
    DependencyTracker._stack.add(session);
    try {
      super.performLayout();
    } finally {
      DependencyTracker._stack.removeLast();
    }
  }
}
