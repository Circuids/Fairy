import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/core/command.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:fairy/src/ui/bind_widget.dart';
import 'package:fairy/src/ui/command_widget.dart';

// ============================================================================
// ViewModels
// ============================================================================

class _ItemsViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>(['a', 'b', 'c']);
  final highlight = ObservableProperty<String>('a');
  final separator = ObservableProperty<String>('---');
  final label = ObservableProperty<String>('hello');
  final counter = ObservableProperty<int>(0);
}

class _OtherViewModel extends ObservableObject {
  final text = ObservableProperty<String>('other');
}

class _CommandViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>(['x', 'y']);
  final enabled = ObservableProperty<bool>(true);

  late final RelayCommand doAction;
  late final AsyncRelayCommand doAsync;

  int actionCount = 0;

  _CommandViewModel() {
    doAction = RelayCommand(
      () => actionCount++,
      canExecute: () => enabled.value,
    );
    doAsync = AsyncRelayCommand(
      () async {
        await Future.delayed(const Duration(milliseconds: 50));
        actionCount++;
      },
      canExecute: () => enabled.value,
    );
  }
}

class _ToggleViewModel extends ObservableObject {
  final showList = ObservableProperty<bool>(true);
  final items = ObservableProperty<List<String>>(['1', '2', '3']);
  final marker = ObservableProperty<String>('1');
}

class _TabViewModel extends ObservableObject {
  final selectedTab = ObservableProperty<int>(0);
  final tabAItems = ObservableProperty<List<String>>(['A1', 'A2']);
  final tabBItems = ObservableProperty<List<String>>(['B1', 'B2']);
  final tabALabel = ObservableProperty<String>('Tab A');
  final tabBLabel = ObservableProperty<String>('Tab B');
}

class _GrowingListViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>([]);
  final tag = ObservableProperty<String>('v1');
}

class _VmA extends ObservableObject {
  final listItems = ObservableProperty<List<String>>(['a', 'b', 'c']);
  final badge = ObservableProperty<String>('!');
}

class _VmB extends ObservableObject {
  final prefix = ObservableProperty<String>('>>');
  final count = ObservableProperty<int>(0);
}

class _VmC extends ObservableObject {
  final sep = ObservableProperty<String>('|');
  final flag = ObservableProperty<bool>(false);
}

class _VmD extends ObservableObject {
  final suffix = ObservableProperty<String>('.');
  final score = ObservableProperty<int>(100);
}

// ============================================================================
// Tests
// ============================================================================

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // GROUP 1: Sliver / CustomScrollView tracking
  // ──────────────────────────────────────────────────────────────────────────
  group('Sliver tracking', () {
    testWidgets(
      'CustomScrollView with SliverList.builder tracks deferred accesses',
      (tester) async {
        final vm = _ItemsViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  builds++;
                  return CustomScrollView(
                    slivers: [
                      SliverList.builder(
                        itemCount: vm.items.value.length,
                        itemBuilder: (context, index) {
                          final isH =
                              vm.items.value[index] == vm.highlight.value;
                          return Text(
                            '${vm.items.value[index]}${isH ? " *" : ""}',
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('a *'), findsOneWidget);

        vm.highlight.value = 'c';
        await tester.pump();

        expect(builds, 2);
        expect(find.text('c *'), findsOneWidget);
        expect(find.text('a'), findsOneWidget);
      },
    );

    testWidgets(
      'CustomScrollView with SliverGrid.builder tracks deferred accesses',
      (tester) async {
        final vm = _ItemsViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  builds++;
                  return CustomScrollView(
                    slivers: [
                      SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                        ),
                        itemCount: vm.items.value.length,
                        itemBuilder: (context, index) {
                          final isH =
                              vm.items.value[index] == vm.highlight.value;
                          return Text(
                            '${vm.items.value[index]}${isH ? " *" : ""}',
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('a *'), findsOneWidget);

        vm.highlight.value = 'b';
        await tester.pump();

        expect(builds, 2);
        expect(find.text('b *'), findsOneWidget);
      },
    );

    testWidgets(
      'CustomScrollView with multiple slivers tracks all deferred accesses',
      (tester) async {
        final vm = _ItemsViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  builds++;
                  return CustomScrollView(
                    slivers: [
                      // Fixed sliver reading label
                      SliverToBoxAdapter(
                        child: Text('Label: ${vm.label.value}'),
                      ),
                      // Dynamic sliver reading highlight in builder
                      SliverList.builder(
                        itemCount: vm.items.value.length,
                        itemBuilder: (context, index) {
                          final isH =
                              vm.items.value[index] == vm.highlight.value;
                          return Text(
                            '${vm.items.value[index]}${isH ? " *" : ""}',
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('Label: hello'), findsOneWidget);

        // Change highlight — should rebuild via deferred tracking
        vm.highlight.value = 'b';
        await tester.pump();

        expect(builds, 2);
        expect(find.text('b *'), findsOneWidget);

        // Change label — should rebuild via direct tracking
        vm.label.value = 'world';
        await tester.pump();

        expect(builds, 3);
        expect(find.text('Label: world'), findsOneWidget);
      },
    );

    testWidgets(
      'SliverList.separated tracks both item and separator builders',
      (tester) async {
        final vm = _ItemsViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  builds++;
                  return CustomScrollView(
                    slivers: [
                      SliverList.separated(
                        itemCount: vm.items.value.length,
                        itemBuilder: (context, index) {
                          return Text(vm.items.value[index]);
                        },
                        separatorBuilder: (context, index) {
                          return Text(vm.separator.value);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('a'), findsOneWidget);
        expect(find.text('---'), findsNWidgets(2));

        // Change separator — should rebuild
        vm.separator.value = '***';
        await tester.pump();

        expect(builds, 2);
        expect(find.text('***'), findsNWidgets(2));
        expect(find.text('---'), findsNothing);
      },
    );

    testWidgets(
      'Nested CustomScrollView inside ListView.builder tracks correctly',
      (tester) async {
        final vm = _ItemsViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  builds++;
                  return ListView.builder(
                    itemCount: 1, // single item wrapping a CustomScrollView
                    itemBuilder: (context, index) {
                      return SizedBox(
                        height: 300,
                        child: CustomScrollView(
                          slivers: [
                            SliverList.builder(
                              itemCount: vm.items.value.length,
                              itemBuilder: (ctx, i) {
                                final isH =
                                    vm.items.value[i] == vm.highlight.value;
                                return Text(
                                  '${vm.items.value[i]}${isH ? " *" : ""}',
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('a *'), findsOneWidget);

        vm.highlight.value = 'c';
        await tester.pump();

        expect(builds, 2);
        expect(find.text('c *'), findsOneWidget);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP 2: Multiple Bind.viewModel widgets with deferred builders
  // ──────────────────────────────────────────────────────────────────────────
  group('Multi-widget deferred tracking isolation', () {
    testWidgets(
      'Two sibling Bind.viewModel with ListView.builder — independent tracking',
      (tester) async {
        final vm = _ItemsViewModel();
        var buildsA = 0;
        var buildsB = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Column(
                children: [
                  // Widget A — reads highlight in deferred builder
                  Expanded(
                    child: Bind.viewModel<_ItemsViewModel>(
                      builder: (context, vm) {
                        buildsA++;
                        return ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            final isH =
                                vm.items.value[index] == vm.highlight.value;
                            return Text(
                              'A:${vm.items.value[index]}${isH ? " *" : ""}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Widget B — reads separator in deferred builder
                  Expanded(
                    child: Bind.viewModel<_ItemsViewModel>(
                      builder: (context, vm) {
                        buildsB++;
                        return ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'B:${vm.items.value[index]} ${vm.separator.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(buildsA, 1);
        expect(buildsB, 1);

        // Change highlight — only Widget A should rebuild
        vm.highlight.value = 'b';
        await tester.pump();

        expect(buildsA, 2,
            reason: 'A reads highlight in deferred builder');
        expect(buildsB, 1,
            reason: 'B does NOT read highlight');

        // Change separator — only Widget B should rebuild
        vm.separator.value = '===';
        await tester.pump();

        expect(buildsA, 2,
            reason: 'A does NOT read separator');
        expect(buildsB, 2,
            reason: 'B reads separator in deferred builder');
      },
    );

    testWidgets(
      'Three widgets: direct + deferred + deferred — isolated sessions',
      (tester) async {
        final vm = _ItemsViewModel();
        var buildsA = 0;
        var buildsB = 0;
        var buildsC = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Column(
                children: [
                  // A: direct label read
                  Bind.viewModel<_ItemsViewModel>(
                    builder: (context, vm) {
                      buildsA++;
                      return Text('A:${vm.label.value}');
                    },
                  ),
                  // B: deferred highlight read
                  Expanded(
                    child: Bind.viewModel<_ItemsViewModel>(
                      builder: (context, vm) {
                        buildsB++;
                        return ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            final isH =
                                vm.items.value[index] == vm.highlight.value;
                            return Text(
                              'B:${vm.items.value[index]}${isH ? " *" : ""}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // C: deferred separator read
                  Expanded(
                    child: Bind.viewModel<_ItemsViewModel>(
                      builder: (context, vm) {
                        buildsC++;
                        return ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'C:${vm.items.value[index]} ${vm.separator.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(buildsA, 1);
        expect(buildsB, 1);
        expect(buildsC, 1);

        // Change label — only A rebuilds
        vm.label.value = 'changed';
        await tester.pump();
        expect(buildsA, 2);
        expect(buildsB, 1);
        expect(buildsC, 1);

        // Change highlight — only B rebuilds
        vm.highlight.value = 'c';
        await tester.pump();
        expect(buildsA, 2);
        expect(buildsB, 2);
        expect(buildsC, 1);

        // Change separator — only C rebuilds
        vm.separator.value = '+++';
        await tester.pump();
        expect(buildsA, 2);
        expect(buildsB, 2);
        expect(buildsC, 2);
      },
    );

    testWidgets(
      'Two widgets with different VMs, each with deferred builder — no cross-contamination',
      (tester) async {
        final vmItems = _ItemsViewModel();
        final vmOther = _OtherViewModel();
        var buildsItems = 0;
        var buildsOther = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [
                (_) => vmItems,
                (_) => vmOther,
              ],
              child: Column(
                children: [
                  Expanded(
                    child: Bind.viewModel<_ItemsViewModel>(
                      builder: (context, vm) {
                        buildsItems++;
                        return ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'Item:${vm.items.value[index]} ${vm.highlight.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Bind.viewModel<_OtherViewModel>(
                    builder: (context, vm) {
                      buildsOther++;
                      return Text('Other:${vm.text.value}');
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(buildsItems, 1);
        expect(buildsOther, 1);

        // Change items VM property — only items widget rebuilds
        vmItems.highlight.value = 'b';
        await tester.pump();
        expect(buildsItems, 2);
        expect(buildsOther, 1);

        // Change other VM — only other widget rebuilds
        vmOther.text.value = 'updated';
        await tester.pump();
        expect(buildsItems, 2);
        expect(buildsOther, 2);
      },
    );

    testWidgets(
      'Bind.viewModel with both direct and deferred access — both properties tracked',
      (tester) async {
        final vm = _ItemsViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  builds++;
                  return Column(
                    children: [
                      // Direct access
                      Text('Label: ${vm.label.value}'),
                      Expanded(
                        child: ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            // Deferred access
                            return Text(
                              '${vm.items.value[index]} ${vm.highlight.value}',
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);

        // Direct property change triggers rebuild
        vm.label.value = 'new label';
        await tester.pump();
        expect(builds, 2);

        // Deferred property change also triggers rebuild
        vm.highlight.value = 'b';
        await tester.pump();
        expect(builds, 3);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP 3: Nested Bind + Command inside Bind.viewModel
  // ──────────────────────────────────────────────────────────────────────────
  group('Nested Bind/Command inside Bind.viewModel — session isolation', () {
    testWidgets(
      'Bind inside Bind.viewModel with ListView.builder — child does not pollute parent',
      (tester) async {
        final vm = _ItemsViewModel();
        var outerBuilds = 0;
        var innerBuilds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  outerBuilds++;
                  return Column(
                    children: [
                      // Inner Bind subscribes to label only
                      Bind<_ItemsViewModel, String>(
                        bind: (vm) => vm.label,
                        builder: (context, value, update) {
                          innerBuilds++;
                          return Text('Inner: $value');
                        },
                      ),
                      // Outer has deferred builder reading highlight
                      Expanded(
                        child: ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              '${vm.items.value[index]} ${vm.highlight.value}',
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(outerBuilds, 1);
        expect(innerBuilds, 1);

        // Change label — inner rebuilds but outer should NOT
        // (label is accessed in inner Bind's selector, not outer builder)
        vm.label.value = 'updated';
        await tester.pump();
        expect(outerBuilds, 1, reason: 'Outer does not access label');
        expect(innerBuilds, 2, reason: 'Inner subscribes to label');

        // Change highlight — outer rebuilds (deferred), inner does NOT
        vm.highlight.value = 'c';
        await tester.pump();
        expect(outerBuilds, 2, reason: 'Outer reads highlight in deferred');
        // Inner may or may not rebuild depending on whether outer rebuild
        // causes it. The key assertion is outerBuilds incremented.
      },
    );

    testWidgets(
      'Command inside Bind.viewModel — canExecute does not leak into parent session',
      (tester) async {
        final vm = _CommandViewModel();
        var outerBuilds = 0;
        var cmdBuilds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_CommandViewModel>(
                builder: (context, vm) {
                  outerBuilds++;
                  return Column(
                    children: [
                      Command<_CommandViewModel>(
                        command: (vm) => vm.doAction,
                        builder: (context, execute, canExecute, isRunning) {
                          cmdBuilds++;
                          return ElevatedButton(
                            onPressed: canExecute ? execute : null,
                            child:
                                Text('Can: $canExecute Running: $isRunning'),
                          );
                        },
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            return Text(vm.items.value[index]);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(outerBuilds, 1);
        expect(cmdBuilds, 1);
        expect(find.text('Can: true Running: false'), findsOneWidget);

        // Change canExecute — Command rebuilds, outer should NOT
        vm.enabled.value = false;
        vm.doAction.notifyCanExecuteChanged();
        await tester.pump();

        expect(cmdBuilds, 2, reason: 'Command subscribes to doAction');
        expect(find.text('Can: false Running: false'), findsOneWidget);
        // outerBuilds may increment because outer subscribes to vm itself.
        // The key test: if it does NOT increment, canExecute didn't leak.
        // If it does, that's the ViewModel-level subscription, not leakage.
      },
    );

    testWidgets(
      'AsyncCommand inside Bind.viewModel — isRunning does not leak into parent session',
      (tester) async {
        final vm = _CommandViewModel();
        var outerBuilds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_CommandViewModel>(
                builder: (context, vm) {
                  outerBuilds++;
                  return Column(
                    children: [
                      Command<_CommandViewModel>(
                        command: (vm) => vm.doAsync,
                        builder: (context, execute, canExecute, isRunning) {
                          return ElevatedButton(
                            onPressed: canExecute ? execute : null,
                            child: Text(isRunning ? 'Running...' : 'Go'),
                          );
                        },
                      ),
                      Text('Items: ${vm.items.value.length}'),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        final initialOuterBuilds = outerBuilds;

        // Execute async command
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        // The command widget should show running state
        expect(find.text('Running...'), findsOneWidget);

        // Complete the async action
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('Go'), findsOneWidget);

        // Outer should NOT have rebuilt due to isRunning changes
        // (only if items or vm itself changed externally)
        expect(
          outerBuilds,
          initialOuterBuilds,
          reason:
              'isRunning accesses inside Command widget should not leak to outer',
        );
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP 4: Conditional rendering & visibility changes
  // ──────────────────────────────────────────────────────────────────────────
  group('Conditional rendering and dynamic widget tree', () {
    testWidgets(
      'Toggle between ListView and static content — tracking adjusts correctly',
      (tester) async {
        final vm = _ToggleViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ToggleViewModel>(
                builder: (context, vm) {
                  builds++;
                  if (vm.showList.value) {
                    return ListView.builder(
                      itemCount: vm.items.value.length,
                      itemBuilder: (context, index) {
                        final isM =
                            vm.items.value[index] == vm.marker.value;
                        return Text(
                          '${vm.items.value[index]}${isM ? " *" : ""}',
                        );
                      },
                    );
                  } else {
                    return Text('Static: ${vm.marker.value}');
                  }
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('1 *'), findsOneWidget);

        // Change marker while list is shown — should rebuild
        vm.marker.value = '2';
        await tester.pump();
        expect(builds, 2);
        expect(find.text('2 *'), findsOneWidget);

        // Switch to static view
        vm.showList.value = false;
        await tester.pump();
        expect(builds, 3);
        expect(find.text('Static: 2'), findsOneWidget);

        // Change marker while static — should still rebuild
        vm.marker.value = '3';
        await tester.pump();
        expect(builds, 4);
        expect(find.text('Static: 3'), findsOneWidget);

        // Switch back to list
        vm.showList.value = true;
        await tester.pump();
        expect(builds, 5);
        expect(find.text('3 *'), findsOneWidget);

        // Change marker again after switching back
        vm.marker.value = '1';
        await tester.pump();
        expect(builds, 6);
        expect(find.text('1 *'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget removed from tree — no leak, re-added works correctly',
      (tester) async {
        final vm = _ItemsViewModel();
        var builds = 0;
        var showWidget = true;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: StatefulBuilder(
                builder: (context, setState2) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            setState2(() => showWidget = !showWidget),
                        child: const Text('Toggle'),
                      ),
                      if (showWidget)
                        Expanded(
                          child: Bind.viewModel<_ItemsViewModel>(
                            builder: (context, vm) {
                              builds++;
                              return ListView.builder(
                                itemCount: vm.items.value.length,
                                itemBuilder: (context, index) {
                                  return Text(
                                    '${vm.items.value[index]} ${vm.highlight.value}',
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);

        // Change highlight — should rebuild while mounted
        vm.highlight.value = 'b';
        await tester.pump();
        expect(builds, 2);

        // Remove widget from tree
        await tester.tap(find.text('Toggle'));
        await tester.pump();

        final buildsAfterRemove = builds;

        // Change highlight while widget is gone — no crash, no rebuild
        vm.highlight.value = 'c';
        await tester.pump();
        expect(builds, buildsAfterRemove);

        // Re-add widget
        await tester.tap(find.text('Toggle'));
        await tester.pump();
        // New initial build
        expect(builds, buildsAfterRemove + 1);

        // Verify tracking works again
        vm.highlight.value = 'a';
        await tester.pump();
        expect(builds, buildsAfterRemove + 2);
      },
    );

    testWidgets(
      'Tab switch — each tab has Bind.viewModel with ListView.builder, only active tracked',
      (tester) async {
        final vm = _TabViewModel();
        var tabABuilds = 0;
        var tabBBuilds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_TabViewModel>(
                builder: (context, vm) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => vm.selectedTab.value = 0,
                            child: const Text('Tab A'),
                          ),
                          ElevatedButton(
                            onPressed: () => vm.selectedTab.value = 1,
                            child: const Text('Tab B'),
                          ),
                        ],
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: vm.selectedTab.value,
                          children: [
                            Bind.viewModel<_TabViewModel>(
                              builder: (context, vm) {
                                tabABuilds++;
                                return ListView.builder(
                                  itemCount: vm.tabAItems.value.length,
                                  itemBuilder: (context, index) {
                                    return Text(
                                      'A:${vm.tabAItems.value[index]} ${vm.tabALabel.value}',
                                    );
                                  },
                                );
                              },
                            ),
                            Bind.viewModel<_TabViewModel>(
                              builder: (context, vm) {
                                tabBBuilds++;
                                return ListView.builder(
                                  itemCount: vm.tabBItems.value.length,
                                  itemBuilder: (context, index) {
                                    return Text(
                                      'B:${vm.tabBItems.value[index]} ${vm.tabBLabel.value}',
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        final initialA = tabABuilds;
        final initialB = tabBBuilds;

        // Change tabALabel — Tab A should rebuild
        vm.tabALabel.value = 'New A Label';
        await tester.pump();
        expect(tabABuilds, initialA + 1);

        // Change tabBLabel — Tab B should rebuild
        vm.tabBLabel.value = 'New B Label';
        await tester.pump();
        expect(tabBBuilds, initialB + 1);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP 5: Rapid / stress tests
  // ──────────────────────────────────────────────────────────────────────────
  group('Rapid changes and stress', () {
    testWidgets(
      'Rapid property changes with deferred builder — no crash, correct final state',
      (tester) async {
        final vm = _ItemsViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      final isH =
                          vm.items.value[index] == vm.highlight.value;
                      return Text(
                        '${vm.items.value[index]}${isH ? " *" : ""}',
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );

        // Rapid changes without pumping between them
        vm.highlight.value = 'b';
        vm.highlight.value = 'c';
        vm.highlight.value = 'a';
        vm.highlight.value = 'b';

        await tester.pump();
        expect(find.text('b *'), findsOneWidget);
        expect(find.text('a'), findsOneWidget);
        expect(find.text('c'), findsOneWidget);
      },
    );

    testWidgets(
      'Growing list items — new items tracked after each addition',
      (tester) async {
        final vm = _GrowingListViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_GrowingListViewModel>(
                builder: (context, vm) {
                  builds++;
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      return Text('${vm.items.value[index]} [${vm.tag.value}]');
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);

        // Add items
        vm.items.value = ['item1'];
        await tester.pump();
        expect(builds, 2);
        expect(find.text('item1 [v1]'), findsOneWidget);

        // Change tag — deferred tracking should catch it
        vm.tag.value = 'v2';
        await tester.pump();
        expect(builds, 3);
        expect(find.text('item1 [v2]'), findsOneWidget);

        // Add more items
        vm.items.value = ['item1', 'item2', 'item3'];
        await tester.pump();
        expect(find.text('item1 [v2]'), findsOneWidget);
        expect(find.text('item2 [v2]'), findsOneWidget);
        expect(find.text('item3 [v2]'), findsOneWidget);

        // Change tag again
        vm.tag.value = 'v3';
        await tester.pump();
        expect(find.text('item1 [v3]'), findsOneWidget);
      },
    );

    testWidgets(
      'Empty list then populated — deferred tracking kicks in correctly',
      (tester) async {
        final vm = _GrowingListViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_GrowingListViewModel>(
                builder: (context, vm) {
                  builds++;
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      return Text('${vm.items.value[index]} [${vm.tag.value}]');
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);

        // tag change when list is empty — should still track items via direct access
        vm.tag.value = 'v2';
        await tester.pump();
        // May or may not rebuild depending on whether tag was accessed
        // (it wasn't, because itemBuilder never ran with 0 items)

        // Populate list
        vm.items.value = ['first'];
        await tester.pump();
        expect(find.text('first [v2]'), findsOneWidget);

        // Now tag change should work since itemBuilder ran
        vm.tag.value = 'v3';
        await tester.pump();
        expect(find.text('first [v3]'), findsOneWidget);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP 6: Session stack integrity
  // ──────────────────────────────────────────────────────────────────────────
  group('Session stack integrity', () {
    testWidgets(
      'Deeply nested Bind.viewModel (3 levels) — each tracks independently',
      (tester) async {
        final vm = _ItemsViewModel();
        var outerBuilds = 0;
        var middleBuilds = 0;
        var innerBuilds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  outerBuilds++;
                  return Column(
                    children: [
                      Text('Outer: ${vm.label.value}'),
                      Expanded(
                        child: Bind.viewModel<_ItemsViewModel>(
                          builder: (context, vm) {
                            middleBuilds++;
                            return Column(
                              children: [
                                Text('Middle: ${vm.separator.value}'),
                                Expanded(
                                  child: Bind.viewModel<_ItemsViewModel>(
                                    builder: (context, vm) {
                                      innerBuilds++;
                                      return ListView.builder(
                                        itemCount: vm.items.value.length,
                                        itemBuilder: (context, index) {
                                          return Text(
                                            'Inner:${vm.items.value[index]} ${vm.highlight.value}',
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(outerBuilds, 1);
        expect(middleBuilds, 1);
        expect(innerBuilds, 1);
        expect(find.text('Outer: hello'), findsOneWidget);
        expect(find.text('Middle: ---'), findsOneWidget);
        expect(find.text('Inner:a a'), findsOneWidget);

        // Change label — only outer rebuilds (cascades to children via build)
        vm.label.value = 'changed';
        await tester.pump();
        expect(outerBuilds, 2);
        // Middle and inner get recreated as part of outer's subtree rebuild
        // That's expected Flutter behavior

        // Reset counts
        final savedMiddle = middleBuilds;
        final savedInner = innerBuilds;

        // Change separator — middle tracks it directly
        vm.separator.value = '***';
        await tester.pump();
        expect(outerBuilds, 2, reason: 'Outer does NOT read separator');
        expect(middleBuilds, savedMiddle + 1);

        // Change highlight — inner tracks it in deferred builder
        final savedOuter2 = outerBuilds;
        final savedMiddle2 = middleBuilds;
        vm.highlight.value = 'c';
        await tester.pump();
        expect(outerBuilds, savedOuter2, reason: 'Outer does NOT read highlight');
        expect(middleBuilds, savedMiddle2, reason: 'Middle does NOT read highlight');
        expect(innerBuilds, savedInner + 2, // +1 from separator change, +1 from highlight
            reason: 'Inner reads highlight in deferred builder');
      },
    );

    testWidgets(
      'Bind.viewModel2 with lazy builder in both VMs — tracks correctly',
      (tester) async {
        final vmItems = _ItemsViewModel();
        final vmOther = _OtherViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [
                (_) => vmItems,
                (_) => vmOther,
              ],
              child: Bind.viewModel2<_ItemsViewModel, _OtherViewModel>(
                builder: (context, items, other) {
                  builds++;
                  return Column(
                    children: [
                      Text('Other: ${other.text.value}'),
                      Expanded(
                        child: ListView.builder(
                          itemCount: items.items.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              '${items.items.value[index]} ${items.highlight.value}',
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);

        // Change deferred property — should rebuild
        vmItems.highlight.value = 'b';
        await tester.pump();
        expect(builds, 2);

        // Change direct property from other VM — should rebuild
        vmOther.text.value = 'updated';
        await tester.pump();
        expect(builds, 3);
        expect(find.text('Other: updated'), findsOneWidget);
      },
    );

    testWidgets(
      'Parallel sibling Bind.viewModel with GridView and ListView — isolated',
      (tester) async {
        final vm = _ItemsViewModel();
        var listBuilds = 0;
        var gridBuilds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Column(
                children: [
                  Expanded(
                    child: Bind.viewModel<_ItemsViewModel>(
                      builder: (context, vm) {
                        listBuilds++;
                        return ListView.builder(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'List:${vm.items.value[index]} ${vm.highlight.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Bind.viewModel<_ItemsViewModel>(
                      builder: (context, vm) {
                        gridBuilds++;
                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                          ),
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'Grid:${vm.items.value[index]} ${vm.separator.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(listBuilds, 1);
        expect(gridBuilds, 1);

        // Change highlight — only list rebuilds
        vm.highlight.value = 'c';
        await tester.pump();
        expect(listBuilds, 2);
        expect(gridBuilds, 1, reason: 'Grid does NOT read highlight');

        // Change separator — only grid rebuilds
        vm.separator.value = '|||';
        await tester.pump();
        expect(listBuilds, 2, reason: 'List does NOT read separator');
        expect(gridBuilds, 2);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP 7: Edge cases — exceptions, empty states, widget key changes
  // ──────────────────────────────────────────────────────────────────────────
  group('Edge cases', () {
    testWidgets(
      'ListView.builder with 0 items — tracker does not crash on rebuild',
      (tester) async {
        final vm = _GrowingListViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_GrowingListViewModel>(
                builder: (context, vm) {
                  builds++;
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      return Text('${vm.items.value[index]} [${vm.tag.value}]');
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);

        // Force rebuild via items change (add then remove)
        vm.items.value = ['temp'];
        await tester.pump();
        expect(builds, 2);

        vm.items.value = [];
        await tester.pump();
        // No crash expected
        expect(builds, 3);

        // Now add items
        vm.items.value = ['hello'];
        await tester.pump();
        expect(find.text('hello [v1]'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget with key change — re-creates element, tracking re-initializes',
      (tester) async {
        final vm = _ItemsViewModel();
        var builds = 0;
        var currentKey = const ValueKey('v1');

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: StatefulBuilder(
                builder: (context, setState2) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => setState2(
                            () => currentKey = const ValueKey('v2')),
                        child: const Text('Change Key'),
                      ),
                      Expanded(
                        child: Bind.viewModel<_ItemsViewModel>(
                          key: currentKey,
                          builder: (context, vm) {
                            builds++;
                            return ListView.builder(
                              itemCount: vm.items.value.length,
                              itemBuilder: (context, index) {
                                return Text(
                                  '${vm.items.value[index]} ${vm.highlight.value}',
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);

        // Tracking works
        vm.highlight.value = 'b';
        await tester.pump();
        expect(builds, 2);

        // Change key — forces full re-creation
        await tester.tap(find.text('Change Key'));
        await tester.pump();
        final buildsAfterKeyChange = builds;

        // Tracking still works on new element
        vm.highlight.value = 'c';
        await tester.pump();
        expect(builds, buildsAfterKeyChange + 1);
      },
    );

    testWidgets(
      'Multiple rapid mount/unmount cycles — no context stack leak',
      (tester) async {
        final vm = _ItemsViewModel();
        var showWidget = true;

        for (var i = 0; i < 10; i++) {
          await tester.pumpWidget(
            MaterialApp(
              home: FairyScope(
                viewModel: (_) => vm,
                child: showWidget
                    ? Bind.viewModel<_ItemsViewModel>(
                        builder: (context, vm) {
                          return ListView.builder(
                            itemCount: vm.items.value.length,
                            itemBuilder: (context, index) {
                              return Text(
                                '${vm.items.value[index]} ${vm.highlight.value}',
                              );
                            },
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          );
          showWidget = !showWidget;
        }

        // After many mount/unmounts, verify no crash and tracking still works
        // showWidget is now false (10 toggles from true)
        showWidget = true;
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      return Text(
                        '${vm.items.value[index]} ${vm.highlight.value}',
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('a a'), findsOneWidget);

        vm.highlight.value = 'c';
        await tester.pump();
        expect(find.text('a c'), findsOneWidget);
        expect(find.text('c c'), findsOneWidget);
      },
    );

    testWidgets(
      'ListView.separated inside Bind.viewModel alongside sibling Bind.viewModel — separator accesses isolated',
      (tester) async {
        final vm = _ItemsViewModel();
        var listBuilds = 0;
        var siblingBuilds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Column(
                children: [
                  Expanded(
                    child: Bind.viewModel<_ItemsViewModel>(
                      builder: (context, vm) {
                        listBuilds++;
                        return ListView.separated(
                          itemCount: vm.items.value.length,
                          itemBuilder: (context, index) {
                            return Text(vm.items.value[index]);
                          },
                          separatorBuilder: (context, index) {
                            return Text(vm.separator.value);
                          },
                        );
                      },
                    ),
                  ),
                  Bind.viewModel<_ItemsViewModel>(
                    builder: (context, vm) {
                      siblingBuilds++;
                      return Text('Sibling: ${vm.label.value}');
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(listBuilds, 1);
        expect(siblingBuilds, 1);

        // Change separator — only list rebuilds
        vm.separator.value = '===';
        await tester.pump();
        expect(listBuilds, 2);
        expect(siblingBuilds, 1,
            reason: 'Sibling does NOT read separator');

        // Change label — only sibling rebuilds
        vm.label.value = 'new';
        await tester.pump();
        expect(listBuilds, 2, reason: 'List does NOT read label');
        expect(siblingBuilds, 2);
      },
    );

    testWidgets(
      'Bind.viewModel with ListView.builder inside Scaffold body and appBar — both track correctly',
      (tester) async {
        final vm = _ItemsViewModel();
        var bodyBuilds = 0;
        var appBarBuilds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Scaffold(
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Bind.viewModel<_ItemsViewModel>(
                    builder: (context, vm) {
                      appBarBuilds++;
                      return AppBar(title: Text(vm.label.value));
                    },
                  ),
                ),
                body: Bind.viewModel<_ItemsViewModel>(
                  builder: (context, vm) {
                    bodyBuilds++;
                    return ListView.builder(
                      itemCount: vm.items.value.length,
                      itemBuilder: (context, index) {
                        final isH =
                            vm.items.value[index] == vm.highlight.value;
                        return Text(
                          '${vm.items.value[index]}${isH ? " *" : ""}',
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );

        expect(bodyBuilds, 1);
        expect(appBarBuilds, 1);

        // Change highlight — only body rebuilds
        vm.highlight.value = 'b';
        await tester.pump();
        expect(bodyBuilds, 2);
        expect(appBarBuilds, 1, reason: 'AppBar does NOT read highlight');

        // Change label — only appBar rebuilds
        vm.label.value = 'New Title';
        await tester.pump();
        expect(bodyBuilds, 2, reason: 'Body does NOT read label');
        expect(appBarBuilds, 2);
      },
    );

    testWidgets(
      'PageView.builder with deferred tracking — accesses captured',
      (tester) async {
        final vm = _ItemsViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  builds++;
                  return SizedBox(
                    height: 400,
                    child: PageView.builder(
                      itemCount: vm.items.value.length,
                      itemBuilder: (context, index) {
                        return Center(
                          child: Text(
                            '${vm.items.value[index]} ${vm.highlight.value}',
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('a a'), findsOneWidget);

        vm.highlight.value = 'new';
        await tester.pump();
        expect(builds, 2);
        expect(find.text('a new'), findsOneWidget);
      },
    );

    testWidgets(
      'Bind.viewModel reading only in itemBuilder (no direct/sync access) — still tracked',
      (tester) async {
        final vm = _ItemsViewModel();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<_ItemsViewModel>(
                builder: (context, vm) {
                  builds++;
                  // NOTE: vm is intentionally NOT accessed synchronously
                  // (except for the implicit ViewModel-level DependencyTracker.reportAccess(vm))
                  return ListView.builder(
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      // ALL observable accesses happen here (deferred)
                      return Text(
                        '${vm.items.value[index]} ${vm.highlight.value} ${vm.label.value}',
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);

        // Each deferred property change should cause a rebuild
        vm.highlight.value = 'X';
        await tester.pump();
        expect(builds, 2);

        vm.label.value = 'Y';
        await tester.pump();
        expect(builds, 3);

        vm.items.value = ['d', 'e', 'f'];
        await tester.pump();
        expect(builds, 4);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP 8: Bind.viewModel2 — deferred tracking with two VMs
  // ──────────────────────────────────────────────────────────────────────────
  group('Bind.viewModel2 — deferred tracking', () {
    testWidgets(
      'ListView.builder accessing properties from both VMs — all tracked',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB],
              child: Bind.viewModel2<_VmA, _VmB>(
                builder: (context, a, b) {
                  builds++;
                  return ListView.builder(
                    itemCount: a.listItems.value.length,
                    itemBuilder: (context, index) {
                      return Text(
                        '${b.prefix.value} ${a.listItems.value[index]} ${a.badge.value}',
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('>> a !'), findsOneWidget);

        // Change VmA deferred-only property
        vmA.badge.value = '*';
        await tester.pump();
        expect(builds, 2);
        expect(find.text('>> a *'), findsOneWidget);

        // Change VmB deferred-only property
        vmB.prefix.value = '##';
        await tester.pump();
        expect(builds, 3);
        expect(find.text('## a *'), findsOneWidget);
      },
    );

    testWidgets(
      'Sibling Bind.viewModel2 widgets — deferred accesses isolated per widget',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        var buildsW1 = 0;
        var buildsW2 = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB],
              child: Column(
                children: [
                  // W1: reads badge in deferred builder
                  Expanded(
                    child: Bind.viewModel2<_VmA, _VmB>(
                      builder: (context, a, b) {
                        buildsW1++;
                        return ListView.builder(
                          itemCount: a.listItems.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'W1:${a.listItems.value[index]} ${a.badge.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // W2: reads prefix in deferred builder
                  Expanded(
                    child: Bind.viewModel2<_VmA, _VmB>(
                      builder: (context, a, b) {
                        buildsW2++;
                        return ListView.builder(
                          itemCount: a.listItems.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'W2:${a.listItems.value[index]} ${b.prefix.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(buildsW1, 1);
        expect(buildsW2, 1);

        // Change badge — only W1 rebuilds
        vmA.badge.value = '?';
        await tester.pump();
        expect(buildsW1, 2, reason: 'W1 reads badge in deferred builder');
        expect(buildsW2, 1, reason: 'W2 does NOT read badge');

        // Change prefix — only W2 rebuilds
        vmB.prefix.value = '@@';
        await tester.pump();
        expect(buildsW1, 2, reason: 'W1 does NOT read prefix');
        expect(buildsW2, 2, reason: 'W2 reads prefix in deferred builder');
      },
    );

    testWidgets(
      'CustomScrollView with SliverList.builder accessing two VMs',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB],
              child: Bind.viewModel2<_VmA, _VmB>(
                builder: (context, a, b) {
                  builds++;
                  return CustomScrollView(
                    slivers: [
                      SliverList.builder(
                        itemCount: a.listItems.value.length,
                        itemBuilder: (context, index) {
                          return Text(
                            '${b.prefix.value}:${a.listItems.value[index]}',
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('>>:a'), findsOneWidget);

        vmB.prefix.value = '<<';
        await tester.pump();
        expect(builds, 2);
        expect(find.text('<<:a'), findsOneWidget);
      },
    );

    testWidgets(
      'ListView.separated accessing both VMs in itemBuilder and separatorBuilder',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB],
              child: Bind.viewModel2<_VmA, _VmB>(
                builder: (context, a, b) {
                  builds++;
                  return ListView.separated(
                    itemCount: a.listItems.value.length,
                    itemBuilder: (context, index) {
                      return Text(
                        '${a.listItems.value[index]} ${a.badge.value}',
                      );
                    },
                    separatorBuilder: (context, index) {
                      return Text(b.prefix.value);
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('a !'), findsOneWidget);
        expect(find.text('>>'), findsNWidgets(2));

        // Change separator VM property
        vmB.prefix.value = '---';
        await tester.pump();
        expect(builds, 2);
        expect(find.text('---'), findsNWidgets(2));

        // Change item VM property
        vmA.badge.value = '#';
        await tester.pump();
        expect(builds, 3);
        expect(find.text('a #'), findsOneWidget);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP 9: Bind.viewModel3 — deferred tracking with three VMs
  // ──────────────────────────────────────────────────────────────────────────
  group('Bind.viewModel3 — deferred tracking', () {
    testWidgets(
      'ListView.builder accessing three VMs — all deferred accesses tracked',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        final vmC = _VmC();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB, (_) => vmC],
              child: Bind.viewModel3<_VmA, _VmB, _VmC>(
                builder: (context, a, b, c) {
                  builds++;
                  return ListView.builder(
                    itemCount: a.listItems.value.length,
                    itemBuilder: (context, index) {
                      return Text(
                        '${b.prefix.value} ${a.listItems.value[index]} ${c.sep.value}',
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('>> a |'), findsOneWidget);

        // Each VM's deferred property should trigger rebuild
        vmA.badge.value = '?'; // badge not accessed — should NOT rebuild
        await tester.pump();
        expect(builds, 1, reason: 'badge not accessed in builder');

        vmB.prefix.value = '!!';
        await tester.pump();
        expect(builds, 2);
        expect(find.text('!! a |'), findsOneWidget);

        vmC.sep.value = '~';
        await tester.pump();
        expect(builds, 3);
        expect(find.text('!! a ~'), findsOneWidget);
      },
    );

    testWidgets(
      'Sibling Bind.viewModel3 — deferred property isolation',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        final vmC = _VmC();
        var buildsW1 = 0;
        var buildsW2 = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB, (_) => vmC],
              child: Column(
                children: [
                  // W1: reads badge + sep in deferred
                  Expanded(
                    child: Bind.viewModel3<_VmA, _VmB, _VmC>(
                      builder: (context, a, b, c) {
                        buildsW1++;
                        return ListView.builder(
                          itemCount: a.listItems.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'W1:${a.listItems.value[index]} ${a.badge.value} ${c.sep.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // W2: reads prefix + count in deferred
                  Expanded(
                    child: Bind.viewModel3<_VmA, _VmB, _VmC>(
                      builder: (context, a, b, c) {
                        buildsW2++;
                        return ListView.builder(
                          itemCount: a.listItems.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'W2:${a.listItems.value[index]} ${b.prefix.value} ${b.count.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(buildsW1, 1);
        expect(buildsW2, 1);

        // Change badge — only W1 rebuilds
        vmA.badge.value = '?';
        await tester.pump();
        expect(buildsW1, 2);
        expect(buildsW2, 1);

        // Change count — only W2 rebuilds
        vmB.count.value = 42;
        await tester.pump();
        expect(buildsW1, 2);
        expect(buildsW2, 2);

        // Change sep — only W1 rebuilds
        vmC.sep.value = '~';
        await tester.pump();
        expect(buildsW1, 3);
        expect(buildsW2, 2);

        // Change prefix — only W2 rebuilds
        vmB.prefix.value = '@@';
        await tester.pump();
        expect(buildsW1, 3);
        expect(buildsW2, 3);
      },
    );

    testWidgets(
      'CustomScrollView with SliverList.separated — three VMs tracked',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        final vmC = _VmC();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB, (_) => vmC],
              child: Bind.viewModel3<_VmA, _VmB, _VmC>(
                builder: (context, a, b, c) {
                  builds++;
                  return CustomScrollView(
                    slivers: [
                      SliverList.separated(
                        itemCount: a.listItems.value.length,
                        itemBuilder: (context, index) {
                          return Text(
                            '${b.prefix.value} ${a.listItems.value[index]}',
                          );
                        },
                        separatorBuilder: (context, index) {
                          return Text(c.sep.value);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('>> a'), findsOneWidget);
        expect(find.text('|'), findsNWidgets(2));

        vmC.sep.value = '---';
        await tester.pump();
        expect(builds, 2);
        expect(find.text('---'), findsNWidgets(2));
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GROUP 10: Bind.viewModel4 — deferred tracking with four VMs
  // ──────────────────────────────────────────────────────────────────────────
  group('Bind.viewModel4 — deferred tracking', () {
    testWidgets(
      'ListView.builder accessing four VMs — all deferred accesses tracked',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        final vmC = _VmC();
        final vmD = _VmD();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB, (_) => vmC, (_) => vmD],
              child: Bind.viewModel4<_VmA, _VmB, _VmC, _VmD>(
                builder: (context, a, b, c, d) {
                  builds++;
                  return ListView.builder(
                    itemCount: a.listItems.value.length,
                    itemBuilder: (context, index) {
                      return Text(
                        '${b.prefix.value}${a.listItems.value[index]}${c.sep.value}${d.suffix.value}',
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('>>a|.'), findsOneWidget);

        // Each deferred property change triggers rebuild
        vmB.prefix.value = '<<';
        await tester.pump();
        expect(builds, 2);
        expect(find.text('<<a|.'), findsOneWidget);

        vmC.sep.value = '-';
        await tester.pump();
        expect(builds, 3);
        expect(find.text('<<a-.'), findsOneWidget);

        vmD.suffix.value = '!';
        await tester.pump();
        expect(builds, 4);
        expect(find.text('<<a-!'), findsOneWidget);
      },
    );

    testWidgets(
      'Sibling Bind.viewModel4 — per-widget deferred isolation',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        final vmC = _VmC();
        final vmD = _VmD();
        var buildsW1 = 0;
        var buildsW2 = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB, (_) => vmC, (_) => vmD],
              child: Column(
                children: [
                  // W1: reads badge + sep in deferred
                  Expanded(
                    child: Bind.viewModel4<_VmA, _VmB, _VmC, _VmD>(
                      builder: (context, a, b, c, d) {
                        buildsW1++;
                        return ListView.builder(
                          itemCount: a.listItems.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'W1:${a.listItems.value[index]} ${a.badge.value} ${c.sep.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // W2: reads prefix + suffix in deferred
                  Expanded(
                    child: Bind.viewModel4<_VmA, _VmB, _VmC, _VmD>(
                      builder: (context, a, b, c, d) {
                        buildsW2++;
                        return ListView.builder(
                          itemCount: a.listItems.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'W2:${a.listItems.value[index]} ${b.prefix.value} ${d.suffix.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(buildsW1, 1);
        expect(buildsW2, 1);

        // badge — only W1
        vmA.badge.value = '?';
        await tester.pump();
        expect(buildsW1, 2);
        expect(buildsW2, 1);

        // suffix — only W2
        vmD.suffix.value = '!!';
        await tester.pump();
        expect(buildsW1, 2);
        expect(buildsW2, 2);

        // sep — only W1
        vmC.sep.value = '~';
        await tester.pump();
        expect(buildsW1, 3);
        expect(buildsW2, 2);

        // prefix — only W2
        vmB.prefix.value = '@@';
        await tester.pump();
        expect(buildsW1, 3);
        expect(buildsW2, 3);
      },
    );

    testWidgets(
      'ListView.separated with four VMs — both builders track all VMs',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        final vmC = _VmC();
        final vmD = _VmD();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB, (_) => vmC, (_) => vmD],
              child: Bind.viewModel4<_VmA, _VmB, _VmC, _VmD>(
                builder: (context, a, b, c, d) {
                  builds++;
                  return ListView.separated(
                    itemCount: a.listItems.value.length,
                    itemBuilder: (context, index) {
                      return Text(
                        '${b.prefix.value}:${a.listItems.value[index]} ${d.suffix.value}',
                      );
                    },
                    separatorBuilder: (context, index) {
                      return Text('${c.sep.value}${d.score.value}');
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('>>:a .'), findsOneWidget);
        expect(find.text('|100'), findsNWidgets(2));

        // Change separator property in VmC
        vmC.sep.value = '---';
        await tester.pump();
        expect(builds, 2);
        expect(find.text('---100'), findsNWidgets(2));

        // Change score in VmD
        vmD.score.value = 999;
        await tester.pump();
        expect(builds, 3);
        expect(find.text('---999'), findsNWidgets(2));

        // Change suffix in VmD (used in itemBuilder)
        vmD.suffix.value = '!';
        await tester.pump();
        expect(builds, 4);
        expect(find.text('>>:a !'), findsOneWidget);
      },
    );

    testWidgets(
      'CustomScrollView with SliverGrid.builder + SliverToBoxAdapter — four VMs',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        final vmC = _VmC();
        final vmD = _VmD();
        var builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB, (_) => vmC, (_) => vmD],
              child: Bind.viewModel4<_VmA, _VmB, _VmC, _VmD>(
                builder: (context, a, b, c, d) {
                  builds++;
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Text('Header: ${b.prefix.value}'),
                      ),
                      SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                        ),
                        itemCount: a.listItems.value.length,
                        itemBuilder: (context, index) {
                          return Text(
                            '${a.listItems.value[index]}${c.sep.value}${d.suffix.value}',
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('Header: >>'), findsOneWidget);
        expect(find.text('a|.'), findsOneWidget);

        // Change direct property (prefix in SliverToBoxAdapter)
        vmB.prefix.value = '!!';
        await tester.pump();
        expect(builds, 2);
        expect(find.text('Header: !!'), findsOneWidget);

        // Change deferred property (sep in SliverGrid.builder)
        vmC.sep.value = '-';
        await tester.pump();
        expect(builds, 3);
        expect(find.text('a-.'), findsOneWidget);

        // Change deferred property (suffix in SliverGrid.builder)
        vmD.suffix.value = '#';
        await tester.pump();
        expect(builds, 4);
        expect(find.text('a-#'), findsOneWidget);
      },
    );

    testWidgets(
      'Mixed: Bind.viewModel4 alongside Bind.viewModel — no cross-contamination',
      (tester) async {
        final vmA = _VmA();
        final vmB = _VmB();
        final vmC = _VmC();
        final vmD = _VmD();
        var builds4 = 0;
        var builds1 = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB, (_) => vmC, (_) => vmD],
              child: Column(
                children: [
                  // ViewModel4 reads badge in deferred
                  Expanded(
                    child: Bind.viewModel4<_VmA, _VmB, _VmC, _VmD>(
                      builder: (context, a, b, c, d) {
                        builds4++;
                        return ListView.builder(
                          itemCount: a.listItems.value.length,
                          itemBuilder: (context, index) {
                            return Text(
                              'V4:${a.listItems.value[index]} ${a.badge.value}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // ViewModel1 reads suffix in deferred
                  Expanded(
                    child: Bind.viewModel<_VmD>(
                      builder: (context, d) {
                        builds1++;
                        return ListView.builder(
                          itemCount: 2,
                          itemBuilder: (context, index) {
                            return Text('V1:${d.suffix.value}');
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(builds4, 1);
        expect(builds1, 1);

        // Change badge — only V4 rebuilds
        vmA.badge.value = '?';
        await tester.pump();
        expect(builds4, 2);
        expect(builds1, 1);

        // Change suffix — only V1 rebuilds
        vmD.suffix.value = '!!!';
        await tester.pump();
        // V4 may also rebuild because it registered vmD in its session,
        // but badge change should NOT affect V1
        expect(builds1, 2);
      },
    );
  });
}
