import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:fairy/src/ui/bind_widget.dart';

// ─────────────────────────────────────────────────────────────
// Test ViewModels
// ─────────────────────────────────────────────────────────────

/// ViewModel with list items and a deferred-only property (highlight).
/// Used by tests where two Bind.viewModel widgets share the same VM.
class _SharedViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>(['a', 'b', 'c']);
  final highlight = ObservableProperty<String>('a');
  final label = ObservableProperty<String>('hello');
}

/// ViewModel A for cross-type isolation tests.
class _ViewModelA extends ObservableObject {
  final items = ObservableProperty<List<String>>(['x', 'y']);
  final marker = ObservableProperty<String>('x');
}

/// ViewModel B for cross-type isolation tests.
class _ViewModelB extends ObservableObject {
  final label = ObservableProperty<String>('initial');
}

// ─────────────────────────────────────────────────────────────
// Tests: _currentContext cross-widget tracking corruption
//
// Bug: DependencyTracker._currentContext is a single global static.
// When multiple Bind.viewModel widgets mount, the last one to mount
// overwrites _currentContext. Deferred accesses (e.g. ListView.builder's
// itemBuilder) from earlier-mounted widgets use the wrong session,
// causing missed rebuilds.
// ─────────────────────────────────────────────────────────────

void main() {
  group('Bind.viewModel — _currentContext cross-widget tracking correctness',
      () {
    // ───────────────────────────────────────────────────────
    // Test 1 (Baseline): Single widget with lazy builder
    // ───────────────────────────────────────────────────────
    testWidgets(
      'Test 1 (Baseline): Single Bind.viewModel with lazy builder '
      'tracks deferred-only property and rebuilds correctly',
      (tester) async {
        final vm = _SharedViewModel();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<_SharedViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      // highlight is accessed ONLY here (deferred callback)
                      // It is NOT accessed in the synchronous builder above
                      final isHighlighted =
                          vm.items.value[index] == vm.highlight.value;
                      return Text(
                        '${vm.items.value[index]}${isHighlighted ? " *" : ""}',
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(buildCount, 1);
        expect(find.text('a *'), findsOneWidget);
        expect(find.text('b'), findsOneWidget);
        expect(find.text('c'), findsOneWidget);

        // Change highlight — widget should rebuild via deferred tracking
        vm.highlight.value = 'b';
        await tester.pump();

        expect(
          buildCount,
          2,
          reason:
              'Single widget should rebuild when deferred-only property changes',
        );
        expect(find.text('a'), findsOneWidget);
        expect(find.text('b *'), findsOneWidget);
        expect(find.text('c'), findsOneWidget);
      },
    );

    // ───────────────────────────────────────────────────────
    // Test 2: Two Bind.viewModel widgets (same VM type)
    //   Widget A (first child, mounts first): lazy builder reading highlight
    //   Widget B (second child, mounts second): direct Text
    //   Bug: Widget B's mount overwrites _currentContext, so Widget A's
    //   deferred highlight access goes to Widget B's session.
    // ───────────────────────────────────────────────────────
    testWidgets(
      'Test 2: Two Bind.viewModel widgets (same VM) — deferred access in '
      'first widget should be tracked by first widget, not second',
      (tester) async {
        final vm = _SharedViewModel();
        var widgetABuildCount = 0;
        var widgetBBuildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Column(
                children: [
                  // Widget A — mounts FIRST, has lazy builder.
                  // highlight is accessed ONLY in itemBuilder (deferred).
                  Expanded(
                    child: Bind.viewModel<_SharedViewModel>(
                      builder: (context, vm) {
                        widgetABuildCount++;
                        return ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            final isHighlighted =
                                vm.items.value[index] == vm.highlight.value;
                            return Text(
                              'A:${vm.items.value[index]}${isHighlighted ? " *" : ""}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Widget B — mounts SECOND, overwrites _currentContext.
                  // Reads label directly (synchronous).
                  Bind.viewModel<_SharedViewModel>(
                    builder: (context, vm) {
                      widgetBBuildCount++;
                      return Text('B:${vm.label.value}');
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(widgetABuildCount, 1);
        expect(widgetBBuildCount, 1);
        expect(find.text('A:a *'), findsOneWidget);
        expect(find.text('B:hello'), findsOneWidget);

        // Change highlight —
        //   Widget A SHOULD rebuild (reads highlight in deferred itemBuilder)
        //   Widget B should NOT rebuild (doesn't access highlight at all)
        vm.highlight.value = 'b';
        await tester.pump();

        expect(
          widgetABuildCount,
          2,
          reason: 'Widget A should rebuild — highlight is accessed '
              'in its deferred itemBuilder',
        );
        expect(find.text('A:a'), findsOneWidget);
        expect(find.text('A:b *'), findsOneWidget);
        expect(find.text('A:c'), findsOneWidget);

        // Widget B must NOT have rebuilt (it doesn't access highlight)
        expect(
          widgetBBuildCount,
          1,
          reason: 'Widget B should NOT rebuild — it does not access highlight',
        );
      },
    );

    // ───────────────────────────────────────────────────────
    // Test 3: Two Bind.viewModel widgets (different VM types)
    //   Ensures deferred accesses don't cross-contaminate between VMs.
    // ───────────────────────────────────────────────────────
    testWidgets(
      'Test 3: Two Bind.viewModel widgets (different VMs) — deferred access '
      'in VmA should NOT leak to VmB tracking session',
      (tester) async {
        final vmA = _ViewModelA();
        final vmB = _ViewModelB();
        var widgetABuildCount = 0;
        var widgetBBuildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [
                (_) => vmA,
                (_) => vmB,
              ],
              child: Column(
                children: [
                  // Widget A — mounts FIRST, lazy builder accessing marker
                  Expanded(
                    child: Bind.viewModel<_ViewModelA>(
                      builder: (context, vm) {
                        widgetABuildCount++;
                        return ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            // marker accessed ONLY here (deferred)
                            final isMarked =
                                vm.items.value[index] == vm.marker.value;
                            return Text(
                              'A:${vm.items.value[index]}${isMarked ? " !" : ""}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Widget B — mounts SECOND, reads its own label
                  Bind.viewModel<_ViewModelB>(
                    builder: (context, vm) {
                      widgetBBuildCount++;
                      return Text('B:${vm.label.value}');
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(widgetABuildCount, 1);
        expect(widgetBBuildCount, 1);

        // Change vmA.marker — Widget A should rebuild, Widget B should NOT
        vmA.marker.value = 'y';
        await tester.pump();

        expect(
          widgetABuildCount,
          2,
          reason: 'Widget A should rebuild when marker changes '
              '(accessed in deferred itemBuilder)',
        );
        expect(find.text('A:x'), findsOneWidget);
        expect(find.text('A:y !'), findsOneWidget);

        expect(
          widgetBBuildCount,
          1,
          reason:
              'Widget B should NOT rebuild — vmA.marker is unrelated to VmB',
        );
      },
    );

    // ───────────────────────────────────────────────────────
    // Test 4: Scaffold body + bottomNavigationBar
    //   body mounts before bottomNavigationBar. Body has lazy builder
    //   accessing highlight. Bottom reads highlight directly.
    //   Both should rebuild when highlight changes.
    // ───────────────────────────────────────────────────────
    testWidgets(
      'Test 4: Scaffold body + bottomNavigationBar — mount order '
      'should not affect deferred tracking correctness',
      (tester) async {
        final vm = _SharedViewModel();
        var bodyBuildCount = 0;
        var bottomBuildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Scaffold(
                body: Bind.viewModel<_SharedViewModel>(
                  builder: (context, vm) {
                    bodyBuildCount++;
                    return ListView.builder(
                      itemCount: vm.items.value.length,
                      itemBuilder: (context, index) {
                        // highlight accessed ONLY in deferred itemBuilder
                        final isHighlighted =
                            vm.items.value[index] == vm.highlight.value;
                        return Text(
                          'Body:${vm.items.value[index]}${isHighlighted ? " *" : ""}',
                        );
                      },
                    );
                  },
                ),
                bottomNavigationBar: SizedBox(
                  height: 56,
                  child: Bind.viewModel<_SharedViewModel>(
                    builder: (context, vm) {
                      bottomBuildCount++;
                      return Center(
                        child: Text('Bottom:${vm.highlight.value}'),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        expect(bodyBuildCount, 1);
        expect(bottomBuildCount, 1);
        expect(find.text('Body:a *'), findsOneWidget);
        expect(find.text('Bottom:a'), findsOneWidget);

        // Change highlight — BOTH widgets should rebuild
        //   Body: reads highlight in deferred itemBuilder
        //   Bottom: reads highlight directly in builder
        vm.highlight.value = 'c';
        await tester.pump();

        expect(
          bodyBuildCount,
          2,
          reason: 'Body should rebuild — highlight accessed in '
              'deferred itemBuilder',
        );
        expect(find.text('Body:c *'), findsOneWidget);

        expect(
          bottomBuildCount,
          2,
          reason: 'Bottom should rebuild — highlight accessed directly',
        );
        expect(find.text('Bottom:c'), findsOneWidget);
      },
    );

    // ───────────────────────────────────────────────────────
    // Test 5: Three Bind.viewModel widgets — middle has lazy builder
    //   Widget 1: reads label (direct)
    //   Widget 2: reads highlight in lazy builder ONLY
    //   Widget 3: reads label (direct)
    //   Changing highlight should rebuild only Widget 2.
    // ───────────────────────────────────────────────────────
    testWidgets(
      'Test 5: Three Bind.viewModel widgets — only the widget with '
      'deferred access to changed property should rebuild',
      (tester) async {
        final vm = _SharedViewModel();
        var widget1BuildCount = 0;
        var widget2BuildCount = 0;
        var widget3BuildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Column(
                children: [
                  // Widget 1: reads label directly
                  Bind.viewModel<_SharedViewModel>(
                    builder: (context, vm) {
                      widget1BuildCount++;
                      return Text('W1:${vm.label.value}');
                    },
                  ),
                  // Widget 2: reads highlight ONLY in lazy builder
                  Expanded(
                    child: Bind.viewModel<_SharedViewModel>(
                      builder: (context, vm) {
                        widget2BuildCount++;
                        return ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            final isHighlighted =
                                vm.items.value[index] == vm.highlight.value;
                            return Text(
                              'W2:${vm.items.value[index]}${isHighlighted ? " *" : ""}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Widget 3: reads label directly
                  Bind.viewModel<_SharedViewModel>(
                    builder: (context, vm) {
                      widget3BuildCount++;
                      return Text('W3:${vm.label.value}');
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(widget1BuildCount, 1);
        expect(widget2BuildCount, 1);
        expect(widget3BuildCount, 1);

        // Change highlight — only Widget 2 should rebuild
        vm.highlight.value = 'b';
        await tester.pump();

        expect(
          widget2BuildCount,
          2,
          reason: 'Widget 2 should rebuild — highlight accessed '
              'in its deferred itemBuilder',
        );
        expect(find.text('W2:b *'), findsOneWidget);

        expect(
          widget1BuildCount,
          1,
          reason: 'Widget 1 should NOT rebuild — does not access highlight',
        );
        expect(
          widget3BuildCount,
          1,
          reason: 'Widget 3 should NOT rebuild — does not access highlight',
        );
      },
    );
  });
}
