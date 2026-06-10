class VoleoClock {
  static final DateTime _simulatedNow = DateTime(2026, 7, 15, 12, 0, 0);

  // Simulation aktiv wenn FLUTTER_ENV=test oder ENVIRONMENT=test übergeben wurde
  static const bool useSimulation =
      String.fromEnvironment('FLUTTER_ENV', defaultValue: 'prod') == 'test' ||
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'prod') == 'test';

  static DateTime get now {
    if (useSimulation) {
      return _simulatedNow;
    }
    return DateTime.now();
  }
}
