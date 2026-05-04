import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';
import 'pages/todo_list_page.dart';

// ============================================================================
// ViewModels
// ============================================================================

// ViewModel for Counter example demonstrating MVVM pattern with Fairy
class CounterViewModel extends ObservableObject {
  // Reactive property for counter value (auto-disposed with parent)
  late final ObservableProperty<int> counter;

  // Commands with canExecute logic (auto-disposed with parent)
  // Note: For parameterized commands, use RelayCommandWithParam<T>
  // and bind with Command.param<TViewModel, TParam> in UI
  late final RelayCommand incrementCommand;
  late final RelayCommand decrementCommand;
  late final RelayCommand resetCommand;

  // Store disposer for cleanup
  VoidCallback? _counterDisposer;

  CounterViewModel() {
    counter = ObservableProperty<int>(0);

    incrementCommand = RelayCommand(_increment);

    // Decrement only enabled when counter > 0
    decrementCommand = RelayCommand(
      _decrement,
      canExecute: () => counter.value > 0,
    );

    resetCommand = RelayCommand(_reset);

    // When counter changes, refresh commands that depend on its value
    _counterDisposer = counter.propertyChanged(() {
      decrementCommand.notifyCanExecuteChanged();
    });
  }

  void _increment() {
    counter.value++;
  }

  void _decrement() {
    if (counter.value > 0) {
      counter.value--;
    }
  }

  void _reset() {
    counter.value = 0;
  }

  @override
  void dispose() {
    _counterDisposer?.call();
    super.dispose(); // Auto-disposes counter and all commands
  }
}

// ============================================================================
// Main App
// ============================================================================

void main() {
  runApp(const FairyExampleApp());
}

class FairyExampleApp extends StatelessWidget {
  const FairyExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fairy Examples',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ExamplesHomePage(),
    );
  }
}

class ExamplesHomePage extends StatelessWidget {
  const ExamplesHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Fairy Examples'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calculate, size: 36),
              title: const Text('Simple Counter'),
              subtitle: const Text('Basic MVVM pattern with commands'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CounterExamplePage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.checklist, size: 36),
              title: const Text('Todo List'),
              subtitle: const Text(
                'Complex data handling with lists and filtering',
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TodoListApp()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Counter Example
// ============================================================================

class CounterExamplePage extends StatelessWidget {
  const CounterExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FairyScope(
      viewModels: [ViewModelFactory((_) => CounterViewModel())],
      child: const CounterPage(),
    );
  }
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fairy Counter Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FairyScope(
        // Create scoped ViewModel - automatically disposed when widget is removed
        viewModels: [ViewModelFactory((_) => CounterViewModel())],
        child: const CounterPage(),
      ),
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Fairy Counter Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You have pushed the button this many times:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Bind widget: Two-way data binding with counter property
            // Updates automatically when counter changes
            Bind<CounterViewModel, int>(
              bind: (vm) => vm.counter,
              builder: (context, value, update) {
                return Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineLarge,
                );
              },
            ),

            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Command widget: Decrement button (disabled when counter = 0)
                Command<CounterViewModel>(
                  command: (vm) => vm.decrementCommand,
                  builder: (context, execute, canExecute, isRunning) {
                    return ElevatedButton.icon(
                      onPressed: canExecute ? execute : null,
                      icon: const Icon(Icons.remove),
                      label: const Text('Decrement'),
                    );
                  },
                ),

                const SizedBox(width: 20),

                // Command widget: Increment button
                Command<CounterViewModel>(
                  command: (vm) => vm.incrementCommand,
                  builder: (context, execute, canExecute, isRunning) {
                    return ElevatedButton.icon(
                      onPressed: canExecute ? execute : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Increment'),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Command widget: Reset button
            Command<CounterViewModel>(
              command: (vm) => vm.resetCommand,
              builder: (context, execute, canExecute, isRunning) {
                return ElevatedButton.icon(
                  onPressed: canExecute ? execute : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
