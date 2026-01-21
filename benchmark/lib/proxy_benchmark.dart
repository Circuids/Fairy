import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';

/// Benchmark results for proxy collection performance
class ProxyBenchmarkResults {
  // Mutation latency (microseconds per operation)
  final Map<String, double> mutationLatency = {};

  // Total time for batch operations (microseconds)
  final Map<String, int> batchOperations = {};

  // Memory overhead estimates (bytes)
  final Map<String, int> memoryOverhead = {};

  // Notification throughput (operations per second)
  final Map<String, double> notificationThroughput = {};
}

final _results = ProxyBenchmarkResults();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int iterations = 10000;
  const int warmUpIterations = 100;

  group('Proxy Collection Benchmarks', () {
    group('List Operations', () {
      test('Baseline: Plain List without proxy', () {
        final list = <int>[];

        // Warm up
        for (int i = 0; i < warmUpIterations; i++) {
          list.add(i);
        }
        list.clear();

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          list.add(i);
        }
        stopwatch.stop();

        _results.mutationLatency['List_Baseline_Add'] =
            stopwatch.elapsedMicroseconds / iterations;

        print(
            'Plain List add(): ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['List_Baseline_Add']!.toStringAsFixed(4)}µs/op)');
      });

      test('ProxyList: add() performance', () {
        final prop = ObservableProperty.list<int>([]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Warm up
        for (int i = 0; i < warmUpIterations; i++) {
          prop.value.add(i);
        }
        prop.value.clear();
        notifyCount = 0;

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          prop.value.add(i);
        }
        stopwatch.stop();

        _results.mutationLatency['List_Proxy_Add'] =
            stopwatch.elapsedMicroseconds / iterations;

        expect(notifyCount, iterations);
        print(
            'ProxyList add(): ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['List_Proxy_Add']!.toStringAsFixed(4)}µs/op)');
      });

      test('Baseline: Plain List remove()', () {
        final list = List.generate(iterations, (i) => i);

        // Warm up by removing a few elements
        for (int i = 0; i < warmUpIterations; i++) {
          list.add(i + iterations);
          list.removeLast();
        }

        // Benchmark - removeAt from end is O(1)
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          list.removeLast();
        }
        stopwatch.stop();

        _results.mutationLatency['List_Baseline_RemoveLast'] =
            stopwatch.elapsedMicroseconds / iterations;

        print(
            'Plain List removeLast(): ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['List_Baseline_RemoveLast']!.toStringAsFixed(4)}µs/op)');
      });

      test('ProxyList: removeLast() performance', () {
        final prop = ObservableProperty.list<int>(List.generate(iterations, (i) => i));
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Warm up
        for (int i = 0; i < warmUpIterations; i++) {
          prop.value.add(i + iterations);
          prop.value.removeLast();
        }
        notifyCount = 0;

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          prop.value.removeLast();
        }
        stopwatch.stop();

        _results.mutationLatency['List_Proxy_RemoveLast'] =
            stopwatch.elapsedMicroseconds / iterations;

        expect(notifyCount, iterations);
        print(
            'ProxyList removeLast(): ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['List_Proxy_RemoveLast']!.toStringAsFixed(4)}µs/op)');
      });

      test('Baseline: Plain List index assignment', () {
        final list = List.generate(iterations, (i) => i);

        // Warm up
        for (int i = 0; i < warmUpIterations; i++) {
          list[i % list.length] = i * 2;
        }

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          list[i] = i * 3;
        }
        stopwatch.stop();

        _results.mutationLatency['List_Baseline_IndexSet'] =
            stopwatch.elapsedMicroseconds / iterations;

        print(
            'Plain List []=: ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['List_Baseline_IndexSet']!.toStringAsFixed(4)}µs/op)');
      });

      test('ProxyList: []= performance (with change)', () {
        final prop = ObservableProperty.list<int>(List.generate(iterations, (i) => i));
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Benchmark - add 1 to ensure all values change (including index 0)
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          prop.value[i] = i * 3 + 1;
        }
        stopwatch.stop();

        _results.mutationLatency['List_Proxy_IndexSet'] =
            stopwatch.elapsedMicroseconds / iterations;

        expect(notifyCount, iterations);
        print(
            'ProxyList []=: ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['List_Proxy_IndexSet']!.toStringAsFixed(4)}µs/op)');
      });
    });

    group('Map Operations', () {
      test('Baseline: Plain Map insert', () {
        final map = <String, int>{};

        // Warm up
        for (int i = 0; i < warmUpIterations; i++) {
          map['key$i'] = i;
        }
        map.clear();

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          map['key$i'] = i;
        }
        stopwatch.stop();

        _results.mutationLatency['Map_Baseline_Insert'] =
            stopwatch.elapsedMicroseconds / iterations;

        print(
            'Plain Map []=: ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['Map_Baseline_Insert']!.toStringAsFixed(4)}µs/op)');
      });

      test('ProxyMap: []= performance (new keys)', () {
        final prop = ObservableProperty.map<String, int>({});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Warm up
        for (int i = 0; i < warmUpIterations; i++) {
          prop.value['warmup$i'] = i;
        }
        prop.value.clear();
        notifyCount = 0;

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          prop.value['key$i'] = i;
        }
        stopwatch.stop();

        _results.mutationLatency['Map_Proxy_Insert'] =
            stopwatch.elapsedMicroseconds / iterations;

        expect(notifyCount, iterations);
        print(
            'ProxyMap []=: ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['Map_Proxy_Insert']!.toStringAsFixed(4)}µs/op)');
      });

      test('Baseline: Plain Map remove', () {
        final map = <String, int>{};
        for (int i = 0; i < iterations; i++) {
          map['key$i'] = i;
        }

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          map.remove('key$i');
        }
        stopwatch.stop();

        _results.mutationLatency['Map_Baseline_Remove'] =
            stopwatch.elapsedMicroseconds / iterations;

        print(
            'Plain Map remove(): ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['Map_Baseline_Remove']!.toStringAsFixed(4)}µs/op)');
      });

      test('ProxyMap: remove() performance', () {
        final initialMap = <String, int>{};
        for (int i = 0; i < iterations; i++) {
          initialMap['key$i'] = i;
        }
        final prop = ObservableProperty.map<String, int>(initialMap);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          prop.value.remove('key$i');
        }
        stopwatch.stop();

        _results.mutationLatency['Map_Proxy_Remove'] =
            stopwatch.elapsedMicroseconds / iterations;

        expect(notifyCount, iterations);
        print(
            'ProxyMap remove(): ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['Map_Proxy_Remove']!.toStringAsFixed(4)}µs/op)');
      });
    });

    group('Set Operations', () {
      test('Baseline: Plain Set add', () {
        final set = <int>{};

        // Warm up
        for (int i = 0; i < warmUpIterations; i++) {
          set.add(i);
        }
        set.clear();

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          set.add(i);
        }
        stopwatch.stop();

        _results.mutationLatency['Set_Baseline_Add'] =
            stopwatch.elapsedMicroseconds / iterations;

        print(
            'Plain Set add(): ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['Set_Baseline_Add']!.toStringAsFixed(4)}µs/op)');
      });

      test('ProxySet: add() performance', () {
        final prop = ObservableProperty.set<int>({});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Warm up
        for (int i = 0; i < warmUpIterations; i++) {
          prop.value.add(i + iterations * 2);
        }
        prop.value.clear();
        notifyCount = 0;

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          prop.value.add(i);
        }
        stopwatch.stop();

        _results.mutationLatency['Set_Proxy_Add'] =
            stopwatch.elapsedMicroseconds / iterations;

        expect(notifyCount, iterations);
        print(
            'ProxySet add(): ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['Set_Proxy_Add']!.toStringAsFixed(4)}µs/op)');
      });

      test('Baseline: Plain Set remove', () {
        final set = <int>{};
        for (int i = 0; i < iterations; i++) {
          set.add(i);
        }

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          set.remove(i);
        }
        stopwatch.stop();

        _results.mutationLatency['Set_Baseline_Remove'] =
            stopwatch.elapsedMicroseconds / iterations;

        print(
            'Plain Set remove(): ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['Set_Baseline_Remove']!.toStringAsFixed(4)}µs/op)');
      });

      test('ProxySet: remove() performance', () {
        final initialSet = <int>{};
        for (int i = 0; i < iterations; i++) {
          initialSet.add(i);
        }
        final prop = ObservableProperty.set<int>(initialSet);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Benchmark
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          prop.value.remove(i);
        }
        stopwatch.stop();

        _results.mutationLatency['Set_Proxy_Remove'] =
            stopwatch.elapsedMicroseconds / iterations;

        expect(notifyCount, iterations);
        print(
            'ProxySet remove(): ${stopwatch.elapsedMicroseconds}µs for $iterations ops (${_results.mutationLatency['Set_Proxy_Remove']!.toStringAsFixed(4)}µs/op)');
      });
    });

    group('Notification Throughput', () {
      test('List: notifications per second', () {
        final prop = ObservableProperty.list<int>([]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          prop.value.add(i);
        }
        stopwatch.stop();

        final throughput = iterations / (stopwatch.elapsedMicroseconds / 1000000);
        _results.notificationThroughput['List'] = throughput;

        print(
            'List notification throughput: ${throughput.toStringAsFixed(0)} ops/sec');
      });

      test('Map: notifications per second', () {
        final prop = ObservableProperty.map<String, int>({});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          prop.value['key$i'] = i;
        }
        stopwatch.stop();

        final throughput = iterations / (stopwatch.elapsedMicroseconds / 1000000);
        _results.notificationThroughput['Map'] = throughput;

        print(
            'Map notification throughput: ${throughput.toStringAsFixed(0)} ops/sec');
      });

      test('Set: notifications per second', () {
        final prop = ObservableProperty.set<int>({});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < iterations; i++) {
          prop.value.add(i);
        }
        stopwatch.stop();

        final throughput = iterations / (stopwatch.elapsedMicroseconds / 1000000);
        _results.notificationThroughput['Set'] = throughput;

        print(
            'Set notification throughput: ${throughput.toStringAsFixed(0)} ops/sec');
      });
    });

    group('Overhead Analysis', () {
      test('List: Calculate proxy overhead percentage', () {
        final baseline = _results.mutationLatency['List_Baseline_Add'] ?? 0;
        final proxy = _results.mutationLatency['List_Proxy_Add'] ?? 0;

        if (baseline > 0) {
          final overhead = ((proxy - baseline) / baseline) * 100;
          print(
              '\n📊 List add() overhead: ${overhead.toStringAsFixed(2)}% (${baseline.toStringAsFixed(4)}µs → ${proxy.toStringAsFixed(4)}µs)');
        }
      });

      test('Map: Calculate proxy overhead percentage', () {
        final baseline = _results.mutationLatency['Map_Baseline_Insert'] ?? 0;
        final proxy = _results.mutationLatency['Map_Proxy_Insert'] ?? 0;

        if (baseline > 0) {
          final overhead = ((proxy - baseline) / baseline) * 100;
          print(
              '📊 Map insert overhead: ${overhead.toStringAsFixed(2)}% (${baseline.toStringAsFixed(4)}µs → ${proxy.toStringAsFixed(4)}µs)');
        }
      });

      test('Set: Calculate proxy overhead percentage', () {
        final baseline = _results.mutationLatency['Set_Baseline_Add'] ?? 0;
        final proxy = _results.mutationLatency['Set_Proxy_Add'] ?? 0;

        if (baseline > 0) {
          final overhead = ((proxy - baseline) / baseline) * 100;
          print(
              '📊 Set add() overhead: ${overhead.toStringAsFixed(2)}% (${baseline.toStringAsFixed(4)}µs → ${proxy.toStringAsFixed(4)}µs)');
        }
      });

      test('Summary: Print all results', () {
        print('\n' + '=' * 60);
        print('PROXY COLLECTION BENCHMARK SUMMARY');
        print('=' * 60);
        print('\n📈 Mutation Latency (µs per operation):');
        _results.mutationLatency.forEach((key, value) {
          print('  $key: ${value.toStringAsFixed(4)}µs');
        });
        print('\n🚀 Notification Throughput (ops/sec):');
        _results.notificationThroughput.forEach((key, value) {
          print('  $key: ${value.toStringAsFixed(0)} ops/sec');
        });
        print('=' * 60 + '\n');
      });
    });
  });
}
