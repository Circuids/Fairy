import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counter StateNotifier for basic performance testing
class RiverpodCounterNotifier extends StateNotifier<int> {
  RiverpodCounterNotifier() : super(0);

  void increment() {
    state = state + 1;
  }
}

final riverpodCounterProvider =
    StateNotifierProvider<RiverpodCounterNotifier, int>(
      (ref) => RiverpodCounterNotifier(),
    );

/// Multi-property StateNotifier for selective rebuild testing
class RiverpodMultiPropertyNotifier extends StateNotifier<Map<String, int>> {
  RiverpodMultiPropertyNotifier() : super({'p1': 0, 'p2': 0, 'p3': 0});

  void updateProperty1() {
    state = {...state, 'p1': state['p1']! + 1};
  }

  void updateProperty2() {
    state = {...state, 'p2': state['p2']! + 1};
  }

  void updateProperty3() {
    state = {...state, 'p3': state['p3']! + 1};
  }
}

final riverpodMultiProvider =
    StateNotifierProvider<RiverpodMultiPropertyNotifier, Map<String, int>>(
      (ref) => RiverpodMultiPropertyNotifier(),
    );
