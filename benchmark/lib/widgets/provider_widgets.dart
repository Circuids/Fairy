import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import '../models/provider_models.dart';

/// Provider counter widget for performance testing
class ProviderCounterWidget extends StatelessWidget {
  const ProviderCounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return provider.ChangeNotifierProvider(
      create: (_) => ProviderCounterNotifier(),
      child: Column(
        children: [
          provider.Consumer<ProviderCounterNotifier>(
            builder: (context, notifier, child) =>
                Text('Count: ${notifier.counter}'),
          ),
          provider.Consumer<ProviderCounterNotifier>(
            builder: (context, notifier, child) => ElevatedButton(
              onPressed: notifier.increment,
              child: const Text('Increment'),
            ),
          ),
        ],
      ),
    );
  }
}
