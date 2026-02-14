import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ───────────────────────────────────────────────────────────────────────────
// ViewModels for testing
// ───────────────────────────────────────────────────────────────────────────
class _ViewModelA extends ObservableObject {
  late final name = ObservableProperty<String>('A');
}

class _ViewModelB extends ObservableObject {
  late final name = ObservableProperty<String>('B');
}

class _ViewModelC extends ObservableObject {
  late final name = ObservableProperty<String>('C');
}

class _ViewModelD extends ObservableObject {
  late final name = ObservableProperty<String>('D');
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Bind.viewModel2 — duplicate type prevention
  // ─────────────────────────────────────────────────────────────────────────
  group('Bind.viewModel2 — duplicate type assertion', () {
    testWidgets(
      'throws AssertionError when both type parameters are the same',
      (tester) async {
        final vm = _ViewModelA();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vm],
              child: Builder(
                builder: (context) {
                  // Should throw assertion error
                  expect(
                    () => Bind.viewModel2<_ViewModelA, _ViewModelA>(
                      builder: (context, a1, a2) => Text('${a1.name.value}'),
                    ),
                    throwsAssertionError,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
      },
    );

    testWidgets(
      'does NOT throw when type parameters are different',
      (tester) async {
        final vmA = _ViewModelA();
        final vmB = _ViewModelB();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB],
              child: Bind.viewModel2<_ViewModelA, _ViewModelB>(
                builder: (context, a, b) {
                  return Text('${a.name.value} ${b.name.value}');
                },
              ),
            ),
          ),
        );

        expect(find.text('A B'), findsOneWidget);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bind.viewModel3 — duplicate type prevention
  // ─────────────────────────────────────────────────────────────────────────
  group('Bind.viewModel3 — duplicate type assertion', () {
    testWidgets(
      'throws when first and second types are the same',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => Bind.viewModel3<_ViewModelA, _ViewModelA, _ViewModelC>(
                    builder: (context, a1, a2, c) => const SizedBox.shrink(),
                  ),
                  throwsAssertionError,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'throws when first and third types are the same',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => Bind.viewModel3<_ViewModelA, _ViewModelB, _ViewModelA>(
                    builder: (context, a1, b, a2) => const SizedBox.shrink(),
                  ),
                  throwsAssertionError,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'throws when second and third types are the same',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => Bind.viewModel3<_ViewModelA, _ViewModelB, _ViewModelB>(
                    builder: (context, a, b1, b2) => const SizedBox.shrink(),
                  ),
                  throwsAssertionError,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'throws when all three types are the same',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => Bind.viewModel3<_ViewModelA, _ViewModelA, _ViewModelA>(
                    builder: (context, a1, a2, a3) => const SizedBox.shrink(),
                  ),
                  throwsAssertionError,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'does NOT throw when all three types are different',
      (tester) async {
        final vmA = _ViewModelA();
        final vmB = _ViewModelB();
        final vmC = _ViewModelC();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB, (_) => vmC],
              child: Bind.viewModel3<_ViewModelA, _ViewModelB, _ViewModelC>(
                builder: (context, a, b, c) {
                  return Text(
                      '${a.name.value} ${b.name.value} ${c.name.value}');
                },
              ),
            ),
          ),
        );

        expect(find.text('A B C'), findsOneWidget);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bind.viewModel4 — duplicate type prevention
  // ─────────────────────────────────────────────────────────────────────────
  group('Bind.viewModel4 — duplicate type assertion', () {
    testWidgets(
      'throws when first and second types are the same',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => Bind.viewModel4<_ViewModelA, _ViewModelA, _ViewModelC,
                      _ViewModelD>(
                    builder: (context, a1, a2, c, d) => const SizedBox.shrink(),
                  ),
                  throwsAssertionError,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'throws when first and third types are the same',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => Bind.viewModel4<_ViewModelA, _ViewModelB, _ViewModelA,
                      _ViewModelD>(
                    builder: (context, a1, b, a2, d) => const SizedBox.shrink(),
                  ),
                  throwsAssertionError,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'throws when first and fourth types are the same',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => Bind.viewModel4<_ViewModelA, _ViewModelB, _ViewModelC,
                      _ViewModelA>(
                    builder: (context, a1, b, c, a2) => const SizedBox.shrink(),
                  ),
                  throwsAssertionError,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'throws when second and third types are the same',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => Bind.viewModel4<_ViewModelA, _ViewModelB, _ViewModelB,
                      _ViewModelD>(
                    builder: (context, a, b1, b2, d) => const SizedBox.shrink(),
                  ),
                  throwsAssertionError,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'throws when third and fourth types are the same',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => Bind.viewModel4<_ViewModelA, _ViewModelB, _ViewModelC,
                      _ViewModelC>(
                    builder: (context, a, b, c1, c2) => const SizedBox.shrink(),
                  ),
                  throwsAssertionError,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'throws when all four types are the same',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => Bind.viewModel4<_ViewModelA, _ViewModelA, _ViewModelA,
                      _ViewModelA>(
                    builder: (context, a1, a2, a3, a4) =>
                        const SizedBox.shrink(),
                  ),
                  throwsAssertionError,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'does NOT throw when all four types are different',
      (tester) async {
        final vmA = _ViewModelA();
        final vmB = _ViewModelB();
        final vmC = _ViewModelC();
        final vmD = _ViewModelD();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModels: [(_) => vmA, (_) => vmB, (_) => vmC, (_) => vmD],
              child: Bind.viewModel4<_ViewModelA, _ViewModelB, _ViewModelC,
                  _ViewModelD>(
                builder: (context, a, b, c, d) {
                  return Text(
                    '${a.name.value} ${b.name.value} ${c.name.value} ${d.name.value}',
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('A B C D'), findsOneWidget);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Direct constructor usage (BindViewModel2/3/4) — same assertions
  // ─────────────────────────────────────────────────────────────────────────
  group('Direct BindViewModel constructors — duplicate type assertion', () {
    testWidgets(
      'BindViewModel2 throws when types are the same',
      (tester) async {
        expect(
          () => BindViewModel2<_ViewModelA, _ViewModelA>(
            builder: (context, a1, a2) => const SizedBox.shrink(),
          ),
          throwsAssertionError,
        );
      },
    );

    testWidgets(
      'BindViewModel3 throws when any two types are the same',
      (tester) async {
        expect(
          () => BindViewModel3<_ViewModelA, _ViewModelB, _ViewModelA>(
            builder: (context, a1, b, a2) => const SizedBox.shrink(),
          ),
          throwsAssertionError,
        );
      },
    );

    testWidgets(
      'BindViewModel4 throws when any two types are the same',
      (tester) async {
        expect(
          () => BindViewModel4<_ViewModelA, _ViewModelB, _ViewModelC,
              _ViewModelB>(
            builder: (context, a, b1, c, b2) => const SizedBox.shrink(),
          ),
          throwsAssertionError,
        );
      },
    );
  });
}
