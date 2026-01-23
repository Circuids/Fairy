import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';
import '../models/todo.dart';

// ViewModel for Todo List demonstrating complex data handling
class TodoListViewModel extends ObservableObject {
  // Observable properties (auto-disposed with parent)
  late final ObservableProperty<List<Todo>> todos;
  late final ObservableProperty<String> filterText;
  late final ObservableProperty<bool> showOnlyActive;
  late final ObservableProperty<TodoPriority?> filterPriority;

  // Computed property for filtered todos
  late final ComputedProperty<List<Todo>> filteredTodos;

  // Computed properties for statistics
  late final ComputedProperty<int> totalCount;
  late final ComputedProperty<int> completedCount;
  late final ComputedProperty<int> activeCount;

  // Commands
  late final addTodoCommand = RelayCommand.param<String>(
    _addTodo,
    canExecute: (title) => title.trim().isNotEmpty,
  );
  late final toggleTodoCommand = RelayCommand.param<String>(_toggleTodo);
  late final deleteTodoCommand = RelayCommand.param<String>(_deleteTodo);
  late final RelayCommand clearCompletedCommand;
  late final RelayCommand toggleFilterCommand;

  // Controllers for text fields
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  TodoListViewModel() {
    // Initialize properties
    todos = ObservableProperty<List<Todo>>([
      Todo(
        id: '1',
        title: 'Welcome to Fairy',
        description: 'Explore this example to see Fairy\'s capabilities',
        isCompleted: false,
        priority: TodoPriority.high,
        createdAt: DateTime.now(),
      ),
      Todo(
        id: '2',
        title: 'Check out the source code',
        description: 'See how clean MVVM patterns work with Fairy',
        isCompleted: false,
        priority: TodoPriority.medium,
        createdAt: DateTime.now(),
      ),
      Todo(
        id: '3',
        title: 'Try adding new todos',
        description: 'Test the reactive data binding',
        isCompleted: true,
        priority: TodoPriority.low,
        createdAt: DateTime.now(),
      ),
    ]);

    filterText = ObservableProperty<String>('');
    showOnlyActive = ObservableProperty<bool>(false);
    filterPriority = ObservableProperty<TodoPriority?>(null);

    // Computed property automatically updates when dependencies change
    filteredTodos = ComputedProperty<List<Todo>>(
      () {
        var result = todos.value;

        // Filter by active status
        if (showOnlyActive.value) {
          result = result.where((todo) => !todo.isCompleted).toList();
        }

        // Filter by priority
        if (filterPriority.value != null) {
          result = result
              .where((todo) => todo.priority == filterPriority.value)
              .toList();
        }

        // Filter by search text
        if (filterText.value.isNotEmpty) {
          final query = filterText.value.toLowerCase();
          result = result
              .where(
                (todo) =>
                    todo.title.toLowerCase().contains(query) ||
                    todo.description.toLowerCase().contains(query),
              )
              .toList();
        }

        return result;
      },
      [todos, filterText, showOnlyActive, filterPriority],
      this,
    );

    totalCount = ComputedProperty<int>(() => todos.value.length, [todos], this);
    completedCount = ComputedProperty<int>(
      () => todos.value.where((t) => t.isCompleted).length,
      [todos],
      this,
    );
    activeCount = ComputedProperty<int>(
      () => todos.value.where((t) => !t.isCompleted).length,
      [todos],
      this,
    );

    // Initialize commands
    clearCompletedCommand = RelayCommand(
      _clearCompleted,
      canExecute: () => completedCount.value > 0,
    );

    toggleFilterCommand = RelayCommand(_toggleFilter);
  }

  void _addTodo(String? title) {
    if (title == null || title.trim().isEmpty) return;

    final newTodo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: descriptionController.text,
      isCompleted: false,
      priority: TodoPriority.medium,
      createdAt: DateTime.now(),
    );

    // Deep equality ensures the list change is detected
    todos.value = [...todos.value, newTodo];

    // Clear text fields
    titleController.clear();
    descriptionController.clear();

    // Refresh clear completed command
    clearCompletedCommand.notifyCanExecuteChanged();
  }

  void _toggleTodo(String? id) {
    if (id == null) return;

    todos.value = todos.value.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(isCompleted: !todo.isCompleted);
      }
      return todo;
    }).toList();

    clearCompletedCommand.notifyCanExecuteChanged();
  }

  void _deleteTodo(String? id) {
    if (id == null) return;

    todos.value = todos.value.where((todo) => todo.id != id).toList();
    clearCompletedCommand.notifyCanExecuteChanged();
  }

  void _clearCompleted() {
    todos.value = todos.value.where((todo) => !todo.isCompleted).toList();
    clearCompletedCommand.notifyCanExecuteChanged();
  }

  void _toggleFilter() {
    showOnlyActive.value = !showOnlyActive.value;
  }

  void setPriorityFilter(TodoPriority? priority) {
    filterPriority.value = priority;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
