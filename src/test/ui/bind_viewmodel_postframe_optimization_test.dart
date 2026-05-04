import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:fairy/src/ui/bind_widget.dart';

// Test ViewModels
class SimpleViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
  final message = ObservableProperty<String>('Hello');
}

class ListViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>([]);
}

void main() {
  group('Bind.viewModel - Post-Frame Callback Optimization', () {
    testWidgets(
        'Widgets WITHOUT lazy builders should work correctly (optimization path)',
        (tester) async {
      // This test verifies the optimization doesn't break normal (non-lazy) widgets
      final vm = SimpleViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<SimpleViewModel>(
              builder: (context, vm) {
                buildCount++;
                // Simple synchronous property access - no lazy builders
                return Text('${vm.counter.value} - ${vm.message.value}');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('0 - Hello'), findsOneWidget);

      // Change counter - should rebuild
      vm.counter.value = 5;
      await tester.pump();

      expect(buildCount, 2);
      expect(find.text('5 - Hello'), findsOneWidget);

      // Change message - should rebuild
      vm.message.value = 'World';
      await tester.pump();

      expect(buildCount, 3);
      expect(find.text('5 - World'), findsOneWidget);
    });

    testWidgets(
        'Widgets WITH lazy builders should track deferred accesses correctly',
        (tester) async {
      // This test verifies post-frame callback IS scheduled for lazy builders
      final vm = ListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<ListViewModel>(
              builder: (context, vm) {
                return ListView.builder(
                  itemCount: vm.items.value.length,
                  itemBuilder: (context, index) {
                    // Lazy builder - deferred property access
                    return Text(vm.items.value[index]);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Initially empty
      expect(find.byType(Text), findsNothing);

      // Add items - should track and rebuild
      vm.items.value = ['Item 1', 'Item 2', 'Item 3'];
      await tester.pump();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);

      // Update items - should rebuild
      vm.items.value = ['Updated'];
      await tester.pump();

      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Updated'), findsOneWidget);
    });

    testWidgets(
        'Mixed: synchronous + lazy builder accesses should both be tracked',
        (tester) async {
      final vm = ListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<ListViewModel>(
              builder: (context, vm) {
                // Synchronous access
                final count = vm.items.value.length;
                return Column(
                  children: [
                    Text('Count: $count'), // Synchronous
                    Expanded(
                      child: ListView.builder(
                        itemCount: count,
                        itemBuilder: (context, index) {
                          // Deferred access
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

      expect(find.text('Count: 0'), findsOneWidget);

      vm.items.value = ['A', 'B'];
      await tester.pump();

      expect(find.text('Count: 2'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('Empty ListView.builder should not cause issues',
        (tester) async {
      final vm = ListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<ListViewModel>(
              builder: (context, vm) {
                return ListView.builder(
                  itemCount: vm.items.value.length, // 0 initially
                  itemBuilder: (context, index) {
                    return Text(vm.items.value[index]);
                  },
                );
              },
            ),
          ),
        ),
      );

      // No items initially, itemBuilder never called
      expect(find.byType(Text), findsNothing);

      // Add items later
      vm.items.value = ['First'];
      await tester.pump();

      expect(find.text('First'), findsOneWidget);
    });

    testWidgets(
        'Conditional lazy builder (only shown sometimes) should track correctly',
        (tester) async {
      final vm = ListViewModel();
      var showList = false;

      Widget buildWidget() {
        return MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => showList = !showList),
                      child: const Text('Toggle'),
                    ),
                    Expanded(
                      child: Bind.viewModel<ListViewModel>(
                        builder: (context, vm) {
                          if (!showList) {
                            // No lazy builder when hidden
                            return const Text('Hidden');
                          }
                          return ListView.builder(
                            itemCount: vm.items.value.length,
                            itemBuilder: (context, index) {
                              return Text(vm.items.value[index]);
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
        );
      }

      await tester.pumpWidget(buildWidget());

      expect(find.text('Hidden'), findsOneWidget);

      // Toggle to show list
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // No items yet
      expect(find.text('Hidden'), findsNothing);

      // Add items
      vm.items.value = ['A', 'B'];
      await tester.pump();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);

      // Toggle to hide
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Hidden'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });

    testWidgets('Rapid builds without lazy builders should be efficient',
        (tester) async {
      final vm = SimpleViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<SimpleViewModel>(
              builder: (context, vm) {
                buildCount++;
                return Text('${vm.counter.value}');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Rapid updates - should coalesce
      for (var i = 1; i <= 10; i++) {
        vm.counter.value = i;
      }
      await tester.pump();

      // Only 1 rebuild for all updates (Flutter coalescing)
      expect(buildCount, 2);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('Widget disposal during post-frame callback should not crash',
        (tester) async {
      final vm = ListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<ListViewModel>(
              builder: (context, vm) {
                return ListView.builder(
                  itemCount: vm.items.value.length,
                  itemBuilder: (context, index) {
                    return Text(vm.items.value[index]);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Immediately remove widget (before post-frame callback executes)
      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: const SizedBox(),
          ),
        ),
      );

      // Should not crash
      expect(() => tester.pump(), returnsNormally);
    });

    testWidgets('GridView.builder should work with optimization',
        (tester) async {
      final vm = ListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<ListViewModel>(
              builder: (context, vm) {
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                  ),
                  itemCount: vm.items.value.length,
                  itemBuilder: (context, index) {
                    return Text(vm.items.value[index]);
                  },
                );
              },
            ),
          ),
        ),
      );

      vm.items.value = ['G1', 'G2', 'G3', 'G4'];
      await tester.pump();

      expect(find.text('G1'), findsOneWidget);
      expect(find.text('G2'), findsOneWidget);
      expect(find.text('G3'), findsOneWidget);
      expect(find.text('G4'), findsOneWidget);
    });

    testWidgets('ListView.separated should track separator builder correctly',
        (tester) async {
      final vm = ListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind.viewModel<ListViewModel>(
              builder: (context, vm) {
                return ListView.separated(
                  itemCount: vm.items.value.length,
                  itemBuilder: (context, index) {
                    return Text(vm.items.value[index]);
                  },
                  separatorBuilder: (context, index) {
                    // Another deferred callback
                    return const Divider();
                  },
                );
              },
            ),
          ),
        ),
      );

      vm.items.value = ['S1', 'S2'];
      await tester.pump();

      expect(find.text('S1'), findsOneWidget);
      expect(find.text('S2'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('Stress test: multiple creates/disposals with optimization',
        (tester) async {
      final vm = SimpleViewModel();

      for (var i = 0; i < 20; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: Bind.viewModel<SimpleViewModel>(
                builder: (context, vm) {
                  return Text('${vm.counter.value}');
                },
              ),
            ),
          ),
        );

        vm.counter.value = i;
        await tester.pump();

        expect(find.text('$i'), findsOneWidget);

        // Remove widget
        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [ViewModelFactory((_) => vm)],
              child: const SizedBox(),
            ),
          ),
        );
      }

      // No crashes or memory leaks
      expect(() => vm.counter.value = 100, returnsNormally);
    });

    testWidgets('Nested Bind.viewModel with different lazy builder patterns',
        (tester) async {
      final vm1 = SimpleViewModel();
      final vm2 = ListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (_) => vm1,
              (_) => vm2,
            ],
            child: Column(
              children: [
                // No lazy builder
                Bind.viewModel<SimpleViewModel>(
                  builder: (context, vm) {
                    return Text('Count: ${vm.counter.value}');
                  },
                ),
                // With lazy builder
                Expanded(
                  child: Bind.viewModel<ListViewModel>(
                    builder: (context, vm) {
                      return ListView.builder(
                        itemCount: vm.items.value.length,
                        itemBuilder: (context, index) {
                          return Text(vm.items.value[index]);
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

      expect(find.text('Count: 0'), findsOneWidget);

      vm1.counter.value = 5;
      await tester.pump();

      expect(find.text('Count: 5'), findsOneWidget);

      vm2.items.value = ['List Item'];
      await tester.pump();

      expect(find.text('List Item'), findsOneWidget);
    });
  });
}
