# NetScope Studio — TCP & UDP Network Performance Lab

NetScope Studio is a desktop application (macOS & Windows) built with Flutter and Dart for educational networking experimentation, protocol benchmarking, and performance analysis.

It benchmarks real TCP (`ServerSocket` / `Socket`) and UDP (`RawDatagramSocket`) network traffic directly over loopback (`127.0.0.1`), measuring throughput, round-trip time (RTT), latency variation (jitter), and packet delivery under configurable network conditions.

---

## Features

- **Real Socket Benchmarking**: Runs actual TCP and UDP clients and servers inside the app over loopback (`127.0.0.1`).
- **Configurable Network Impairment**:
  - Simulated UDP packet drop policies.
  - Latency & jitter delay simulation on echo paths.
  - Send-rate pacing for custom bandwidth limits.
- **Accurate Metric Derivation**:
  - Throughput (Mbps) derived exclusively from received payload bytes.
  - Min, Average, Max, Median, and p95 RTT metrics.
  - Mean absolute RTT variation (jitter).
  - Delivery and loss percentage calculation.
- **Interactive Benchmark Cockpit**:
  - Presets: Quick, Standard, High-Throughput, Latency & Jitter, UDP Loss, and Custom.
  - Live metric cards and progress indicators.
  - Safe cancellation with resource cleanup.
- **Persistent Experiments**:
  - SQLite local database via `sqflite_common_ffi`.
  - Atomic transactions for experiment runs and raw RTT samples.
- **Multi-Experiment Comparison (Phase 7)**:
  - Interactive multi-run comparison with `fl_chart`.
  - Side-by-side TCP vs. UDP throughput, RTT, jitter, and delivery comparisons.
  - Automated insights derived from measured data.
- **CSV Data Export**:
  - Export full test data and raw samples for external analysis.

---

## Architecture

Built using a feature-first architecture:

```
lib/
  apis/
  common/
  constants/
  core/
    enums/
    extensions/
    utility/
  features/
    dashboard/
    comparison/
  modals/
  routes/
  services/
    networking/
    benchmark/
    simulation/
    database/
  theme/
  widgets/
  main.dart
```

- **State Management**: `flutter_riverpod` (StateNotifier API).
- **Error Handling**: Functional programming via `fpdart` (`FutureEither<T>`).
- **Charts**: `fl_chart`.
- **Typography & Theme**: Google Fonts (Manrope) with custom dark theme palette.

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.13` or newer
- Dart SDK `^3.10` or newer
- Desktop development prerequisites:
  - **macOS**: Xcode with Command Line Tools
  - **Windows**: Visual Studio 2022 (with Desktop development with C++)

### Installation & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/bhumikkataria/NetScope-Studio.git
   cd NetScope-Studio
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run unit and integration tests:
   ```bash
   flutter test
   ```

4. Launch the application:
   ```bash
   flutter run -d macos    # macOS
   flutter run -d windows  # Windows
   ```

---

## Loopback Measurement Notes

- Measurements are conducted over `127.0.0.1`. Absolute throughput numbers depend on host CPU scheduling and OS socket buffer management.
- Application-level simulated UDP loss models application drop behavior and does not represent hardware transmission loss or TCP congestion control retransmission.
- Rate limits represent application send-rate pacing caps, not physical network adapter bandwidth.

---

## License

This project is licensed for educational and laboratory use. Fonts are licensed under the SIL Open Font License (OFL).
