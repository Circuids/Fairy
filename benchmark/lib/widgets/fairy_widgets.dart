import 'package:flutter/material.dart';
import 'package:fairy/fairy.dart';
import '../models/fairy_models.dart';

/// Fairy counter widget for performance testing (using explicit Bind)
class FairyCounterWidget extends StatelessWidget {
  const FairyCounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FairyScope(
      viewModel: (_) => FairyCounterViewModel(),
      child: Builder(
        builder: (context) {
          return Column(
            children: [
              Bind<FairyCounterViewModel, int>(
                bind: (vm) => vm.counter.value,
                builder: (context, value, update) => Text('Count: $value'),
              ),
              Command<FairyCounterViewModel>(
                command: (vm) => vm.incrementCommand,
                builder: (context, execute, canExecute, isRunning) =>
                    ElevatedButton(
                      onPressed: execute,
                      child: const Text('Increment'),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fairy counter widget using BindObserver (Consumer-like automatic tracking)
class FairyObserverCounterWidget extends StatelessWidget {
  const FairyObserverCounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FairyScope(
      viewModel: (_) => FairyCounterViewModel(),
      child: Builder(
        builder: (context) {
          return Column(
            children: [
              Bind.viewModel<FairyCounterViewModel>(
                builder: (context, vm) => Text('Count: ${vm.counter.value}'),
              ),
              Bind.viewModel<FairyCounterViewModel>(
                builder: (context, vm) => ElevatedButton(
                  onPressed: () => vm.incrementCommand.execute(),
                  child: const Text('Increment'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
