import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../constants/network_constants.dart';
import '../../core/failure.dart';
import 'network_failure.dart';
import 'packet_protocol.dart';

/// Immutable receiver evidence frozen at an explicit collection deadline.
/// Bytes count unique accepted application payload, excluding protocol headers.
/// Drop count is the number of discarded arrivals; droppedSequences counts
/// unique discarded requests, which is the value used by UdpResult.
class UdpAudit {
  final int experimentId;
  final int packetCount;
  final int datagramSize;
  final Set<int> receivedSequences;
  final Set<int> droppedSequences;
  final Set<int> duplicateSequences;
  final Set<int> outOfOrderSequences;
  final int duplicates;
  final int simulationDropCount;
  final int bytesReceived;
  final int rejectedDatagrams;
  final int seed;
  final double lossPercent;
  final int collectionWindowMs;

  UdpAudit({
    required this.experimentId,
    required this.packetCount,
    required this.datagramSize,
    required Set<int> receivedSequences,
    required Set<int> droppedSequences,
    required Set<int> duplicateSequences,
    required Set<int> outOfOrderSequences,
    required this.duplicates,
    required this.simulationDropCount,
    required this.bytesReceived,
    required this.rejectedDatagrams,
    required this.seed,
    required this.lossPercent,
    required this.collectionWindowMs,
  }) : receivedSequences = Set<int>.unmodifiable(receivedSequences),
       droppedSequences = Set<int>.unmodifiable(droppedSequences),
       duplicateSequences = Set<int>.unmodifiable(duplicateSequences),
       outOfOrderSequences = Set<int>.unmodifiable(outOfOrderSequences);

  /// Valid bulk arrivals before the simulated application discard decision.
  int get validDatagramArrivals =>
      receivedSequences.length + duplicates + simulationDropCount;

  Map<String, Object?> toMap() => <String, Object?>{
    'experimentId': experimentId,
    'packetCount': packetCount,
    'datagramSize': datagramSize,
    'received': _bitmap(receivedSequences),
    'dropped': _bitmap(droppedSequences),
    'duplicateSequences': _bitmap(duplicateSequences),
    'outOfOrderSequences': _bitmap(outOfOrderSequences),
    'duplicates': duplicates,
    'simulationDropCount': simulationDropCount,
    'bytesReceived': bytesReceived,
    'rejectedDatagrams': rejectedDatagrams,
    'seed': seed,
    'lossPercent': lossPercent,
    'collectionWindowMs': collectionWindowMs,
  };

  String _bitmap(Set<int> sequences) {
    final bits = Uint8List((packetCount + 7) ~/ 8);
    for (final sequence in sequences) {
      bits[sequence ~/ 8] |= 1 << (sequence % 8);
    }
    return base64Encode(bits);
  }

  static Either<Failure, UdpAudit> fromMap(Map<String, Object?> map) {
    try {
      int integer(String key, {int maximum = PacketProtocol.maxCounter}) {
        final value = map[key];
        if (value is! int || value < 0 || value > maximum) {
          throw FormatException('Invalid audit $key.');
        }
        return value;
      }

      final count = integer(
        'packetCount',
        maximum: NetworkConstants.maxPacketCount,
      );
      final size = integer(
        'datagramSize',
        maximum: NetworkConstants.maxUdpDatagramSize,
      );
      if (count == 0 || size < NetworkConstants.minUdpDatagramSize) {
        throw const FormatException('Invalid audit workload.');
      }
      Set<int> sequences(String key) {
        final encoded = map[key];
        if (encoded is! String) throw FormatException('Missing bitmap $key.');
        final bits = base64Decode(encoded);
        if (bits.length != (count + 7) ~/ 8 ||
            (count % 8 != 0 && bits.last >> (count % 8) != 0)) {
          throw FormatException('Invalid bitmap $key.');
        }
        return <int>{
          for (var i = 0; i < count; i++)
            if ((bits[i ~/ 8] & (1 << (i % 8))) != 0) i,
        };
      }

      final received = sequences('received');
      final dropped = sequences('dropped');
      final duplicateSet = sequences('duplicateSequences');
      final reordered = sequences('outOfOrderSequences');
      final bytes = integer('bytesReceived');
      final duplicates = integer('duplicates');
      final drops = integer('simulationDropCount');
      final loss = map['lossPercent'];
      final experiment = integer(
        'experimentId',
        maximum: PacketProtocol.maxUnsigned32,
      );
      if (experiment == 0 ||
          received.intersection(dropped).isNotEmpty ||
          !received.containsAll(duplicateSet) ||
          !received.containsAll(reordered) ||
          duplicates < duplicateSet.length ||
          drops < dropped.length ||
          bytes != received.length * (size - PacketProtocol.headerSize) ||
          loss is! num ||
          !loss.isFinite ||
          loss < 0 ||
          loss > 100) {
        throw const FormatException('Inconsistent UDP audit.');
      }
      return right(
        UdpAudit(
          experimentId: experiment,
          packetCount: count,
          datagramSize: size,
          receivedSequences: received,
          droppedSequences: dropped,
          duplicateSequences: duplicateSet,
          outOfOrderSequences: reordered,
          duplicates: duplicates,
          simulationDropCount: drops,
          bytesReceived: bytes,
          rejectedDatagrams: integer('rejectedDatagrams'),
          seed: integer('seed', maximum: PacketProtocol.maxUnsigned32),
          lossPercent: loss.toDouble(),
          collectionWindowMs: integer('collectionWindowMs', maximum: 1000),
        ),
      );
    } on Object catch (error) {
      return left(
        NetworkFailure(
          NetworkFailureCode.malformedPacket,
          'Malformed UDP audit.',
          cause: error,
        ),
      );
    }
  }
}
