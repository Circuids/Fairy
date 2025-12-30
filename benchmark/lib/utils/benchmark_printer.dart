import '../models/benchmark_results.dart';

/// Prints formatted benchmark results to console
void printBenchmarkResults(BenchmarkResults results) {
  print('\n');
  print(
    '╔═══════════════════════════════════════════════════════════════════╗',
  );
  print(
    '║          🏆 Flutter State Management Benchmark Results 🏆         ║',
  );
  print(
    '╚═══════════════════════════════════════════════════════════════════╝',
  );
  print('');

  // Widget Performance Table
  printSection(
    'Widget Performance (1000 interactions)',
    results.widgetPerformance,
  );

  // Memory Performance Table
  printSection(
    'Memory Management (50 create/dispose cycles)',
    results.memoryPerformance,
  );

  // Selective Rebuild Performance Table (using explicit Bind with selectors)
  printSection(
    'Selective Rebuild Performance (100 property updates, explicit Bind)',
    results.selectiveRebuildPerformance,
  );

  // Rebuild Performance Table (using Bind.viewModel auto-tracking)
  printSection(
    'Rebuild Performance (100 property updates, auto-tracking)',
    results.rebuildPerformance,
  );

  // Summary
  printSummary(results);
}

/// Prints a single benchmark section with formatted results
void printSection(String title, Map<String, int> data) {
  if (data.isEmpty) return;

  print(
    '┌───────────────────────────────────────────────────────────────────┐',
  );
  print('│ $title');
  print('├─────────────────┬────────────────┬──────────────┬────────────────┤');
  print('│ Framework       │ Time (μs)      │ Time (ms)    │ Relative (%)   │');
  print('├─────────────────┼────────────────┼──────────────┼────────────────┤');

  // Find the fastest time
  final fastest = data.values.reduce((a, b) => a < b ? a : b);

  // Sort by performance (fastest first)
  final sorted = data.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  for (var i = 0; i < sorted.length; i++) {
    final entry = sorted[i];
    final rawName = entry.key;
    final time = entry.value;
    final ms = (time / 1000).toStringAsFixed(2);
    final relative = ((time / fastest) * 100).toStringAsFixed(1);

    // Clean up display name - remove suffixes like "(selective)", "Bind.viewModel", "Consumer"
    String displayName = rawName
        .replaceAll(' (selective)', '')
        .replaceAll(' Bind.viewModel', '')
        .replaceAll(' Consumer', '');

    // Extract base framework name for emoji
    String baseName = displayName;
    if (displayName.startsWith('Fairy')) {
      baseName = 'Fairy';
    } else if (displayName.startsWith('Provider')) {
      baseName = 'Provider';
    } else if (displayName.startsWith('Riverpod')) {
      baseName = 'Riverpod';
    }

    String emoji;
    switch (baseName) {
      case 'Fairy':
        emoji = '🧚';
        break;
      case 'Provider':
        emoji = '📦';
        break;
      case 'Riverpod':
        emoji = '🏗️';
        break;
      default:
        emoji = '  ';
    }

    String medal = '';
    if (i == 0) {
      medal = ' 🥇';
    } else if (i == 1) {
      medal = ' 🥈';
    } else if (i == 2) {
      medal = ' 🥉';
    }

    final nameField = '$emoji $displayName$medal'.padRight(15);
    final timeField = time.toString().padLeft(14);
    final msField = ms.padLeft(12);
    final relativeField = relative.padLeft(14);

    print('│ $nameField │ $timeField │ $msField │ $relativeField │');
  }

  print('└─────────────────┴────────────────┴──────────────┴────────────────┘');
  print('');
}

/// Prints summary with medal counts and key insights
void printSummary(BenchmarkResults results) {
  print(
    '┌───────────────────────────────────────────────────────────────────┐',
  );
  print(
    '│ 📊 Summary                                                        │',
  );
  print(
    '├───────────────────────────────────────────────────────────────────┤',
  );

  // Count medals
  final medals = <String, Map<String, int>>{
    'Fairy': {'gold': 0, 'silver': 0, 'bronze': 0},
    'Provider': {'gold': 0, 'silver': 0, 'bronze': 0},
    'Riverpod': {'gold': 0, 'silver': 0, 'bronze': 0},
  };

  // Helper function to extract framework name from entries like "Fairy (selective)" or "Fairy"
  String extractFramework(String name) {
    if (name.startsWith('Fairy')) return 'Fairy';
    if (name.startsWith('Provider')) return 'Provider';
    if (name.startsWith('Riverpod')) return 'Riverpod';
    return name;
  }

  for (final category in [
    results.widgetPerformance,
    results.memoryPerformance,
    results.selectiveRebuildPerformance,
    results.rebuildPerformance,
  ]) {
    if (category.isEmpty) continue;
    final sorted = category.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (sorted.isNotEmpty) {
      final winner = extractFramework(sorted[0].key);
      medals[winner]!['gold'] = medals[winner]!['gold']! + 1;
    }
    if (sorted.length > 1) {
      final second = extractFramework(sorted[1].key);
      medals[second]!['silver'] = medals[second]!['silver']! + 1;
    }
    if (sorted.length > 2) {
      final third = extractFramework(sorted[2].key);
      medals[third]!['bronze'] = medals[third]!['bronze']! + 1;
    }
  }

  for (final entry in medals.entries) {
    final name = entry.key;
    final counts = entry.value;
    final total = counts['gold']! + counts['silver']! + counts['bronze']!;

    if (total > 0) {
      String emoji;
      switch (name) {
        case 'Fairy':
          emoji = '🧚';
          break;
        case 'Provider':
          emoji = '📦';
          break;
        case 'Riverpod':
          emoji = '🏗️';
          break;
        default:
          emoji = '  ';
      }

      final nameField = '$emoji $name:'.padRight(18);
      final medalsStr =
          '🥇×${counts['gold']} 🥈×${counts['silver']} 🥉×${counts['bronze']}';
      print('│ $nameField $medalsStr');
    }
  }

  print(
    '├───────────────────────────────────────────────────────────────────┤',
  );
  print(
    '│ 💡 Key Insights:                                                  │',
  );

  // Calculate Fairy's position
  final fairyWidget = results.widgetPerformance['Fairy'] ?? 0;
  final fairyMemory = results.memoryPerformance['Fairy'] ?? 0;

  if (fairyWidget > 0) {
    final fastestWidget = results.widgetPerformance.values.reduce(
      (a, b) => a < b ? a : b,
    );
    final diff = ((fairyWidget / fastestWidget - 1) * 100).toStringAsFixed(1);
    if (fairyWidget == fastestWidget) {
      print(
        '│    • Fairy has the FASTEST widget interaction performance! ⚡    │',
      );
    } else {
      print(
        '│    • Fairy is within $diff% of fastest for widget interactions        │',
      );
    }
  }

  if (fairyMemory > 0) {
    final fastestMemory = results.memoryPerformance.values.reduce(
      (a, b) => a < b ? a : b,
    );
    if (fairyMemory == fastestMemory) {
      print(
        '│    • Fairy has the BEST memory management! 🧠                    │',
      );
    } else {
      final diff = ((fairyMemory / fastestMemory - 1) * 100).toStringAsFixed(1);
      print(
        '│    • Fairy memory management within $diff% of best                   │',
      );
    }
  }

  // Selective rebuild insights
  if (results.selectiveRebuildPerformance.isNotEmpty) {
    final sorted = results.selectiveRebuildPerformance.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (sorted.isNotEmpty) {
      final fastest = sorted.first;
      final fastestName = fastest.key;

      // Find best selective approach (those with 100% efficiency)
      final selectiveApproaches = sorted
          .where(
            (e) => e.key.contains('selective') || e.key.contains('TWO-WAY'),
          )
          .toList();

      // Find best global approach (those with ~33% efficiency)
      final globalApproaches = sorted
          .where((e) => e.key.contains('global') || e.key.contains('ONE-WAY'))
          .toList();

      if (fastestName.contains('Fairy')) {
        print(
          '│    • Fairy has the FASTEST rebuild performance! ⚡               │',
        );
      }

      if (selectiveApproaches.isNotEmpty && globalApproaches.isNotEmpty) {
        final bestSelective = selectiveApproaches.first;
        final bestGlobal = globalApproaches.first;

        if (bestGlobal.value < bestSelective.value) {
          print(
            '│    • Global approach faster despite lower efficiency! 🎯        │',
          );
        } else {
          print(
            '│    • Selective approach provides best rebuild optimization 🎯   │',
          );
        }
      }
    }
  }

  print('│    • All frameworks show excellent performance 🚀                │');
  print('│    • Differences are negligible in real-world apps 📱            │');
  print(
    '└───────────────────────────────────────────────────────────────────┘',
  );
  print('');
}
