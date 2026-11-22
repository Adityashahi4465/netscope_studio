# NetScope Studio — TCP & UDP Network Performance Lab

A Flutter/Dart desktop lab for real TCP and UDP experiments over `127.0.0.1`.
The application owns both clients and servers. Measurements are never generated
from illustrative data. All experiment storage is local SQLite; no cloud, web
runtime, external database, Python, or Node is required.

## Setup and run

Use Flutter **3.47.7 or newer with Dart 3.13.5 or newer** (the current SDK
constraint is `^3.13.5`). The project pins its package versions in `pubspec.yaml`
and commits `pubspec.lock`. Manrope font assets are bundled for offline use.

- macOS: install Xcode and its command-line tools; select the full Xcode developer
  directory and complete its first-launch setup. CocoaPods is required for the
  desktop plugins when requested by Flutter.
- Windows: install Visual Studio with the Desktop development with C++ workload
  and a supported Windows SDK. Keep Windows desktop support enabled in Flutter.

```sh
flutter doctor -v
flutter pub get
flutter run -d macos
# On a Windows development host:
flutter run -d windows
```

## Screens and workflow

1. **Benchmark cockpit**: choose Quick, Standard, High-Throughput, Latency &
   Jitter, UDP Packet Loss, or Custom; configure, Start, Cancel, Reset, Save,
   or Export. Validation appears alongside the form. Settings contains local
   ports, operation timeout, and optional simulation seed.
2. **TCP vs UDP**: select saved experiments to compare received throughput,
   RTT, mean absolute RTT variation, delivery, repetitions, and simulated
   conditions. Insights use recorded values and include loopback caveats.
3. **Latency analysis**: load a focused setup and Start, or analyze the current
   measured result. Choose transport and repetition; inspect successful-probe
   RTTs, an equal-width histogram, min/average/max/median/p95, mean absolute RTT
   variation, and probe timeouts. Missing RTT samples are shown as unavailable.
4. **Packet loss**: load a focused UDP loss setup and Start. Compare configured
   simulated discard probability with observed request loss. Inspect sent,
   accepted, simulated drops, unexplained missing, duplicate and out-of-order
   arrivals, and RTT echo timeouts. The delivery map pages 256 sequence numbers
   at a time and reads packet statuses from the reliable TCP audit.
5. **Experiment history**: search saved names, IDs, dates, and conditions; filter
   by included transport and simulation preset. Open details, export CSV, delete
   individual experiments, clear history with confirmation, or send selections
   directly to Comparison. Hidden selections remain selected until removed.
6. **Protocol visualizer**: play, pause, scrub, restart, and change playback
   speed. TCP illustrates a three-way handshake, data/ACK, and both FIN
   directions. UDP illustrates independent messages and an application discard.
   Illustrations are explicitly labeled and never populate measured results.
   Toggle recorded UDP replay from the current run, or open a saved log from
   history. Replay preserves recorded statuses and send timestamps; its motion
   remains illustrative. Long logs are paged at 256 records.

A benchmark can remain active while navigating; all analysis views share the
cockpit controller. Save a result to retain it across application restarts.

## macOS sandbox entitlements

Both `macos/Runner/DebugProfile.entitlements` and
`macos/Runner/Release.entitlements` include:

- `com.apple.security.app-sandbox`: the application stays sandboxed.
- `com.apple.security.network.server`: bind in-app TCP and UDP loopback servers.
- `com.apple.security.network.client`: connect clients and send datagrams.
- `com.apple.security.files.user-selected.read-write`: export CSV into a directory
  explicitly chosen with the native directory chooser.

Debug/profile also enables `com.apple.security.cs.allow-jit` for Flutter.
SQLite is stored in the application's support directory obtained through
`path_provider`. CSV export uses a native user-chosen directory and writes an
atomic temporary file before renaming. Windows does not use these entitlements.
A native firewall prompt may require allowing the executable's local networking.

## Verification

```sh
flutter analyze
flutter test
# Native desktop end-to-end: configure Quick, run real sockets, save, compare,
# then inspect latency, packet loss and recorded replay. Uses a temporary DB.
flutter test integration_test/full_flow_test.dart -d macos
# Run this command on Windows to verify that target:
flutter test integration_test/full_flow_test.dart -d windows
flutter build macos --debug
```

For optional local PNGs of analysis screens using actual loopback results:

```sh
flutter test test/features/analysis/analysis_views_test.dart --dart-define=NETSCOPE_SCREENSHOTS=true
```

Images are written to the ignored `build/screenshots/` directory. Unit-test
fixtures are confined to `test/`; benchmarks and integration tests use real
sockets. Integration tests choose available loopback ports and isolate storage.

## Architecture

Feature-first `lib/features/<feature>/{controller,view,widgets}` separates
StateNotifier controllers from thin Riverpod views. Immutable models remain
in `lib/modals/`. Sockets are confined to `services/networking`; orchestration,
pure metrics, simulation, SQLite, repository operations and export are separate
services. Fallible service operations return `FutureEither` and controllers
handle failures using `fold`. All navigation uses `RouteUtils`.

The UDP server is registered as `TcpServer(controlHandler: udpServer)` so the
same TCP listener handles benchmarks and reliable UDP audit transactions.
Audits include accepted/dropped sequence bitmaps, duplicates, arrival ordering,
and received payload bytes; large audits use multiple bounded TCP frames.

## Measurement limitations and known issues

- Loopback results depend on CPU, hardware, OS scheduling, socket buffers and
  application framing; they are not measurements of a physical network link.
- Application-level simulated loss is **not comparable to TCP loss recovery**.
  UDP simulation discards requests after they reach the server application.
  Configured probability and observed discard percentage can differ.
- Delay and jitter apply to server RTT echo responses. They do not emulate a
  physical link or inject delays into bulk delivery. Rate limiting is an
  **application send-rate cap**, not physical bandwidth.
- Throughput/goodput use received application payload bytes. UDP datagram size
  includes the 36-byte application header; its goodput excludes that header.
  The UDP bulk duration includes its bounded final collection window and TCP
  control exchange. It is not directly the same timing boundary as TCP bulk.
- UDP echo timeouts are separate from bulk request loss. A lost echo never
  becomes evidence that a bulk request was lost. The audit freezes after its
  collection deadline; a request arriving later remains missing in that run.
- RTT logs contain successful samples, without the original indices of timed-out
  probes. The latency line uses successful-sample index and cannot place gaps.
- Replay has no packet-capture data, arrival timestamps, TCP segment traces,
  retransmission traces, or congestion-control observations. Missing UDP
  requests have unknown locations. Replaying outcomes does not reconstruct
  actual packet motion or arrival order. Older records without packet logs
  remain unavailable for replay; missing evidence is not invented.
- Windows source compatibility is maintained, but native Windows execution
  must be verified on a Windows host using the commands above.

Manrope is bundled under the SIL Open Font License in `assets/fonts/OFL.txt`.
