class VoleoClock {
  // Simulation: Samstag, 13. Juni 2026, 22:00 Uhr (Mitte des 5. Spiels)
  static final DateTime _simulatedNow = DateTime(2026, 6, 28, 22, 0, 0);

  // Auf true setzen, wenn ENVIRONMENT=test übergeben wurde
  static const bool useSimulation = String.fromEnvironment('ENVIRONMENT', defaultValue: 'prod') == 'test';

  static DateTime get now {
    if (useSimulation) {
      return _simulatedNow;
    }
    return DateTime.now();
  }
}
