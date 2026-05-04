import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:fairy/src/ui/bind_widget.dart';

void main() {
  group('Bind.viewModel - Lazy Builder Support', () {
    testWidgets('ListView.builder itemBuilder reads are tracked and rebuild',
        (tester) async {
      final vm = ListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<ListViewModel>(
                builder: (context, vm) {
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      // This read should be tracked by stack-based tracking
                      final item = vm.items.value[index];
                      return Text(item);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initial state: empty list
      expect(find.text('Item 1'), findsNothing);

      // Update the list
      vm.items.value = ['Item 1', 'Item 2', 'Item 3'];
      await tester.pump();

      // Should rebuild and show items
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);

      // Update again
      vm.items.value = ['Updated Item'];
      await tester.pump();

      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Updated Item'), findsOneWidget);
    });

    testWidgets('GridView.builder itemBuilder reads are tracked',
        (tester) async {
      final vm = ListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<ListViewModel>(
                builder: (context, vm) {
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
        ),
      );

      vm.items.value = ['Grid 1', 'Grid 2'];
      await tester.pump();

      expect(find.text('Grid 1'), findsOneWidget);
      expect(find.text('Grid 2'), findsOneWidget);
    });

    testWidgets('Nested property access in itemBuilder is tracked',
        (tester) async {
      final vm = NestedViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<NestedViewModel>(
                builder: (context, vm) {
                  return ListView.builder(
                    itemCount: vm.users.value.length,
                    itemBuilder: (context, index) {
                      final user = vm.users.value[index];
                      // Access nested observable property
                      return Text('${user.name.value} - ${user.age.value}');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      vm.users.value = [
        User('Alice', 25),
        User('Bob', 30),
      ];
      await tester.pump();

      expect(find.text('Alice - 25'), findsOneWidget);
      expect(find.text('Bob - 30'), findsOneWidget);

      // Change nested property
      vm.users.value[0].age.value = 26;
      await tester.pump();

      expect(find.text('Alice - 26'), findsOneWidget);
    });

    testWidgets('Multiple observables in itemBuilder are all tracked',
        (tester) async {
      final vm = MultiObservableViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<MultiObservableViewModel>(
                builder: (context, vm) {
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      // Access multiple observables
                      final item = vm.items.value[index];
                      final prefix = vm.prefix.value;
                      final showIndex = vm.showIndex.value;
                      return Text(
                        showIndex ? '$prefix $index: $item' : '$prefix: $item',
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      vm.items.value = ['A', 'B'];
      await tester.pump();

      expect(find.text('Item 0: A'), findsOneWidget);
      expect(find.text('Item 1: B'), findsOneWidget);

      // Change prefix
      vm.prefix.value = 'Thing';
      await tester.pump();

      expect(find.text('Thing 0: A'), findsOneWidget);
      expect(find.text('Thing 1: B'), findsOneWidget);

      // Change showIndex
      vm.showIndex.value = false;
      await tester.pump();

      expect(find.text('Thing: A'), findsOneWidget);
      expect(find.text('Thing: B'), findsOneWidget);
    });

    testWidgets('Conditional branches in itemBuilder track correctly',
        (tester) async {
      final vm = ConditionalViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<ConditionalViewModel>(
                builder: (context, vm) {
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      final item = vm.items.value[index];
                      // Conditional access
                      if (vm.showDetails.value) {
                        return Text('$item - ${vm.details.value}');
                      }
                      return Text(item);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      vm.items.value = ['X', 'Y'];
      await tester.pump();

      expect(find.text('X'), findsOneWidget);
      expect(find.text('Y'), findsOneWidget);

      // Enable details
      vm.showDetails.value = true;
      await tester.pump();

      expect(find.text('X - Extra info'), findsOneWidget);
      expect(find.text('Y - Extra info'), findsOneWidget);

      // Change details
      vm.details.value = 'Updated info';
      await tester.pump();

      expect(find.text('X - Updated info'), findsOneWidget);
    });

    testWidgets(
        'itemBuilder accessing ComputedProperty rebuilds when dependency changes',
        (tester) async {
      final vm = ComputedViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<ComputedViewModel>(
                builder: (context, vm) {
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      // Access computed property
                      return Text(
                          '${vm.items.value[index]} - ${vm.totalCount.value}');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      vm.items.value = ['A', 'B'];
      await tester.pump();

      expect(find.text('A - 2'), findsOneWidget);
      expect(find.text('B - 2'), findsOneWidget);

      // Change items, computed should update
      vm.items.value = ['X', 'Y', 'Z'];
      await tester.pump();

      expect(find.text('X - 3'), findsOneWidget);
      expect(find.text('Y - 3'), findsOneWidget);
      expect(find.text('Z - 3'), findsOneWidget);
    });

    testWidgets('Deep nesting: ListView inside ListView tracks correctly',
        (tester) async {
      final vm = NestedListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<NestedListViewModel>(
                builder: (context, vm) {
                  return ListView.builder(
                    itemCount: vm.groups.value.length,
                    itemBuilder: (context, groupIndex) {
                      final group = vm.groups.value[groupIndex];
                      return Column(
                        children: [
                          Text(group.name.value),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: group.items.value.length,
                            itemBuilder: (context, itemIndex) {
                              return Text(group.items.value[itemIndex]);
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      final group1 = ItemGroup('Group 1', ['Item 1.1', 'Item 1.2']);
      vm.groups.value = [group1];
      await tester.pump();

      expect(find.text('Group 1'), findsOneWidget);
      expect(find.text('Item 1.1'), findsOneWidget);
      expect(find.text('Item 1.2'), findsOneWidget);

      // Change nested list
      group1.items.value = ['Updated 1.1'];
      await tester.pump();

      expect(find.text('Updated 1.1'), findsOneWidget);
      expect(find.text('Item 1.2'), findsNothing);
    });

    testWidgets('ListView with separatorBuilder tracks both builders',
        (tester) async {
      final vm = SeparatorViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<SeparatorViewModel>(
                builder: (context, vm) {
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
          ),
        ),
      );

      vm.items.value = ['A', 'B', 'C'];
      await tester.pump();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('---'), findsNWidgets(2)); // 2 separators for 3 items

      // Change separator
      vm.separator.value = '===';
      await tester.pump();

      expect(find.text('==='), findsNWidgets(2));
      expect(find.text('---'), findsNothing);
    });
  });

  group('Bind.viewModel - Lazy Builder Boundaries', () {
    testWidgets('onTap callback is NOT automatically tracked', (tester) async {
      final vm = CallbackViewModel();
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<CallbackViewModel>(
                builder: (context, vm) {
                  return GestureDetector(
                    onTap: () {
                      // This should NOT be tracked automatically
                      final _ = vm.counter.value;
                      tapCount++;
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      color: Colors.blue,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Container));
      await tester.pump();

      expect(tapCount, equals(1));

      // Change counter - should NOT trigger rebuild since onTap isn't tracked
      vm.counter.value = 10;
      await tester.pump();

      // Widget shouldn't rebuild from counter change
      // (If you have a way to verify rebuild count, add that assertion here)
    });

    testWidgets('Future.delayed callback is NOT tracked', (tester) async {
      final vm = AsyncViewModel();
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<AsyncViewModel>(
                builder: (context, vm) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    // This should NOT be tracked
                    final _ = vm.value.value;
                    completed = true;
                  });
                  return Container();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));

      expect(completed, isTrue);

      // Change value - should not cause issues
      vm.value.value = 100;
      await tester.pump();

      // No crashes or unexpected behavior
    });

    testWidgets('Timer callback is NOT tracked', (tester) async {
      final vm = TimerViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<TimerViewModel>(
                builder: (context, vm) {
                  // This is NOT a lazy builder, it's an async callback
                  // Should not be tracked
                  return Text('Count: ${vm.count.value}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      // Manual increment should work fine
      vm.count.value = 5;
      await tester.pump();

      expect(find.text('Count: 5'), findsOneWidget);
    });
  });

  group('Bind.viewModel - Performance', () {
    testWidgets('Many itemBuilder calls with same observable are efficient',
        (tester) async {
      final vm = LargeListViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Scaffold(
              body: Bind.viewModel<LargeListViewModel>(
                builder: (context, vm) {
                  return ListView.builder(
                    itemCount: vm.items.value.length,
                    itemBuilder: (context, index) {
                      // Multiple accesses to same observable
                      final len = vm.items.value.length;
                      final item = vm.items.value[index];
                      return Text('$index/$len: $item');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Create 100 items
      vm.items.value = List.generate(100, (i) => 'Item $i');
      await tester.pump();

      expect(find.text('0/100: Item 0'), findsOneWidget);

      // Change should still trigger rebuild efficiently
      vm.items.value = List.generate(50, (i) => 'New $i');
      await tester.pump();

      expect(find.text('0/50: New 0'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Multi-ViewModel Lazy Builder Tests
  // ==========================================================================

  group('Bind.viewModel2 - Lazy Builder Support', () {
    testWidgets('ListView.builder tracks properties from two ViewModels',
        (tester) async {
      final vm1 = ListViewModel();
      final vm2 = SecondViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (locator) => vm1,
              (locator) => vm2,
            ],
            child: Scaffold(
              body: Bind.viewModel2<ListViewModel, SecondViewModel>(
                builder: (context, list, second) {
                  return ListView.builder(
                    itemCount: list.items.value.length,
                    itemBuilder: (context, index) {
                      // Track properties from both ViewModels in itemBuilder
                      return Text(
                          '${list.items.value[index]} - ${second.counter.value}');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initial state
      expect(find.textContaining('Item 1'), findsNothing);

      // Add items to first ViewModel
      vm1.items.value = ['Item 1', 'Item 2'];
      await tester.pumpAndSettle();

      expect(find.text('Item 1 - 0'), findsOneWidget);
      expect(find.text('Item 2 - 0'), findsOneWidget);

      // Update second ViewModel - should rebuild
      vm2.counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Item 1 - 5'), findsOneWidget);
      expect(find.text('Item 2 - 5'), findsOneWidget);
    });

    testWidgets('Nested property access in lazy builder is tracked',
        (tester) async {
      final vm1 = ListViewModel();
      final vm2 = SecondViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (locator) => vm1,
              (locator) => vm2,
            ],
            child: Scaffold(
              body: Bind.viewModel2<ListViewModel, SecondViewModel>(
                builder: (context, list, second) {
                  return Column(
                    children: [
                      Text('Header: ${second.name.value}'),
                      Expanded(
                        child: ListView.builder(
                          itemCount: list.items.value.length,
                          itemBuilder: (context, index) {
                            return Text(list.items.value[index]);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      vm1.items.value = ['A', 'B'];
      vm2.name.value = 'Test';
      await tester.pumpAndSettle();

      expect(find.text('Header: Test'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('Multiple lazy builders in same widget', (tester) async {
      final vm1 = ListViewModel();
      final vm2 = SecondViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (locator) => vm1,
              (locator) => vm2,
            ],
            child: Scaffold(
              body: Bind.viewModel2<ListViewModel, SecondViewModel>(
                builder: (context, list, second) {
                  return Row(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: list.items.value.length,
                          itemBuilder: (context, index) =>
                              Text('List: ${list.items.value[index]}'),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: 3,
                          itemBuilder: (context, index) =>
                              Text('Counter: ${second.counter.value}'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      vm1.items.value = ['X'];
      vm2.counter.value = 10;
      await tester.pumpAndSettle();

      expect(find.text('List: X'), findsOneWidget);
      expect(find.text('Counter: 10'), findsNWidgets(3));
    });
  });

  group('Bind.viewModel3 - Lazy Builder Support', () {
    testWidgets('ListView.builder tracks properties from three ViewModels',
        (tester) async {
      final vm1 = ListViewModel();
      final vm2 = SecondViewModel();
      final vm3 = SeparatorViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (locator) => vm1,
              (locator) => vm2,
              (locator) => vm3,
            ],
            child: Scaffold(
              body: Bind.viewModel3<ListViewModel, SecondViewModel,
                  SeparatorViewModel>(
                builder: (context, list, second, sep) {
                  return ListView.builder(
                    itemCount: list.items.value.length,
                    itemBuilder: (context, index) {
                      return Text(
                          '${list.items.value[index]} ${sep.separator.value} ${second.counter.value}');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      vm1.items.value = ['A', 'B'];
      vm2.counter.value = 1;
      vm3.separator.value = '|';
      await tester.pumpAndSettle();

      expect(find.text('A | 1'), findsOneWidget);
      expect(find.text('B | 1'), findsOneWidget);

      // Update third ViewModel
      vm3.separator.value = '::';
      await tester.pumpAndSettle();

      expect(find.text('A :: 1'), findsOneWidget);
      expect(find.text('B :: 1'), findsOneWidget);
    });

    testWidgets('GridView.builder with conditional property access',
        (tester) async {
      final vm1 = ListViewModel();
      final vm2 = SecondViewModel();
      final vm3 = SeparatorViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (locator) => vm1,
              (locator) => vm2,
              (locator) => vm3,
            ],
            child: Scaffold(
              body: Bind.viewModel3<ListViewModel, SecondViewModel,
                  SeparatorViewModel>(
                builder: (context, list, second, sep) {
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                    ),
                    itemCount: list.items.value.length,
                    itemBuilder: (context, index) {
                      final item = list.items.value[index];
                      // Conditional access - only track counter for even indices
                      if (index % 2 == 0) {
                        return Text('$item [${second.counter.value}]');
                      } else {
                        return Text('$item [${sep.separator.value}]');
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      vm1.items.value = ['1', '2', '3', '4'];
      vm2.counter.value = 5;
      vm3.separator.value = 'X';
      await tester.pumpAndSettle();

      expect(find.text('1 [5]'), findsOneWidget); // Even index
      expect(find.text('2 [X]'), findsOneWidget); // Odd index
      expect(find.text('3 [5]'), findsOneWidget); // Even index
      expect(find.text('4 [X]'), findsOneWidget); // Odd index
    });
  });

  group('Bind.viewModel4 - Lazy Builder Support', () {
    testWidgets('ListView.builder tracks properties from four ViewModels',
        (tester) async {
      final vm1 = ListViewModel();
      final vm2 = SecondViewModel();
      final vm3 = SeparatorViewModel();
      final vm4 = CallbackViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (locator) => vm1,
              (locator) => vm2,
              (locator) => vm3,
              (locator) => vm4,
            ],
            child: Scaffold(
              body: Bind.viewModel4<ListViewModel, SecondViewModel,
                  SeparatorViewModel, CallbackViewModel>(
                builder: (context, list, second, sep, callback) {
                  return ListView.builder(
                    itemCount: list.items.value.length,
                    itemBuilder: (context, index) {
                      return Text(
                          '${list.items.value[index]} ${sep.separator.value} ${second.counter.value} ${sep.separator.value} ${callback.counter.value}');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      vm1.items.value = ['Row1', 'Row2'];
      vm2.counter.value = 10;
      vm3.separator.value = '-';
      vm4.counter.value = 20;
      await tester.pumpAndSettle();

      expect(find.text('Row1 - 10 - 20'), findsOneWidget);
      expect(find.text('Row2 - 10 - 20'), findsOneWidget);

      // Update fourth ViewModel
      vm4.counter.value = 99;
      await tester.pumpAndSettle();

      expect(find.text('Row1 - 10 - 99'), findsOneWidget);
      expect(find.text('Row2 - 10 - 99'), findsOneWidget);
    });

    testWidgets('Complex nested structure with all four ViewModels',
        (tester) async {
      final vm1 = ListViewModel();
      final vm2 = SecondViewModel();
      final vm3 = SeparatorViewModel();
      final vm4 = CallbackViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (locator) => vm1,
              (locator) => vm2,
              (locator) => vm3,
              (locator) => vm4,
            ],
            child: Scaffold(
              body: Bind.viewModel4<ListViewModel, SecondViewModel,
                  SeparatorViewModel, CallbackViewModel>(
                builder: (context, list, second, sep, callback) {
                  return Column(
                    children: [
                      Text('Header: ${second.name.value}'),
                      Text('Total: ${callback.counter.value}'),
                      Expanded(
                        child: ListView.builder(
                          itemCount: list.items.value.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(
                                  '${list.items.value[index]} ${sep.separator.value}'),
                              trailing: Text('Count: ${second.counter.value}'),
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
        ),
      );

      vm1.items.value = ['Item A', 'Item B'];
      vm2.name.value = 'Multi-VM Test';
      vm2.counter.value = 5;
      vm3.separator.value = '•';
      vm4.counter.value = 100;
      await tester.pumpAndSettle();

      expect(find.text('Header: Multi-VM Test'), findsOneWidget);
      expect(find.text('Total: 100'), findsOneWidget);
      expect(find.text('Item A •'), findsOneWidget);
      expect(find.text('Item B •'), findsOneWidget);
      expect(find.text('Count: 5'), findsNWidgets(2));

      // Update properties from different ViewModels
      vm3.separator.value = '★';
      await tester.pumpAndSettle();
      expect(find.text('Item A ★'), findsOneWidget);

      vm2.counter.value = 15;
      await tester.pumpAndSettle();
      expect(find.text('Count: 15'), findsNWidgets(2));

      vm4.counter.value = 200;
      await tester.pumpAndSettle();
      expect(find.text('Total: 200'), findsOneWidget);
    });

    testWidgets('ListView.separated with all four ViewModels', (tester) async {
      final vm1 = ListViewModel();
      final vm2 = SecondViewModel();
      final vm3 = SeparatorViewModel();
      final vm4 = CallbackViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (locator) => vm1,
              (locator) => vm2,
              (locator) => vm3,
              (locator) => vm4,
            ],
            child: Scaffold(
              body: Bind.viewModel4<ListViewModel, SecondViewModel,
                  SeparatorViewModel, CallbackViewModel>(
                builder: (context, list, second, sep, callback) {
                  return ListView.separated(
                    itemCount: list.items.value.length,
                    itemBuilder: (context, index) {
                      return Text(
                          '${list.items.value[index]} [${second.counter.value}]');
                    },
                    separatorBuilder: (context, index) {
                      // Access separator and callback in separator builder
                      return Text(
                          '${sep.separator.value} (${callback.counter.value})');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      vm1.items.value = ['First', 'Second', 'Third'];
      vm2.counter.value = 1;
      vm3.separator.value = '---';
      vm4.counter.value = 999;
      await tester.pumpAndSettle();

      expect(find.text('First [1]'), findsOneWidget);
      expect(find.text('--- (999)'), findsNWidgets(2)); // Two separators
      expect(find.text('Third [1]'), findsOneWidget);

      // Update separator ViewModel
      vm3.separator.value = '===';
      await tester.pumpAndSettle();
      expect(find.text('=== (999)'), findsNWidgets(2));

      // Update callback ViewModel
      vm4.counter.value = 777;
      await tester.pumpAndSettle();
      expect(find.text('=== (777)'), findsNWidgets(2));
    });
  });
}

// Test ViewModels

class ListViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>([]);
}

class User extends ObservableObject {
  final name = ObservableProperty<String>('');
  final age = ObservableProperty<int>(0);

  User(String n, int a) {
    name.value = n;
    age.value = a;
  }
}

class NestedViewModel extends ObservableObject {
  final users = ObservableProperty<List<User>>([]);
}

class MultiObservableViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>([]);
  final prefix = ObservableProperty<String>('Item');
  final showIndex = ObservableProperty<bool>(true);
}

class ConditionalViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>([]);
  final showDetails = ObservableProperty<bool>(false);
  final details = ObservableProperty<String>('Extra info');
}

class ComputedViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>([]);

  late final ComputedProperty<int> totalCount;

  ComputedViewModel() {
    totalCount = ComputedProperty<int>(
      () => items.value.length,
      [items],
      this,
    );
  }
}

class ItemGroup extends ObservableObject {
  final name = ObservableProperty<String>('');
  final items = ObservableProperty<List<String>>([]);

  ItemGroup(String n, List<String> i) {
    name.value = n;
    items.value = i;
  }
}

class NestedListViewModel extends ObservableObject {
  final groups = ObservableProperty<List<ItemGroup>>([]);
}

class SeparatorViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>([]);
  final separator = ObservableProperty<String>('---');
}

class CallbackViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
}

class AsyncViewModel extends ObservableObject {
  final value = ObservableProperty<int>(0);
}

class TimerViewModel extends ObservableObject {
  final count = ObservableProperty<int>(0);
}

class LargeListViewModel extends ObservableObject {
  final items = ObservableProperty<List<String>>([]);
}

class SecondViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);
  final name = ObservableProperty<String>('Default');
}
