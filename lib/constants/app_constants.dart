class AppConstants {
  AppConstants._();

  static const String appName = 'NetScope Studio';
  static const String appSubtitle = 'TCP & UDP Network Performance Lab';
  static const String databaseName = 'netscope_studio.db';
  static const int databaseVersion = 1;
  static const String loopbackDisclaimer =
      'Loopback results depend on host hardware, OS scheduling, buffering '
      'and implementation. They do not represent real network behavior.';
  static const String simulationDisclaimer =
      'Impairments are applied at the application layer and are not '
      'equivalent to real network or kernel-level conditions.';
}
