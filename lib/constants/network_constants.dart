class NetworkConstants {
  NetworkConstants._();

  static const String defaultHost = '127.0.0.1';
  static const int defaultTcpPort = 45010;
  static const int defaultUdpPort = 45011;
  static const int minPort = 1024;
  static const int maxPort = 65535;

  // UDP
  static const int defaultUdpDatagramSize = 1024;
  static const int minUdpDatagramSize = 64;
  static const int maxUdpDatagramSize = 1400; // stays under typical MTU

  // Workload limits
  static const int minPacketCount = 10;
  static const int maxPacketCount = 100000;
  static const int minRepetitions = 1;
  static const int maxRepetitions = 20;
  static const int minRttProbes = 1;
  static const int maxRttProbes = 1000;
  static const int minTcpPayloadBytes = 1024;
  static const int maxTcpPayloadBytes = 256 * 1024 * 1024;

  // Timeouts
  static const int defaultTimeoutMs = 2000;
  static const int minTimeoutMs = 100;
  static const int maxTimeoutMs = 30000;

  // Simulation limits
  static const double maxLossPercent = 90;
  static const int maxDelayMs = 2000;
  static const int maxJitterMs = 1000;
  static const double maxRateLimitMbps = 10000;

  // TCP
  static const int tcpChunkSize = 16 * 1024;
}
