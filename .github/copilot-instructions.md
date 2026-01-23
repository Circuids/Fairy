# Fairy – AI Agent Instructions

Fairy is a lightweight MVVM framework for Flutter with reactive data binding, command patterns, and dependency injection. No build_runner required.

**Key Positioning:** Learn just 2 widgets (`Bind` and `Command`) - you're covering almost all use cases.

## Architecture Layers

1. **Core** (`lib/src/core/`): `ObservableObject`, `ObservableProperty<T>`, `RelayCommand`, `AsyncRelayCommand`, `RelayCommand.param<T>`, `AsyncRelayCommand.param<T>`, `ComputedProperty<T>`
2. **Locator** (`lib/src/locator/`): `FairyLocator` (global DI), `FairyScope` (scoped DI), `Fairy` (resolver)
3. **UI** (`lib/src/ui/`): 
   - **Primary API (Recommended)**: `Bind<TViewModel, TValue>`, `Bind.viewModel<TViewModel>`, `Command<TViewModel>`, `Command.param<TViewModel, TParam>`
   - **Advanced API (Public)**: `BindViewModel<TViewModel>`, `BindViewModel2/3/4`

## Key Rules

- **Bind auto-detection**: Returns `ObservableProperty<T>` → two-way binding; Returns raw `T` → one-way binding
- **DI resolution order**: `FairyScope` (nearest) → `FairyLocator` (global) → exception
- **Disposal**: `FairyScope` only disposes VMs it created via `create` parameter (when `autoDispose: true`)
- **Auto-disposal**: Properties and commands created with `parent` parameter are auto-disposed when parent is disposed
- **Observable API**: Use `onPropertyChanged()` for notifications, `propertyChanged(listener)` returns disposer (MUST capture to avoid memory leaks)
- **Named parameters**: All command constructors use named parameters: `canExecute:`

## Critical Patterns

### ViewModels
- Use `final` fields with `ObservableProperty<T>(initialValue)` for auto-disposal
- Nested `ObservableObject` instances require manual disposal in `dispose()` override
- Call `command.notifyCanExecuteChanged()` when `canExecute` dependencies change
- Selectors MUST return stable property references (never create new instances)

### Commands
- `RelayCommand`: Sync actions with optional `canExecute` - use: `RelayCommand(() => action, canExecute: () => condition)`
- `AsyncRelayCommand`: Async actions - use: `AsyncRelayCommand(() async => action)`
- `RelayCommand.param<T>`: Parameterized commands (preferred) - use: `RelayCommand.param<T>((param) => action, canExecute: (param) => condition)`
- `AsyncRelayCommand.param<T>`: Async parameterized commands (preferred) - use: `AsyncRelayCommand.param<T>((param) async => action)`
- Call `notifyCanExecuteChanged()` to re-evaluate `canExecute` after dependency changes
- Use `canExecuteChanged(listener)` to subscribe to `canExecute` changes (returns disposer function, similar to `propertyChanged()`)

### UI Widgets (Recommended API)
- **Data binding**: Use `Bind<TViewModel, TValue>` with explicit selector, or `Bind.viewModel<TViewModel>` for auto-tracking
- **Command binding**: Use `Command<TViewModel>` for regular commands, or `Command.param<TViewModel, TParam>` for parameterized commands
- **Command.param signature**: `builder: (context, execute, canExecute, isRunning)` where `execute(TParam)` and `canExecute(TParam)` take parameters
- **Advanced**: `BindViewModel`, `BindViewModel2/3/4`, and `CommandWithParam` are public for power users but factories are preferred

### Memory Management
- **CRITICAL**: Always capture disposer from `propertyChanged()` and `canExecuteChanged()` calls to avoid memory leaks
- Use `Bind`/`Command` widgets for UI (handles lifecycle automatically)
- `FairyScope` auto-disposes VMs created via `create` parameter (when `autoDispose: true`)
- ChangeNotifier API is `@protected` in all types - do not call `addListener`/`removeListener` directly

## Common Pitfalls

1. **Memory leaks**: Not capturing `propertyChanged()` disposer → listener stays forever
2. **Unstable selectors**: Creating new `ObservableProperty` in selector → infinite rebuilds
3. **Missing refresh**: Not calling `notifyCanExecuteChanged()` when `canExecute` dependencies change
4. **Manual disposal of scoped VMs**: Let `FairyScope` handle disposal automatically
5. **Wrong constructor syntax**: Remember to use named parameters: `canExecute:`

## Testing

- Unit tests: Mirror `lib/src/` structure in `test/` directory
- Widget tests: Use `FairyScope` with test ViewModels
- Verify: Property changes trigger rebuilds, commands respect `canExecute`, VMs are disposed
