import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/locator/fairy_locator.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:fairy/src/locator/fairy_resolver.dart';
import 'package:fairy/src/ui/fairy_bridge.dart';

void main() {
  setUp(() {
    // Clear FairyLocator before each test
    FairyLocator.clear();
  });

  tearDown(() {
    // Clean up after each test
    FairyLocator.clear();
  });

  group('Fairy.of()', () {
    testWidgets('should resolve ViewModel from FairyScope first',
        (tester) async {
      final scopeVm = ScopedViewModel();
      ScopedViewModel? resolvedVm;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => scopeVm)],
          child: Builder(
            builder: (context) {
              resolvedVm = Fairy.of<ScopedViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, scopeVm), isTrue);
    });

    testWidgets('should resolve ViewModel from FairyLocator if not in scope',
        (tester) async {
      final globalVm = GlobalViewModel();
      FairyLocator.registerSingleton<GlobalViewModel>(globalVm);

      GlobalViewModel? resolvedVm;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedVm = Fairy.of<GlobalViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, globalVm), isTrue);
    });

    testWidgets('should prioritize FairyScope over FairyLocator',
        (tester) async {
      final scopeVm = TestViewModel();
      final globalVm = TestViewModel();

      FairyLocator.registerSingleton<TestViewModel>(globalVm);

      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => scopeVm)],
          child: Builder(
            builder: (context) {
              resolvedVm = Fairy.of<TestViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedVm, isNotNull);
      // Should get scope VM, not global
      expect(identical(resolvedVm, scopeVm), isTrue);
      expect(identical(resolvedVm, globalVm), isFalse);
    });

    testWidgets('should throw StateError when ViewModel not found',
        (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              Fairy.of<TestViewModel>(context);
              fail('Should have thrown StateError');
            } catch (e) {
              expect(e, isA<StateError>());
              expect(e.toString(),
                  contains('No ViewModel of type TestViewModel found'));
            }
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('should provide helpful error message with registration hints',
        (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              Fairy.of<TestViewModel>(context);
              fail('Should have thrown StateError');
            } catch (e) {
              expect(e.toString(), contains('FairyLocator.registerSingleton'));
              expect(e.toString(), contains('FairyScope'));
              expect(e.toString(), contains('Make sure to either'));
            }
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('should work with nested FairyScopes', (tester) async {
      final outerVm = OuterViewModel();
      final innerVm = InnerViewModel();

      InnerViewModel? resolvedInner;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => outerVm)],
          child: FairyScope(
            viewModels: [ViewModelFactory((_) => innerVm)],
            child: Builder(
              builder: (context) {
                resolvedInner = Fairy.of<InnerViewModel>(context);

                // OuterViewModel should not be found in inner scope
                try {
                  Fairy.of<OuterViewModel>(context);
                  fail(
                      'Should have thrown - OuterViewModel not in inner scope');
                } catch (e) {
                  expect(e, isA<StateError>());
                }

                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedInner, isNotNull);
      expect(identical(resolvedInner, innerVm), isTrue);
    });

    testWidgets('should resolve from outer scope if available', (tester) async {
      final outerVm = TestViewModel();

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => outerVm)],
          child: Builder(
            builder: (outerContext) {
              return FairyScope(
                viewModels: [ViewModelFactory((_) => InnerViewModel())],
                child: Builder(
                  builder: (innerContext) {
                    // Try to get TestViewModel from inner context
                    // Should fail because FairyScope.of() only gets nearest scope
                    try {
                      Fairy.of<TestViewModel>(innerContext);
                      fail('Should have thrown');
                    } catch (e) {
                      expect(e, isA<StateError>());
                    }
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );
    });

    testWidgets('should work with FairyScope and FairyLocator together',
        (tester) async {
      final scopeVm = ScopedViewModel();
      final globalVm = GlobalViewModel();

      FairyLocator.registerSingleton<GlobalViewModel>(globalVm);

      ScopedViewModel? resolvedScoped;
      GlobalViewModel? resolvedGlobal;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => scopeVm)],
          child: Builder(
            builder: (context) {
              resolvedScoped = Fairy.of<ScopedViewModel>(context);
              resolvedGlobal = Fairy.of<GlobalViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedScoped, isNotNull);
      expect(identical(resolvedScoped, scopeVm), isTrue);

      expect(resolvedGlobal, isNotNull);
      expect(identical(resolvedGlobal, globalVm), isTrue);
    });
  });

  group('Fairy.maybeOf()', () {
    testWidgets('should return ViewModel from FairyScope', (tester) async {
      final scopeVm = ScopedViewModel();
      ScopedViewModel? resolvedVm;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => scopeVm)],
          child: Builder(
            builder: (context) {
              resolvedVm = Fairy.maybeOf<ScopedViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, scopeVm), isTrue);
    });

    testWidgets('should return ViewModel from FairyLocator', (tester) async {
      final globalVm = GlobalViewModel();
      FairyLocator.registerSingleton<GlobalViewModel>(globalVm);

      GlobalViewModel? resolvedVm;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedVm = Fairy.maybeOf<GlobalViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, globalVm), isTrue);
    });

    testWidgets('should return null when ViewModel not found', (tester) async {
      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedVm = Fairy.maybeOf<TestViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolvedVm, isNull);
    });

    testWidgets('should prioritize FairyScope over FairyLocator',
        (tester) async {
      final scopeVm = TestViewModel();
      final globalVm = TestViewModel();

      FairyLocator.registerSingleton<TestViewModel>(globalVm);

      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => scopeVm)],
          child: Builder(
            builder: (context) {
              resolvedVm = Fairy.maybeOf<TestViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, scopeVm), isTrue);
      expect(identical(resolvedVm, globalVm), isFalse);
    });

    testWidgets('should not throw when ViewModel not found', (tester) async {
      TestViewModel? resolvedVm;
      var didThrow = false;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              resolvedVm = Fairy.maybeOf<TestViewModel>(context);
            } catch (e) {
              didThrow = true;
            }
            return const SizedBox();
          },
        ),
      );

      expect(didThrow, isFalse);
      expect(resolvedVm, isNull);
    });

    testWidgets('should work with mixed scope and global ViewModels',
        (tester) async {
      final scopeVm = ScopedViewModel();
      final globalVm = GlobalViewModel();

      FairyLocator.registerSingleton<GlobalViewModel>(globalVm);

      ScopedViewModel? resolvedScoped;
      GlobalViewModel? resolvedGlobal;
      TestViewModel? resolvedMissing;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => scopeVm)],
          child: Builder(
            builder: (context) {
              resolvedScoped = Fairy.maybeOf<ScopedViewModel>(context);
              resolvedGlobal = Fairy.maybeOf<GlobalViewModel>(context);
              resolvedMissing = Fairy.maybeOf<TestViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedScoped, isNotNull);
      expect(resolvedGlobal, isNotNull);
      expect(resolvedMissing, isNull);
    });
  });

  group('ViewModelLocator resolution order', () {
    testWidgets('should check FairyScope before FairyLocator', (tester) async {
      final scopeVm = TestViewModel();
      final globalVm = TestViewModel();

      // Register in global first
      FairyLocator.registerSingleton<TestViewModel>(globalVm);

      TestViewModel? firstResolve;
      TestViewModel? secondResolve;

      await tester.pumpWidget(
        Column(
          children: [
            Builder(
              builder: (context) {
                // Outside scope - should get global
                firstResolve = Fairy.of<TestViewModel>(context);
                return const SizedBox();
              },
            ),
            FairyScope(
              viewModels: [ViewModelFactory((_) => scopeVm)],
              child: Builder(
                builder: (context) {
                  // Inside scope - should get scoped
                  secondResolve = Fairy.of<TestViewModel>(context);
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      );

      expect(identical(firstResolve, globalVm), isTrue);
      expect(identical(secondResolve, scopeVm), isTrue);
    });

    testWidgets('should handle scope removal gracefully', (tester) async {
      final scopeVm = ScopedViewModel();
      final globalVm = ScopedViewModel();

      FairyLocator.registerSingleton<ScopedViewModel>(globalVm);

      ScopedViewModel? resolvedBefore;
      ScopedViewModel? resolvedAfter;

      // With scope
      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => scopeVm)],
          child: Builder(
            builder: (context) {
              resolvedBefore = Fairy.of<ScopedViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(identical(resolvedBefore, scopeVm), isTrue);

      // Remove scope
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedAfter = Fairy.of<ScopedViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(identical(resolvedAfter, globalVm), isTrue);
    });
  });

  group('FairyBridge()', () {
    testWidgets('should bridge parent FairyScope to overlay', (tester) async {
      final parentVm = TestViewModel();
      TestViewModel? resolvedInOverlay;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              return FairyBridge(
                context: parentContext,
                child: Builder(
                  builder: (overlayContext) {
                    resolvedInOverlay = Fairy.of<TestViewModel>(overlayContext);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(resolvedInOverlay, isNotNull);
      expect(identical(resolvedInOverlay, parentVm), isTrue);
    });

    testWidgets('should allow Bind widgets to work in bridged overlay',
        (tester) async {
      final parentVm = TestViewModel();
      TestViewModel? resolvedInBind;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              return FairyBridge(
                context: parentContext,
                child: Builder(
                  builder: (overlayContext) {
                    // Simulate what Bind widget does internally
                    resolvedInBind = Fairy.of<TestViewModel>(overlayContext);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(resolvedInBind, isNotNull);
      expect(identical(resolvedInBind, parentVm), isTrue);
    });

    testWidgets('should work when no parent FairyScope exists', (tester) async {
      final globalVm = TestViewModel();
      FairyLocator.registerSingleton<TestViewModel>(globalVm);

      TestViewModel? resolvedInOverlay;

      await tester.pumpWidget(
        Builder(
          builder: (parentContext) {
            return FairyBridge(
              context: parentContext,
              child: Builder(
                builder: (overlayContext) {
                  resolvedInOverlay = Fairy.of<TestViewModel>(overlayContext);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );

      expect(resolvedInOverlay, isNotNull);
      expect(identical(resolvedInOverlay, globalVm), isTrue);
    });

    testWidgets('should fallback to FairyLocator when no parent scope',
        (tester) async {
      final globalVm = GlobalViewModel();
      FairyLocator.registerSingleton<GlobalViewModel>(globalVm);

      GlobalViewModel? resolvedInOverlay;

      await tester.pumpWidget(
        Builder(
          builder: (parentContext) {
            return FairyBridge(
              context: parentContext,
              child: Builder(
                builder: (overlayContext) {
                  resolvedInOverlay =
                      Fairy.maybeOf<GlobalViewModel>(overlayContext);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );

      expect(resolvedInOverlay, isNotNull);
      expect(identical(resolvedInOverlay, globalVm), isTrue);
    });

    testWidgets('should preserve parent scope after bridge is destroyed',
        (tester) async {
      final parentVm = TestViewModel();
      TestViewModel? resolvedBeforeBridge;
      TestViewModel? resolvedAfterBridge;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              resolvedBeforeBridge = Fairy.of<TestViewModel>(parentContext);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedBeforeBridge, isNotNull);
      expect(identical(resolvedBeforeBridge, parentVm), isTrue);

      // Create and destroy bridge
      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              return Column(
                children: [
                  FairyBridge(
                    context: parentContext,
                    child: Builder(
                      builder: (overlayContext) {
                        Fairy.of<TestViewModel>(overlayContext);
                        return const SizedBox();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );

      // Remove bridge
      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              resolvedAfterBridge = Fairy.of<TestViewModel>(parentContext);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedAfterBridge, isNotNull);
      expect(identical(resolvedAfterBridge, parentVm), isTrue);
      expect(!parentVm.isDisposed, isTrue,
          reason: 'Parent VM should not be disposed');
    });

    testWidgets('should not affect parent context ViewModel resolution',
        (tester) async {
      final parentVm = TestViewModel();
      TestViewModel? resolvedInParent;
      TestViewModel? resolvedInOverlay;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              resolvedInParent = Fairy.of<TestViewModel>(parentContext);
              return FairyBridge(
                context: parentContext,
                child: Builder(
                  builder: (overlayContext) {
                    resolvedInOverlay = Fairy.of<TestViewModel>(overlayContext);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(resolvedInParent, isNotNull);
      expect(resolvedInOverlay, isNotNull);
      expect(identical(resolvedInParent, resolvedInOverlay), isTrue);
      expect(identical(resolvedInParent, parentVm), isTrue);
    });

    testWidgets('should bridge multiple ViewModels from same scope',
        (tester) async {
      final vm1 = TestViewModel();
      final vm2 = ScopedViewModel();

      TestViewModel? resolved1;
      ScopedViewModel? resolved2;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [
            (_) => vm1,
            (_) => vm2,
          ],
          child: Builder(
            builder: (parentContext) {
              return FairyBridge(
                context: parentContext,
                child: Builder(
                  builder: (overlayContext) {
                    resolved1 = Fairy.of<TestViewModel>(overlayContext);
                    resolved2 = Fairy.of<ScopedViewModel>(overlayContext);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(resolved1, isNotNull);
      expect(resolved2, isNotNull);
      expect(identical(resolved1, vm1), isTrue);
      expect(identical(resolved2, vm2), isTrue);
    });

    testWidgets('should work with nested bridges', (tester) async {
      final parentVm = TestViewModel();
      TestViewModel? resolvedInFirstOverlay;
      TestViewModel? resolvedInSecondOverlay;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              return FairyBridge(
                context: parentContext,
                child: Builder(
                  builder: (firstOverlayContext) {
                    resolvedInFirstOverlay =
                        Fairy.of<TestViewModel>(firstOverlayContext);
                    return FairyBridge(
                      context: firstOverlayContext,
                      child: Builder(
                        builder: (secondOverlayContext) {
                          resolvedInSecondOverlay =
                              Fairy.of<TestViewModel>(secondOverlayContext);
                          return const SizedBox();
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(resolvedInFirstOverlay, isNotNull);
      expect(resolvedInSecondOverlay, isNotNull);
      expect(identical(resolvedInFirstOverlay, parentVm), isTrue);
      expect(identical(resolvedInSecondOverlay, parentVm), isTrue);
    });

    testWidgets('should bridge nearest FairyScope in nested scopes',
        (tester) async {
      final outerVm = TestViewModel();
      final innerVm = ScopedViewModel();

      ScopedViewModel? resolvedInOverlay;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => outerVm)],
          child: FairyScope(
            viewModels: [ViewModelFactory((_) => innerVm)],
            child: Builder(
              builder: (innerContext) {
                return FairyBridge(
                  context: innerContext,
                  child: Builder(
                    builder: (overlayContext) {
                      resolvedInOverlay =
                          Fairy.of<ScopedViewModel>(overlayContext);
                      return const SizedBox();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(resolvedInOverlay, isNotNull);
      expect(identical(resolvedInOverlay, innerVm), isTrue);
    });

    testWidgets('should throw if ViewModel not in bridged scope or locator',
        (tester) async {
      final parentVm = TestViewModel();
      var didThrow = false;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              return FairyBridge(
                context: parentContext,
                child: Builder(
                  builder: (overlayContext) {
                    try {
                      Fairy.of<GlobalViewModel>(overlayContext);
                      fail('Should have thrown StateError');
                    } catch (e) {
                      expect(e, isA<StateError>());
                      expect(
                          e.toString(),
                          contains(
                              'No ViewModel of type GlobalViewModel found'));
                      didThrow = true;
                    }
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(didThrow, isTrue);
    });

    testWidgets('should return null with maybeOf if not in bridged scope',
        (tester) async {
      final parentVm = TestViewModel();
      GlobalViewModel? resolvedInOverlay;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              return FairyBridge(
                context: parentContext,
                child: Builder(
                  builder: (overlayContext) {
                    resolvedInOverlay =
                        Fairy.maybeOf<GlobalViewModel>(overlayContext);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(resolvedInOverlay, isNull);
    });

    testWidgets('bridge should not dispose parent ViewModel when removed',
        (tester) async {
      final parentVm = TestViewModel();
      var bridgeBuilt = false;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              if (!bridgeBuilt) {
                bridgeBuilt = true;
                return FairyBridge(
                  context: parentContext,
                  child: const SizedBox(),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      );

      expect(parentVm.isDisposed, isFalse);

      // Rebuild without bridge
      bridgeBuilt = true;
      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => parentVm)],
          child: Builder(
            builder: (parentContext) {
              return const SizedBox();
            },
          ),
        ),
      );

      expect(parentVm.isDisposed, isFalse,
          reason: 'Parent VM should remain alive after bridge removal');
    });

    testWidgets('should prioritize bridged scope over FairyLocator',
        (tester) async {
      final scopeVm = TestViewModel();
      final globalVm = TestViewModel();

      FairyLocator.registerSingleton<TestViewModel>(globalVm);

      TestViewModel? resolvedInOverlay;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => scopeVm)],
          child: Builder(
            builder: (parentContext) {
              return FairyBridge(
                context: parentContext,
                child: Builder(
                  builder: (overlayContext) {
                    resolvedInOverlay = Fairy.of<TestViewModel>(overlayContext);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(resolvedInOverlay, isNotNull);
      expect(identical(resolvedInOverlay, scopeVm), isTrue);
      expect(identical(resolvedInOverlay, globalVm), isFalse);
    });

    testWidgets('should simulate dialog scenario correctly', (tester) async {
      final pageVm = TestViewModel();
      TestViewModel? resolvedInDialog;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => pageVm)],
            child: Builder(
              builder: (pageContext) {
                return Scaffold(
                  body: Builder(
                    builder: (scaffoldContext) {
                      // Simulate showDialog creating a new overlay entry
                      return Stack(
                        children: [
                          const Text('Page Content'),
                          // Dialog overlay
                          Positioned.fill(
                            child: FairyBridge(
                              context: pageContext, // Bridge from page context
                              child: Builder(
                                builder: (dialogContext) {
                                  // Inside dialog - should access page VM
                                  resolvedInDialog =
                                      Fairy.of<TestViewModel>(dialogContext);
                                  return Container(
                                    color: const Color(0x80000000),
                                    child: const Center(
                                      child: Text('Dialog'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(resolvedInDialog, isNotNull);
      expect(identical(resolvedInDialog, pageVm), isTrue);
      expect(pageVm.isDisposed, isFalse);
    });
  });

  group('ViewModelLocator edge cases', () {
    testWidgets('should handle multiple ViewModels of different types',
        (tester) async {
      final vm1 = TestViewModel();
      final vm2 = ScopedViewModel();
      final vm3 = GlobalViewModel();

      FairyLocator.registerSingleton<TestViewModel>(vm1);
      FairyLocator.registerSingleton<ScopedViewModel>(vm2);
      FairyLocator.registerSingleton<GlobalViewModel>(vm3);

      TestViewModel? resolved1;
      ScopedViewModel? resolved2;
      GlobalViewModel? resolved3;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved1 = Fairy.of<TestViewModel>(context);
            resolved2 = Fairy.of<ScopedViewModel>(context);
            resolved3 = Fairy.of<GlobalViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(identical(resolved1, vm1), isTrue);
      expect(identical(resolved2, vm2), isTrue);
      expect(identical(resolved3, vm3), isTrue);
    });

    testWidgets('should work when FairyLocator is empty', (tester) async {
      final scopeVm = TestViewModel();

      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        FairyScope(
          viewModels: [ViewModelFactory((_) => scopeVm)],
          child: Builder(
            builder: (context) {
              resolvedVm = Fairy.of<TestViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, scopeVm), isTrue);
    });

    testWidgets('should work when no FairyScope in tree', (tester) async {
      final globalVm = TestViewModel();
      FairyLocator.registerSingleton<TestViewModel>(globalVm);

      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedVm = Fairy.of<TestViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, globalVm), isTrue);
    });

    testWidgets('should return null with tryResolve when both empty',
        (tester) async {
      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedVm = Fairy.maybeOf<TestViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolvedVm, isNull);
    });
  });
}

// Test ViewModels

class TestViewModel extends ObservableObject {
  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    super.dispose();
  }
}

class ScopedViewModel extends ObservableObject {}

class GlobalViewModel extends ObservableObject {}

class OuterViewModel extends ObservableObject {}

class InnerViewModel extends ObservableObject {}
