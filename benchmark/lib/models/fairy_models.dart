import 'package:fairy/fairy.dart';

/// Counter ViewModel for basic performance testing
class FairyCounterViewModel extends ObservableObject {
  late final ObservableProperty<int> counter;
  late final RelayCommand incrementCommand;

  FairyCounterViewModel() {
    counter = ObservableProperty(0);
    incrementCommand = RelayCommand(() {
      counter.value++;
    });
  }
}

/// Multi-property ViewModel for selective rebuild testing
class FairyMultiPropertyViewModel extends ObservableObject {
  late final ObservableProperty<int> property1;
  late final ObservableProperty<int> property2;
  late final ObservableProperty<int> property3;

  FairyMultiPropertyViewModel() {
    property1 = ObservableProperty(0);
    property2 = ObservableProperty(0);
    property3 = ObservableProperty(0);
  }

  /// Helper for ONE-WAY binding: triggers global notifications
  void notifyGlobal() => onPropertyChanged();
}

/// Second ViewModel for multi-ViewModel testing (must be different type)
class FairyMultiPropertyViewModel2 extends ObservableObject {
  late final ObservableProperty<int> property1;
  late final ObservableProperty<int> property2;
  late final ObservableProperty<int> property3;

  FairyMultiPropertyViewModel2() {
    property1 = ObservableProperty(0);
    property2 = ObservableProperty(0);
    property3 = ObservableProperty(0);
  }
}

/// Third ViewModel for multi-ViewModel testing (must be different type)
class FairyMultiPropertyViewModel3 extends ObservableObject {
  late final ObservableProperty<int> property1;
  late final ObservableProperty<int> property2;
  late final ObservableProperty<int> property3;

  FairyMultiPropertyViewModel3() {
    property1 = ObservableProperty(0);
    property2 = ObservableProperty(0);
    property3 = ObservableProperty(0);
  }
}
