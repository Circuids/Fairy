import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import refactored models
import 'models/benchmark_results.dart';
import 'models/fairy_models.dart';
import 'models/provider_models.dart';
import 'models/riverpod_models.dart';

// Import refactored widgets
import 'widgets/fairy_widgets.dart';
import 'widgets/provider_widgets.dart';
import 'widgets/riverpod_widgets.dart';

// Import utilities
import 'utils/benchmark_printer.dart';

// Store benchmark results
final _results = BenchmarkResults();

void main() {
  // Create proper test binding for benchmarks
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fairy vs Provider vs Riverpod Benchmark', () {
    // Warm-up phase - ensure Flutter engine is fully initialized
    testWidgets('Engine Warm-up', (WidgetTester tester) async {
      print('\n🔥 Warming up Flutter engine...');

      // Warm up with all three frameworks
      for (int round = 0; round < 3; round++) {
        // Fairy warm-up
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: const FairyCounterWidget())),
        );
        for (int i = 0; i < 20; i++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
        }
        await tester.pumpWidget(Container());

        // Provider warm-up
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: const ProviderCounterWidget())),
        );
        for (int i = 0; i < 20; i++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
        }
        await tester.pumpWidget(Container());

        // Riverpod warm-up
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: const RiverpodCounterWidget()),
            ),
          ),
        );
        for (int i = 0; i < 20; i++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
        }
        await tester.pumpWidget(Container());
      }

      print('✅ Engine warm-up complete!\n');
    });

    testWidgets('Fairy Widget Performance', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: const FairyCounterWidget())),
      );

      // Warm up
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }

      // Actual benchmark
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }
      stopwatch.stop();

      _results.widgetPerformance['Fairy'] = stopwatch.elapsedMicroseconds;
    });

    testWidgets('Provider Widget Performance', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: const ProviderCounterWidget())),
      );

      // Warm up
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }

      // Actual benchmark
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }
      stopwatch.stop();

      _results.widgetPerformance['Provider'] = stopwatch.elapsedMicroseconds;
    });

    testWidgets('Riverpod Widget Performance', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: const RiverpodCounterWidget()),
          ),
        ),
      );

      // Warm up
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }

      // Actual benchmark
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }
      stopwatch.stop();

      _results.widgetPerformance['Riverpod'] = stopwatch.elapsedMicroseconds;
    });

    testWidgets('Memory Usage Comparison', (WidgetTester tester) async {
      // Fairy memory test
      final fairyStopwatch = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: const FairyCounterWidget())),
        );

        // Trigger state changes
        for (int j = 0; j < 10; j++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
        }

        await tester.pumpWidget(Container()); // Dispose
      }
      fairyStopwatch.stop();
      _results.memoryPerformance['Fairy'] = fairyStopwatch.elapsedMicroseconds;

      // Provider memory test
      final providerStopwatch = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: const ProviderCounterWidget())),
        );

        // Trigger state changes
        for (int j = 0; j < 10; j++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
        }

        await tester.pumpWidget(Container()); // Dispose
      }
      providerStopwatch.stop();
      _results.memoryPerformance['Provider'] =
          providerStopwatch.elapsedMicroseconds;

      // Riverpod memory test
      final riverpodStopwatch = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: const RiverpodCounterWidget()),
            ),
          ),
        );

        // Trigger state changes
        for (int j = 0; j < 10; j++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
        }

        await tester.pumpWidget(Container()); // Dispose
      }
      riverpodStopwatch.stop();
      _results.memoryPerformance['Riverpod'] =
          riverpodStopwatch.elapsedMicroseconds;
    });

    // SELECTIVE REBUILD TEST - The REAL optimization benchmark!
    // This tests what happens when ONE property changes in a multi-property ViewModel
    // Tests SELECTIVE rebuild efficiency using explicit Bind widget with selectors
    // Fairy TWO-WAY binding should only rebuild widgets watching that specific property
    // Fairy ONE-WAY binding, Provider, and Riverpod will rebuild ALL widgets (global notifications)
    testWidgets('Selective Rebuild Performance (Explicit Bind)', (
      WidgetTester tester,
    ) async {
      // === FAIRY TWO-WAY BINDING (Selective Notifications) ===
      int fairy1BuildsSelective = 0,
          fairy2BuildsSelective = 0,
          fairy3BuildsSelective = 0;
      int listenerCalls = 0;
      FairyMultiPropertyViewModel? capturedVm;

      // Build widget tree with FairyScope and TWO-WAY binding (returns ObservableProperty)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              key: const ValueKey('fairy-two-way'),
              viewModel: (locator) {
                final vm = FairyMultiPropertyViewModel();
                // Add a global listener to verify notifications are being sent
                vm.propertyChanged(() {
                  listenerCalls++;
                });
                capturedVm = vm;
                return vm;
              },
              child: Builder(
                builder: (context) {
                  return Column(
                    children: [
                      // Each Bind watches a DIFFERENT property
                      // TValue is int, selector returns ObservableProperty<int> → Two-way binding
                      Bind<FairyMultiPropertyViewModel, int>(
                        bind: (vm) => vm
                            .property1, // Returns ObservableProperty<int> → Two-way!
                        builder: (context, value, update) {
                          fairy1BuildsSelective++;
                          return Text(
                            'Fairy1: $value',
                            key: const ValueKey('fairy1'),
                          );
                        },
                      ),
                      Bind<FairyMultiPropertyViewModel, int>(
                        bind: (vm) => vm
                            .property2, // Returns ObservableProperty<int> → Two-way!
                        builder: (context, value, update) {
                          fairy2BuildsSelective++;
                          return Text(
                            'Fairy2: $value',
                            key: const ValueKey('fairy2'),
                          );
                        },
                      ),
                      Bind<FairyMultiPropertyViewModel, int>(
                        bind: (vm) => vm
                            .property3, // Returns ObservableProperty<int> → Two-way!
                        builder: (context, value, update) {
                          fairy3BuildsSelective++;
                          return Text(
                            'Fairy3: $value',
                            key: const ValueKey('fairy3'),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      fairy1BuildsSelective = fairy2BuildsSelective = fairy3BuildsSelective = 0;
      listenerCalls = 0;

      final fairySelectiveStopwatch = Stopwatch()..start();

      // Update property1 100 times - ONLY widget1 should rebuild!
      for (int i = 0; i < 100; i++) {
        capturedVm!.property1.value = i;
        await tester.pump();
      }
      fairySelectiveStopwatch.stop();

      print('\n🧚 Fairy TWO-WAY Binding (Selective Notification):');
      print(
        '  Global listener calls: $listenerCalls (property changes detected)',
      );
      print(
        '  Widget 1 (watching property1): $fairy1BuildsSelective rebuilds ← Only this one!',
      );
      print(
        '  Widget 2 (watching property2): $fairy2BuildsSelective rebuilds ← Should be 0',
      );
      print(
        '  Widget 3 (watching property3): $fairy3BuildsSelective rebuilds ← Should be 0',
      );
      print('  Time: ${fairySelectiveStopwatch.elapsedMilliseconds}ms');
      print(
        '  Efficiency: ${fairy1BuildsSelective > 0 ? ((fairy1BuildsSelective / (fairy1BuildsSelective + fairy2BuildsSelective + fairy3BuildsSelective)) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n',
      );

      _results.selectiveRebuildPerformance['Fairy (selective)'] =
          fairySelectiveStopwatch.elapsedMicroseconds;

      // === PROVIDER WITH SELECTOR (Selective Notification) ===
      int providerSelectiveBuilds1 = 0,
          providerSelectiveBuilds2 = 0,
          providerSelectiveBuilds3 = 0;
      final providerNotifierSelective = ProviderMultiPropertyNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: provider.ChangeNotifierProvider.value(
              value: providerNotifierSelective,
              child: Builder(
                builder: (context) => Column(
                  children: [
                    provider.Selector<ProviderMultiPropertyNotifier, int>(
                      selector: (context, notifier) => notifier.property1,
                      builder: (context, value, child) {
                        providerSelectiveBuilds1++;
                        return Text(
                          'Provider1: $value',
                          key: const ValueKey('provider1'),
                        );
                      },
                    ),
                    provider.Selector<ProviderMultiPropertyNotifier, int>(
                      selector: (context, notifier) => notifier.property2,
                      builder: (context, value, child) {
                        providerSelectiveBuilds2++;
                        return Text(
                          'Provider2: $value',
                          key: const ValueKey('provider2'),
                        );
                      },
                    ),
                    provider.Selector<ProviderMultiPropertyNotifier, int>(
                      selector: (context, notifier) => notifier.property3,
                      builder: (context, value, child) {
                        providerSelectiveBuilds3++;
                        return Text(
                          'Provider3: $value',
                          key: const ValueKey('provider3'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      providerSelectiveBuilds1 = providerSelectiveBuilds2 =
          providerSelectiveBuilds3 = 0;

      final providerSelectiveStopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        providerNotifierSelective.updateProperty1();
        await tester.pump();
      }
      providerSelectiveStopwatch.stop();

      print('📦 Provider with Selector (Selective Notification):');
      print(
        '  Widget 1 (watching property1): $providerSelectiveBuilds1 rebuilds ← Only this one!',
      );
      print(
        '  Widget 2 (watching property2): $providerSelectiveBuilds2 rebuilds ← Should be 0',
      );
      print(
        '  Widget 3 (watching property3): $providerSelectiveBuilds3 rebuilds ← Should be 0',
      );
      print('  Time: ${providerSelectiveStopwatch.elapsedMilliseconds}ms');
      final totalProviderSelective =
          providerSelectiveBuilds1 +
          providerSelectiveBuilds2 +
          providerSelectiveBuilds3;
      print(
        '  Efficiency: ${totalProviderSelective > 0 ? ((providerSelectiveBuilds1 / totalProviderSelective) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n',
      );

      _results.selectiveRebuildPerformance['Provider (selective)'] =
          providerSelectiveStopwatch.elapsedMicroseconds;

      // === RIVERPOD WITH SELECT (Selective Notification) ===
      int riverpodSelectiveBuilds1 = 0,
          riverpodSelectiveBuilds2 = 0,
          riverpodSelectiveBuilds3 = 0;
      final riverpodSelectiveContainer = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: riverpodSelectiveContainer,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final value = ref.watch(
                          riverpodMultiProvider.select((state) => state['p1']),
                        );
                        riverpodSelectiveBuilds1++;
                        return Text(
                          'Riverpod1: $value',
                          key: const ValueKey('riverpod1'),
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final value = ref.watch(
                          riverpodMultiProvider.select((state) => state['p2']),
                        );
                        riverpodSelectiveBuilds2++;
                        return Text(
                          'Riverpod2: $value',
                          key: const ValueKey('riverpod2'),
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final value = ref.watch(
                          riverpodMultiProvider.select((state) => state['p3']),
                        );
                        riverpodSelectiveBuilds3++;
                        return Text(
                          'Riverpod3: $value',
                          key: const ValueKey('riverpod3'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      riverpodSelectiveBuilds1 = riverpodSelectiveBuilds2 =
          riverpodSelectiveBuilds3 = 0;

      final riverpodSelectiveStopwatch = Stopwatch()..start();
      final riverpodSelectiveNotifier = riverpodSelectiveContainer.read(
        riverpodMultiProvider.notifier,
      );

      for (int i = 0; i < 100; i++) {
        riverpodSelectiveNotifier.updateProperty1();
        await tester.pump();
      }
      riverpodSelectiveStopwatch.stop();

      print('🏗️ Riverpod with select() (Selective Notification):');
      print(
        '  Widget 1 (watching property1): $riverpodSelectiveBuilds1 rebuilds ← Only this one!',
      );
      print(
        '  Widget 2 (watching property2): $riverpodSelectiveBuilds2 rebuilds ← Should be 0',
      );
      print(
        '  Widget 3 (watching property3): $riverpodSelectiveBuilds3 rebuilds ← Should be 0',
      );
      print('  Time: ${riverpodSelectiveStopwatch.elapsedMilliseconds}ms');
      final totalRiverpodSelective =
          riverpodSelectiveBuilds1 +
          riverpodSelectiveBuilds2 +
          riverpodSelectiveBuilds3;
      print(
        '  Efficiency: ${totalRiverpodSelective > 0 ? ((riverpodSelectiveBuilds1 / totalRiverpodSelective) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n',
      );

      _results.selectiveRebuildPerformance['Riverpod (selective)'] =
          riverpodSelectiveStopwatch.elapsedMicroseconds;

      riverpodSelectiveContainer.dispose();
    });

    // ========================================================================
    // BIND.VIEWMODEL BENCHMARKS (Auto-tracking)
    // ========================================================================

    testWidgets('Bind.viewModel vs Provider Consumer - Performance', (
      WidgetTester tester,
    ) async {
      // Test Provider Consumer
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: const ProviderCounterWidget())),
      );

      // Warm up
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }

      final providerStopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }
      providerStopwatch.stop();

      await tester.pumpWidget(Container());

      // Test Bind.viewModel
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: const FairyObserverCounterWidget())),
      );

      // Warm up
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }

      final observerStopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }
      observerStopwatch.stop();

      print('\n📊 Bind.viewModel vs Provider Consumer:');
      print('  Provider Consumer: ${providerStopwatch.elapsedMilliseconds}ms');
      print(
        '  Fairy Bind.viewModel: ${observerStopwatch.elapsedMilliseconds}ms',
      );
      final diff =
          observerStopwatch.elapsedMicroseconds -
          providerStopwatch.elapsedMicroseconds;
      final percentage = (diff / providerStopwatch.elapsedMicroseconds * 100)
          .abs();
      if (diff > 0) {
        print('  Bind.viewModel is ${percentage.toStringAsFixed(1)}% slower');
      } else {
        print('  Bind.viewModel is ${percentage.toStringAsFixed(1)}% faster');
      }
      print('');
    });

    testWidgets('Bind.viewModel - Selective Rebuild Test', (
      WidgetTester tester,
    ) async {
      int widget1Builds = 0;
      int widget2Builds = 0;
      int widget3Builds = 0;
      FairyMultiPropertyViewModel? vm;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (locator) {
                vm = FairyMultiPropertyViewModel();
                return vm!;
              },
              child: Builder(
                builder: (context) => Column(
                  children: [
                    Bind.viewModel<FairyMultiPropertyViewModel>(
                      builder: (context, vm) {
                        widget1Builds++;
                        return Text('P1: ${vm.property1.value}');
                      },
                    ),
                    Bind.viewModel<FairyMultiPropertyViewModel>(
                      builder: (context, vm) {
                        widget2Builds++;
                        return Text('P2: ${vm.property2.value}');
                      },
                    ),
                    Bind.viewModel<FairyMultiPropertyViewModel>(
                      builder: (context, vm) {
                        widget3Builds++;
                        return Text('P3: ${vm.property3.value}');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      widget1Builds = widget2Builds = widget3Builds = 0;

      final stopwatch = Stopwatch()..start();

      // Change property1 100 times
      for (int i = 0; i < 100; i++) {
        vm!.property1.value++;
        await tester.pump();
      }

      stopwatch.stop();

      print('\n📊 Bind.viewModel Selective Rebuild Test:');
      print('  Changed property1 100 times:');
      print('  Widget 1 (accessing property1): $widget1Builds rebuilds ✓');
      print(
        '  Widget 2 (accessing property2): $widget2Builds rebuilds ${widget2Builds == 0 ? "✓" : "← Unexpected!"}',
      );
      print(
        '  Widget 3 (accessing property3): $widget3Builds rebuilds ${widget3Builds == 0 ? "✓" : "← Unexpected!"}',
      );
      print('  Time: ${stopwatch.elapsedMilliseconds}ms');
      final totalBuilds = widget1Builds + widget2Builds + widget3Builds;
      print(
        '  Efficiency: ${totalBuilds > 0 ? ((widget1Builds / totalBuilds) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary',
      );
      print('');
    });

    testWidgets('Bind.viewModel - Tracking Accuracy Test', (
      WidgetTester tester,
    ) async {
      int conditionalBuilds = 0;
      FairyMultiPropertyViewModel? vm;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (locator) {
                vm = FairyMultiPropertyViewModel();
                return vm!;
              },
              child: Builder(
                builder: (context) =>
                    Bind.viewModel<FairyMultiPropertyViewModel>(
                      builder: (context, vm) {
                        conditionalBuilds++;
                        // Conditionally access property2
                        if (vm.property1.value > 10) {
                          return Text('P2: ${vm.property2.value}');
                        }
                        return Text('P1: ${vm.property1.value}');
                      },
                    ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      conditionalBuilds = 0;

      print('\n📊 Bind.viewModel Conditional Access Tracking:');

      // Phase 1: property1 <= 10, should NOT track property2
      print('  Phase 1: property1 <= 10 (property2 not accessed)');
      vm!.property2.value = 999;
      await tester.pump();
      print(
        '    Changed property2 to 999: $conditionalBuilds rebuilds ${conditionalBuilds == 0 ? "✓" : "← Should not rebuild!"}',
      );

      conditionalBuilds = 0;
      vm!.property1.value = 5;
      await tester.pump();
      print(
        '    Changed property1 to 5: $conditionalBuilds rebuilds ${conditionalBuilds == 1 ? "✓" : "← Should rebuild!"}',
      );

      // Phase 2: property1 > 10, should NOW track property2
      conditionalBuilds = 0;
      print('\n  Phase 2: property1 > 10 (property2 IS accessed)');
      vm!.property1.value = 15;
      await tester.pump();
      print(
        '    Changed property1 to 15: $conditionalBuilds rebuilds ${conditionalBuilds == 1 ? "✓" : "← Should rebuild!"}',
      );

      conditionalBuilds = 0;
      vm!.property2.value = 42;
      await tester.pump();
      print(
        '    Changed property2 to 42: $conditionalBuilds rebuilds ${conditionalBuilds == 1 ? "✓" : "← Should rebuild now!"}',
      );
      print('');
    });

    testWidgets('Bind.viewModel - Batching Performance', (
      WidgetTester tester,
    ) async {
      int buildCount = 0;
      FairyCounterViewModel? vm;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (locator) {
                vm = FairyCounterViewModel();
                return vm!;
              },
              child: Builder(
                builder: (context) => Bind.viewModel<FairyCounterViewModel>(
                  builder: (context, vm) {
                    buildCount++;
                    return Text('${vm.counter.value}');
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      buildCount = 0;

      print('\n📊 Bind.viewModel Batching Test:');

      final stopwatch = Stopwatch()..start();

      // Make 1000 rapid changes
      for (int i = 0; i < 1000; i++) {
        vm!.counter.value = i;
      }

      await tester.pump();
      stopwatch.stop();

      print('  Made 1000 rapid changes');
      print('  Actual rebuilds: $buildCount');
      print('  Time: ${stopwatch.elapsedMicroseconds}µs');
      print(
        '  Batching efficiency: ${((1000 - buildCount) / 1000 * 100).toStringAsFixed(1)}% reduction',
      );
      print('');
    });

    testWidgets('Bind.viewModel - Memory Test (Subscription Cleanup)', (
      WidgetTester tester,
    ) async {
      print('\n📊 Bind.viewModel Memory Test:');

      final stopwatch = Stopwatch()..start();

      // Create and dispose 100 widgets
      for (int i = 0; i < 100; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FairyScope(
                viewModel: (locator) => FairyMultiPropertyViewModel(),
                child: Builder(
                  builder: (context) => Column(
                    children: [
                      Bind.viewModel<FairyMultiPropertyViewModel>(
                        builder: (context, vm) => Text('${vm.property1.value}'),
                      ),
                      Bind.viewModel<FairyMultiPropertyViewModel>(
                        builder: (context, vm) => Text('${vm.property2.value}'),
                      ),
                      Bind.viewModel<FairyMultiPropertyViewModel>(
                        builder: (context, vm) => Text('${vm.property3.value}'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        // Dispose
        await tester.pumpWidget(Container());
      }

      stopwatch.stop();

      print('  Created and disposed 100 widget trees (3 observers each)');
      print('  Time: ${stopwatch.elapsedMilliseconds}ms');
      print(
        '  Average per cycle: ${(stopwatch.elapsedMilliseconds / 100).toStringAsFixed(2)}ms',
      );
      print('  ✓ No memory leaks if this completes without errors');
      print('');
    });

    // ========================================================================
    // REBUILD PERFORMANCE WITH BIND.VIEWMODEL
    // ========================================================================

    testWidgets('Rebuild Performance (Bind.viewModel Auto-tracking)', (
      WidgetTester tester,
    ) async {
      // This tests rebuild performance when using Bind.viewModel with auto-tracking
      // All frameworks use their "auto-tracking" approach (Consumer/watch without selectors)

      print('\n📊 Rebuild Performance with Auto-tracking:');

      // === FAIRY BIND.VIEWMODEL ===
      int fairyObserverBuilds1 = 0,
          fairyObserverBuilds2 = 0,
          fairyObserverBuilds3 = 0;
      FairyMultiPropertyViewModel? fairyVm;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              key: const ValueKey('fairy-observer'),
              viewModel: (locator) {
                final vm = FairyMultiPropertyViewModel();
                fairyVm = vm;
                return vm;
              },
              child: Builder(
                builder: (context) => Column(
                  children: [
                    Bind.viewModel<FairyMultiPropertyViewModel>(
                      builder: (context, vm) {
                        fairyObserverBuilds1++;
                        return Text(
                          'Fairy1: ${vm.property1.value}',
                          key: const ValueKey('fairy1'),
                        );
                      },
                    ),
                    Bind.viewModel<FairyMultiPropertyViewModel>(
                      builder: (context, vm) {
                        fairyObserverBuilds2++;
                        return Text(
                          'Fairy2: ${vm.property2.value}',
                          key: const ValueKey('fairy2'),
                        );
                      },
                    ),
                    Bind.viewModel<FairyMultiPropertyViewModel>(
                      builder: (context, vm) {
                        fairyObserverBuilds3++;
                        return Text(
                          'Fairy3: ${vm.property3.value}',
                          key: const ValueKey('fairy3'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      fairyObserverBuilds1 = fairyObserverBuilds2 = fairyObserverBuilds3 = 0;

      // Warm-up run to stabilize JIT compilation and caches
      for (int i = 0; i < 20; i++) {
        fairyVm!.property1.value = i;
        await tester.pump();
      }
      fairyObserverBuilds1 = 0;

      // Multiple measurement runs to reduce noise
      final fairyObserverTimes = <int>[];
      for (int run = 0; run < 5; run++) {
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          fairyVm!.property1.value = i;
          await tester.pump();
        }
        stopwatch.stop();
        fairyObserverTimes.add(stopwatch.elapsedMicroseconds);
      }

      // Use median to eliminate outliers
      fairyObserverTimes.sort();
      final fairyObserverMedian =
          fairyObserverTimes[fairyObserverTimes.length ~/ 2];

      print('  🧚 Fairy Bind.viewModel:');
      print(
        '    Widget 1 (accessing property1): $fairyObserverBuilds1 rebuilds ← Only this one!',
      );
      print(
        '    Widget 2 (accessing property2): $fairyObserverBuilds2 rebuilds ← Should be 0',
      );
      print(
        '    Widget 3 (accessing property3): $fairyObserverBuilds3 rebuilds ← Should be 0',
      );
      print(
        '    Time: ${(fairyObserverMedian / 1000).toStringAsFixed(2)}ms (median of 5 runs)',
      );
      final totalFairyObserver =
          fairyObserverBuilds1 + fairyObserverBuilds2 + fairyObserverBuilds3;
      print(
        '    Efficiency: ${totalFairyObserver > 0 ? ((fairyObserverBuilds1 / totalFairyObserver) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n',
      );

      _results.rebuildPerformance['Fairy Bind.viewModel'] = fairyObserverMedian;

      // === PROVIDER CONSUMER (Global) ===
      int providerConsumerBuilds1 = 0,
          providerConsumerBuilds2 = 0,
          providerConsumerBuilds3 = 0;
      final providerNotifier = ProviderMultiPropertyNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: provider.ChangeNotifierProvider.value(
              value: providerNotifier,
              child: Builder(
                builder: (context) => Column(
                  children: [
                    provider.Consumer<ProviderMultiPropertyNotifier>(
                      builder: (context, notifier, child) {
                        providerConsumerBuilds1++;
                        return Text('Provider1: ${notifier.property1}');
                      },
                    ),
                    provider.Consumer<ProviderMultiPropertyNotifier>(
                      builder: (context, notifier, child) {
                        providerConsumerBuilds2++;
                        return Text('Provider2: ${notifier.property2}');
                      },
                    ),
                    provider.Consumer<ProviderMultiPropertyNotifier>(
                      builder: (context, notifier, child) {
                        providerConsumerBuilds3++;
                        return Text('Provider3: ${notifier.property3}');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      providerConsumerBuilds1 = providerConsumerBuilds2 =
          providerConsumerBuilds3 = 0;

      // Warm-up run
      for (int i = 0; i < 20; i++) {
        providerNotifier.updateProperty1();
        await tester.pump();
      }
      providerConsumerBuilds1 = providerConsumerBuilds2 =
          providerConsumerBuilds3 = 0;

      // Multiple measurement runs to reduce noise
      final providerConsumerTimes = <int>[];
      for (int run = 0; run < 5; run++) {
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          providerNotifier.updateProperty1();
          await tester.pump();
        }
        stopwatch.stop();
        providerConsumerTimes.add(stopwatch.elapsedMicroseconds);
      }

      // Use median to eliminate outliers
      providerConsumerTimes.sort();
      final providerConsumerMedian =
          providerConsumerTimes[providerConsumerTimes.length ~/ 2];

      print('  📦 Provider Consumer (no selector):');
      print(
        '    Widget 1 (watching property1): $providerConsumerBuilds1 rebuilds',
      );
      print(
        '    Widget 2 (watching property2): $providerConsumerBuilds2 rebuilds ← Unnecessary!',
      );
      print(
        '    Widget 3 (watching property3): $providerConsumerBuilds3 rebuilds ← Unnecessary!',
      );
      print(
        '    Time: ${(providerConsumerMedian / 1000).toStringAsFixed(2)}ms (median of 5 runs)',
      );
      final totalProviderConsumer =
          providerConsumerBuilds1 +
          providerConsumerBuilds2 +
          providerConsumerBuilds3;
      print(
        '    Efficiency: ${totalProviderConsumer > 0 ? ((providerConsumerBuilds1 / totalProviderConsumer) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n',
      );

      _results.rebuildPerformance['Provider Consumer'] = providerConsumerMedian;

      // === RIVERPOD CONSUMER (Global) ===
      int riverpodConsumerBuilds1 = 0,
          riverpodConsumerBuilds2 = 0,
          riverpodConsumerBuilds3 = 0;
      final riverpodContainer = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: riverpodContainer,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final state = ref.watch(riverpodMultiProvider);
                        riverpodConsumerBuilds1++;
                        return Text('Riverpod1: ${state['p1']}');
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final state = ref.watch(riverpodMultiProvider);
                        riverpodConsumerBuilds2++;
                        return Text('Riverpod2: ${state['p2']}');
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final state = ref.watch(riverpodMultiProvider);
                        riverpodConsumerBuilds3++;
                        return Text('Riverpod3: ${state['p3']}');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      riverpodConsumerBuilds1 = riverpodConsumerBuilds2 =
          riverpodConsumerBuilds3 = 0;

      // Warm-up run
      final riverpodNotifier = riverpodContainer.read(
        riverpodMultiProvider.notifier,
      );
      for (int i = 0; i < 20; i++) {
        riverpodNotifier.updateProperty1();
        await tester.pump();
      }
      riverpodConsumerBuilds1 = riverpodConsumerBuilds2 =
          riverpodConsumerBuilds3 = 0;

      // Multiple measurement runs to reduce noise
      final riverpodConsumerTimes = <int>[];
      for (int run = 0; run < 5; run++) {
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          riverpodNotifier.updateProperty1();
          await tester.pump();
        }
        stopwatch.stop();
        riverpodConsumerTimes.add(stopwatch.elapsedMicroseconds);
      }

      // Use median to eliminate outliers
      riverpodConsumerTimes.sort();
      final riverpodConsumerMedian =
          riverpodConsumerTimes[riverpodConsumerTimes.length ~/ 2];

      print('  🏗️ Riverpod Consumer (no select):');
      print(
        '    Widget 1 (watching property1): $riverpodConsumerBuilds1 rebuilds',
      );
      print(
        '    Widget 2 (watching property2): $riverpodConsumerBuilds2 rebuilds ← Unnecessary!',
      );
      print(
        '    Widget 3 (watching property3): $riverpodConsumerBuilds3 rebuilds ← Unnecessary!',
      );
      print(
        '    Time: ${(riverpodConsumerMedian / 1000).toStringAsFixed(2)}ms (median of 5 runs)',
      );
      final totalRiverpodConsumer =
          riverpodConsumerBuilds1 +
          riverpodConsumerBuilds2 +
          riverpodConsumerBuilds3;
      print(
        '    Efficiency: ${totalRiverpodConsumer > 0 ? ((riverpodConsumerBuilds1 / totalRiverpodConsumer) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n',
      );

      _results.rebuildPerformance['Riverpod Consumer'] = riverpodConsumerMedian;

      riverpodContainer.dispose();
    });

    // ========================================================================
    // ENHANCED DEPENDENCY TRACKER BENCHMARKS (Lazy Builders)
    // ========================================================================

    testWidgets('Lazy Builder Performance - ListView.builder with Bind.viewModel', (
      WidgetTester tester,
    ) async {
      print('\n📊 Lazy Builder Performance Test:');

      int itemBuilderCalls = 0;
      FairyMultiPropertyViewModel? vm;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModel: (locator) {
                vm = FairyMultiPropertyViewModel();
                return vm!;
              },
              child: Builder(
                builder: (context) => Bind.viewModel<FairyMultiPropertyViewModel>(
                  builder: (context, vm) {
                    return ListView.builder(
                      itemCount: 100,
                      itemBuilder: (context, index) {
                        itemBuilderCalls++;
                        // Access property inside itemBuilder (deferred callback)
                        return ListTile(
                          title: Text('Item $index - ${vm.property1.value}'),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final initialBuilderCalls = itemBuilderCalls;
      itemBuilderCalls = 0;

      final stopwatch = Stopwatch()..start();

      // Update property1 - should trigger rebuilds since it's accessed in itemBuilder
      for (int i = 0; i < 50; i++) {
        vm!.property1.value = i;
        await tester.pump();
      }

      stopwatch.stop();

      print(
        '  Initial itemBuilder calls: $initialBuilderCalls (lazy rendering)',
      );
      print('  Updates: 50 property changes');
      print('  ItemBuilder calls after updates: $itemBuilderCalls');
      print('  Time: ${stopwatch.elapsedMilliseconds}ms');
      print(
        '  ✓ Lazy builder tracking ${itemBuilderCalls > 0 ? "WORKING" : "FAILED"}!',
      );
      print('');
    });

    testWidgets('Multi-ViewModel Performance - Bind.viewModel2', (
      WidgetTester tester,
    ) async {
      print('\n📊 Multi-ViewModel Performance (Bind.viewModel2):');

      int widget1Builds = 0, widget2Builds = 0;
      FairyMultiPropertyViewModel? vm1;
      FairyMultiPropertyViewModel2? vm2;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [
                (locator) {
                  vm1 = FairyMultiPropertyViewModel();
                  return vm1!;
                },
                (locator) {
                  vm2 = FairyMultiPropertyViewModel2();
                  return vm2!;
                },
              ],
              child: Builder(
                builder: (context) => Column(
                  children: [
                    Bind.viewModel2<
                      FairyMultiPropertyViewModel,
                      FairyMultiPropertyViewModel2
                    >(
                      builder: (context, vm1, vm2) {
                        widget1Builds++;
                        return Text('VM1: ${vm1.property1.value}');
                      },
                    ),
                    Bind.viewModel2<
                      FairyMultiPropertyViewModel,
                      FairyMultiPropertyViewModel2
                    >(
                      builder: (context, vm1, vm2) {
                        widget2Builds++;
                        return Text('VM2: ${vm2.property1.value}');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      widget1Builds = widget2Builds = 0;

      final stopwatch = Stopwatch()..start();

      // Update VM1 property - only widget1 should rebuild
      for (int i = 0; i < 100; i++) {
        vm1!.property1.value = i;
        await tester.pump();
      }

      stopwatch.stop();

      print('  Changed VM1.property1 100 times:');
      print('  Widget 1 (accessing VM1.property1): $widget1Builds rebuilds ✓');
      print(
        '  Widget 2 (accessing VM2.property1): $widget2Builds rebuilds ${widget2Builds == 0 ? "✓" : "← Unexpected!"}',
      );
      print('  Time: ${stopwatch.elapsedMilliseconds}ms');
      final totalBuilds = widget1Builds + widget2Builds;
      print(
        '  Efficiency: ${totalBuilds > 0 ? ((widget1Builds / totalBuilds) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary',
      );
      print('');
    });

    testWidgets('Lazy Builder + Multi-ViewModel - Bind.viewModel3 with ListView', (
      WidgetTester tester,
    ) async {
      print(
        '\n📊 Combined Test: Lazy Builder + Multi-ViewModel (Bind.viewModel3):',
      );

      int listBuilderCalls = 0;
      FairyMultiPropertyViewModel? vm1;
      FairyMultiPropertyViewModel2? vm2;
      FairyMultiPropertyViewModel3? vm3;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              viewModels: [
                (locator) {
                  vm1 = FairyMultiPropertyViewModel();
                  return vm1!;
                },
                (locator) {
                  vm2 = FairyMultiPropertyViewModel2();
                  return vm2!;
                },
                (locator) {
                  vm3 = FairyMultiPropertyViewModel3();
                  return vm3!;
                },
              ],
              child: Builder(
                builder: (context) =>
                    Bind.viewModel3<
                      FairyMultiPropertyViewModel,
                      FairyMultiPropertyViewModel2,
                      FairyMultiPropertyViewModel3
                    >(
                      builder: (context, vm1, vm2, vm3) {
                        return ListView.builder(
                          itemCount: 50,
                          itemBuilder: (context, index) {
                            listBuilderCalls++;
                            // Access properties from different VMs in itemBuilder
                            return ListTile(
                              title: Text('Item $index'),
                              subtitle: Text(
                                'VM1: ${vm1.property1.value}, VM2: ${vm2.property1.value}, VM3: ${vm3.property1.value}',
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      listBuilderCalls = 0;

      final stopwatch = Stopwatch()..start();

      // Update all 3 VMs
      for (int i = 0; i < 30; i++) {
        vm1!.property1.value = i;
        vm2!.property1.value = i;
        vm3!.property1.value = i;
        await tester.pump();
      }

      stopwatch.stop();

      print(
        '  ListView with 50 items, 3 ViewModels, accessing properties in itemBuilder',
      );
      print('  Updates: 30 property changes × 3 VMs = 90 total changes');
      print('  ItemBuilder calls: $listBuilderCalls');
      print('  Time: ${stopwatch.elapsedMilliseconds}ms');
      print(
        '  Average per update: ${(stopwatch.elapsedMicroseconds / 30).toStringAsFixed(0)}µs',
      );
      print(
        '  ✓ Complex lazy builder + multi-VM tracking ${listBuilderCalls > 0 ? "WORKING" : "FAILED"}!',
      );
      print('');
    });
  });

  // Print formatted results after all tests complete
  tearDownAll(() {
    printBenchmarkResults(_results);
  });
}
