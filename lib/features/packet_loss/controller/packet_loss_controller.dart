import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../modals/benchmark_result.dart';
import '../../../modals/packet_record.dart';
import '../../../modals/udp_result.dart';
import '../../../theme/app_dimensions.dart';
import '../../dashboard/controller/benchmark_controller.dart';

class PacketLossSelection {
  final int run;
  final int page;
  const PacketLossSelection({this.run = 0, this.page = 0});
}

class PacketLossController extends StateNotifier<PacketLossSelection> {
  PacketLossController() : super(const PacketLossSelection());
  void run(int value) => state = PacketLossSelection(run: value);
  void page(int value) =>
      state = PacketLossSelection(run: state.run, page: value);
}

final packetLossControllerProvider =
    StateNotifierProvider.autoDispose<
      PacketLossController,
      PacketLossSelection
    >((ref) => PacketLossController());
final packetLossReportProvider = Provider.autoDispose(
  (ref) => PacketLossReport.from(
    ref.watch(benchmarkControllerProvider).result,
    ref.watch(packetLossControllerProvider),
  ),
);

class DeliveryCell {
  final int sequence;
  final PacketStatus? status;
  const DeliveryCell(this.sequence, this.status);
  String get label => switch (status) {
    PacketStatus.delivered => 'Delivered',
    PacketStatus.droppedBySimulation => 'Dropped by application simulation',
    PacketStatus.missing => 'Missing at audit deadline',
    PacketStatus.timedOut => 'Timed out',
    PacketStatus.duplicate => 'Duplicate',
    null => 'No recorded packet evidence',
  };
}

class PacketLossReport {
  final List<int> runs;
  final UdpResult? run;
  final double configuredLoss;
  final double observedLoss;
  final int page;
  final int pages;
  final List<DeliveryCell> cells;
  const PacketLossReport({
    required this.runs,
    this.run,
    required this.configuredLoss,
    required this.observedLoss,
    required this.page,
    required this.pages,
    required this.cells,
  });

  factory PacketLossReport.from(
    BenchmarkResult? result,
    PacketLossSelection selection,
  ) {
    final runs = result?.udpRuns ?? const <UdpResult>[];
    final run =
        runs.where((r) => r.runIndex == selection.run).firstOrNull ??
        runs.firstOrNull;
    final count = run?.packetsSent ?? 0;
    final pages = (count / AppDimensions.deliveryPageSize).ceil();
    final page = pages == 0 ? 0 : selection.page.clamp(0, pages - 1);
    final records = <int, PacketStatus>{
      for (final record in run?.packetRecords ?? <PacketRecord>[])
        record.sequence: record.status,
    };
    final start = page * AppDimensions.deliveryPageSize;
    return PacketLossReport(
      runs: List.unmodifiable(runs.map((r) => r.runIndex)),
      run: run,
      configuredLoss: result?.config.simulation.lossPercent ?? 0,
      observedLoss: count == 0 ? 0 : 100 * run!.lostPackets / count,
      page: page,
      pages: pages,
      cells: List<DeliveryCell>.unmodifiable([
        for (
          var i = start;
          i < count && i < start + AppDimensions.deliveryPageSize;
          i++
        )
          DeliveryCell(i, records[i]),
      ]),
    );
  }
}
