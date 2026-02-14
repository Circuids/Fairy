# Fairy Framework Benchmarks

This project contains performance benchmarks comparing Fairy with other popular Flutter state management frameworks.

## Running Benchmarks

To run the performance benchmarks:

```bash
flutter test lib/benchmark.dart
```

## Results

The benchmarks compare three frameworks:
- **🧚 Fairy**: Our lightweight MVVM framework
- **📦 Provider**: Popular state management solution  
- **🏗️ Riverpod**: Modern reactive framework

### Latest Results (v3.0.1)

Performance metrics (median of 5 measurements per test, averaged across 5 complete runs):

| Category | Fairy | Provider | Riverpod | Winner |
|----------|-------|----------|----------|---------|
| Widget Performance (1000 interactions) | 116.5% | 104.9% | 100% | Riverpod 🥇 |
| Memory Management (50 cycles) | 113.9% | 105.1% | 100% | Riverpod 🥇 |
| Selective Rebuild (explicit Bind) | 100% | 138.3% | 130.2% | Fairy 🥇 |
| Auto-tracking Rebuild (Bind.viewModel) | 100% | 132.4% | 124.5% | Fairy 🥇 |

**Key Highlights:**
- **Selective Rebuilds**: Fairy is 30-38% faster (22-23ms vs 30-32ms)
- **Auto-tracking**: Fairy is 24-32% faster (15.92ms vs 19.81-21.08ms)
- **Rebuild Efficiency**: Fairy achieves 100% efficiency (500 rebuilds) vs 33% for Provider/Riverpod (1500 rebuilds)
- **Memory**: **Intentional design decision** to use 14% more memory in exchange for 24-38% faster rebuilds (both auto-tracking and selective binding) plus superior developer experience with command auto-tracking

*Lower percentages are better. All measurements use engine warm-up and median-of-5 methodology to reduce noise.*

## Frameworks Tested

All benchmarks use real framework implementations:

- **Fairy**: Uses `FairyScope`, `Bind`, and `Command` widgets
- **Provider**: Uses `ChangeNotifierProvider`, `Selector` and `Consumer`  
- **Riverpod**: Uses `StateNotifierProvider`, `Select` and `ConsumerWidget`

## Test Scenarios

1. **Widget Performance**: 1000 rapid state updates with UI rebuilds
2. **Memory Management**: 50 create/dispose cycles with state changes
3. **Selective Rebuild** (explicit Bind): 100 property updates with manual selectors
4. **Auto-tracking Rebuild** (Bind.viewModel): 500 property updates with automatic dependency tracking

Each test includes:
- Engine warm-up phase (3 rounds × all frameworks)
- 5 measurements per framework (median selected)
- Full disposal between framework tests

The benchmarks use Flutter's `widgetTest` with `pumpWidget` for accurate, real-world performance measurement.