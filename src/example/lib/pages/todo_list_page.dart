import 'package:fairy/fairy.dart';
import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../viewmodels/todo_list_viewmodel.dart';

// ============================================================================
// Todo List Example
// ============================================================================

class TodoListApp extends StatelessWidget {
  const TodoListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FairyScope(
      viewModel: (_) => TodoListViewModel(),
      child: const TodoListPage(),
    );
  }
}

class TodoListPage extends StatelessWidget {
  const TodoListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Todo List'),
        actions: [
          // Show only active toggle
          Command<TodoListViewModel>(
            command: (vm) => vm.toggleFilterCommand,
            builder: (context, execute, canExecute, isRunning) {
              return Bind<TodoListViewModel, bool>(
                bind: (vm) => vm.showOnlyActive,
                builder: (context, showOnlyActive, update) {
                  return IconButton(
                    icon: Icon(
                      showOnlyActive
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                    ),
                    onPressed: execute,
                    tooltip: showOnlyActive ? 'Show All' : 'Show Active Only',
                  );
                },
              );
            },
          ),
          // Clear completed button
          Command<TodoListViewModel>(
            command: (vm) => vm.clearCompletedCommand,
            builder: (context, execute, canExecute, isRunning) {
              return IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: canExecute ? execute : null,
                tooltip: 'Clear Completed',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Bind.viewModel<TodoListViewModel>(
              builder: (context, vm) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatCard(
                      label: 'Total',
                      count: vm.totalCount.value,
                      icon: Icons.checklist,
                      color: Colors.blue,
                    ),
                    _StatCard(
                      label: 'Active',
                      count: vm.activeCount.value,
                      icon: Icons.pending_actions,
                      color: Colors.orange,
                    ),
                    _StatCard(
                      label: 'Completed',
                      count: vm.completedCount.value,
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ],
                );
              },
            ),
          ),

          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                Bind<TodoListViewModel, String>(
                  bind: (vm) => vm.filterText,
                  builder: (context, value, update) {
                    return TextField(
                      onChanged: update,
                      decoration: InputDecoration(
                        hintText: 'Search todos...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: value.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => update?.call(''),
                              )
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Priority filter chips
                Bind<TodoListViewModel, TodoPriority?>(
                  bind: (vm) => vm.filterPriority,
                  builder: (context, selectedPriority, update) {
                    final vm = Fairy.of<TodoListViewModel>(context);
                    return Row(
                      children: [
                        const Text('Priority: '),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('All'),
                          selected: selectedPriority == null,
                          onSelected: (_) => vm.setPriorityFilter(null),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('High'),
                          selected: selectedPriority == TodoPriority.high,
                          onSelected: (_) =>
                              vm.setPriorityFilter(TodoPriority.high),
                          avatar: const Icon(
                            Icons.circle,
                            color: Colors.red,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Medium'),
                          selected: selectedPriority == TodoPriority.medium,
                          onSelected: (_) =>
                              vm.setPriorityFilter(TodoPriority.medium),
                          avatar: const Icon(
                            Icons.circle,
                            color: Colors.orange,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Low'),
                          selected: selectedPriority == TodoPriority.low,
                          onSelected: (_) =>
                              vm.setPriorityFilter(TodoPriority.low),
                          avatar: const Icon(
                            Icons.circle,
                            color: Colors.green,
                            size: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Todo List
          Expanded(
            child: Bind<TodoListViewModel, List<Todo>>(
              bind: (vm) => vm.filteredTodos,
              builder: (context, todos, update) {
                if (todos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No todos found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: todos.length,
                  itemBuilder: (context, index) {
                    final todo = todos[index];
                    return _TodoItem(todo: todo);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTodoDialog(BuildContext context) {
    showDialog(
      context: context,
      // Bridge parent context to overlay using FairyBridge widget
      // This allows Command and Bind widgets to work inside dialogs!
      builder: (dialogContext) =>
          FairyBridge(context: context, child: const _AddTodoDialog()),
    );
  }
}

// ============================================================================
// Add Todo Dialog Widget
// ============================================================================

/// How to use Command widgets in dialogs?
///
// ignore: unintended_html_in_doc_comment
/// **Problem:** Command widgets need to resolve ViewModels using Fairy.of<T>(context),
/// but showDialog() creates a NEW widget tree (overlay route) that doesn't have
/// access to the parent page's FairyScope.
///
/// **Solution:** Use `FairyBridge` widget to bridge the parent context!
///
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => FairyBridge(
///     context: context,  // Parent context with FairyScope
///     child: MyDialogWidget(),  // Now Command widgets work!
///   ),
/// );
/// ```
///
/// **Benefits:**
/// - ✅ Command widgets work seamlessly in dialogs
/// - ✅ Bind widgets also work
/// - ✅ Automatic canExecute reactivity
/// - ✅ No need to manually pass ViewModels
/// - ✅ Same API as regular pages
///
/// This dialog demonstrates:
/// 1. Using Bind widget to access TextEditingController
/// 2. Using Command.param widget for parameterized command
/// 3. Automatic button enable/disable based on canExecute
class _AddTodoDialog extends StatelessWidget {
  const _AddTodoDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Todo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Use Bind widget to get the TextEditingController
          Bind<TodoListViewModel, TextEditingController>(
            bind: (vm) => vm.titleController,
            builder: (context, controller, update) {
              return TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter todo title',
                ),
                autofocus: true,
                // Notify command to re-evaluate canExecute
                onChanged: (_) => update?.call(controller),
              );
            },
          ),
          const SizedBox(height: 16),
          Bind<TodoListViewModel, TextEditingController>(
            bind: (vm) => vm.descriptionController,
            builder: (context, controller, update) {
              return TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter description (optional)',
                ),
                maxLines: 3,
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        // Use Command.param widget for Add button
        // We bind to the TextEditingController and use ValueListenableBuilder
        // to rebuild when the text changes
        Bind<TodoListViewModel, TextEditingController>(
          bind: (vm) => vm.titleController,
          builder: (context, controller, _) {
            // ValueListenableBuilder listens to controller changes and rebuilds
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return Command.param<TodoListViewModel, String>(
                  command: (vm) => vm.addTodoCommand,
                  builder: (context, execute, canExecute, isRunning) {
                    return FilledButton(
                      onPressed: canExecute(value.text)
                          ? () {
                              execute(value.text);
                              Navigator.pop(context);
                            }
                          : null,
                      child: const Text('Add'),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// Todo List Widgets
// ============================================================================

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TodoItem extends StatelessWidget {
  final Todo todo;

  const _TodoItem({required this.todo});

  @override
  Widget build(BuildContext context) {
    final vm = Fairy.of<TodoListViewModel>(context);

    return Dismissible(
      key: Key(todo.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => vm.deleteTodoCommand.execute(todo.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            // ignore: deprecated_member_use
            backgroundColor: todo.priorityColor.withOpacity(0.2),
            child: Icon(
              todo.isCompleted ? Icons.check_circle : Icons.circle_outlined,
              color: todo.priorityColor,
            ),
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
              color: todo.isCompleted ? Colors.grey : null,
            ),
          ),
          subtitle: todo.description.isNotEmpty
              ? Text(
                  todo.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    decoration: todo.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    color: todo.isCompleted ? Colors.grey : null,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: todo.priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  todo.isCompleted
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                onPressed: () => vm.toggleTodoCommand.execute(todo.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
