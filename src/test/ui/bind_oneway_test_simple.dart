import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';

// Simple ViewModel for one-way binding tests
class SimpleViewModel extends ObservableObject {
  String _message = 'Initial';

  String get message => _message;

  void updateMessage(String value) {
    _message = value;
    onPropertyChanged(); // Explicitly notify listeners
  }
}

void main() {
  group('Bind widget - One-Way Binding', () {
    testWidgets('should detect raw value and provide null update callback',
        (tester) async {
      final vm = SimpleViewModel();
      void Function(String)? capturedUpdate;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<SimpleViewModel, String>(
              bind: (vm) => vm.message, // Raw String, not ObservableProperty
              builder: (context, value, update) {
                capturedUpdate = update;
                return Text(value);
              },
            ),
          ),
        ),
      );

      // Update callback should be null for one-way binding
      expect(capturedUpdate, isNull);
      expect(find.text('Initial'), findsOneWidget);
    });

    testWidgets('should rebuild when ViewModel notifies', (tester) async {
      final vm = SimpleViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<SimpleViewModel, String>(
              bind: (vm) => vm.message,
              builder: (context, value, update) => Text(value),
            ),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);

      // Update via ViewModel method that calls notify()
      vm.updateMessage('Updated');
      await tester.pump();

      expect(find.text('Updated'), findsOneWidget);
    });

    testWidgets('should not rebuild when oneTime is true', (tester) async {
      final vm = SimpleViewModel();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [ViewModelFactory((_) => vm)],
            child: Bind<SimpleViewModel, String>(
              bind: (vm) => vm.message,
              builder: (context, value, update) {
                buildCount++;
                return Text(value);
              },
              oneTime: true, // No subscription
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('Initial'), findsOneWidget);

      // Update - should NOT trigger rebuild
      vm.updateMessage('Updated');
      await tester.pump();

      expect(buildCount, equals(1)); // Still 1
      expect(find.text('Initial'), findsOneWidget); // Still initial
    });
  });
}
