import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/networking/udp_audit.dart';
import '../../../lib/services/networking/udp_control_channel.dart';
import '../../../lib/services/networking/udp_drop_policy.dart';

void main() {
  test(
    'seeded drops reproduce across instances, ordering and duplicate calls',
    () {
      const first = UdpDropPolicy(probability: 0.35, seed: 987);
      const second = UdpDropPolicy(probability: 0.35, seed: 987);
      const different = UdpDropPolicy(probability: 0.35, seed: 988);
      final decisions = List.generate(500, first.shouldDrop);
      expect(List.generate(500, second.shouldDrop), decisions);
      expect(List.generate(500, different.shouldDrop), isNot(decisions));
      for (var sequence = 499; sequence >= 0; sequence--) {
        expect(second.shouldDrop(sequence), decisions[sequence]);
        expect(second.shouldDrop(sequence), decisions[sequence]);
      }
      expect(decisions, containsAll(<bool>[true, false]));
      expect(
        const UdpDropPolicy(probability: 0, seed: 1).shouldDrop(0),
        isFalse,
      );
      expect(
        const UdpDropPolicy(probability: 1, seed: 1).shouldDrop(0),
        isTrue,
      );
    },
  );

  test('audit bitmaps round trip, preserve immutability and reject inconsistencies', () {
    final audit = UdpAudit(
      experimentId: 7,
      packetCount: 10,
      datagramSize: 1024,
      receivedSequences: <int>{0, 2, 9},
      droppedSequences: <int>{1},
      duplicateSequences: <int>{2},
      outOfOrderSequences: <int>{0},
      duplicates: 2,
      simulationDropCount: 1,
      bytesReceived: 3 * (1024 - 36),
      rejectedDatagrams: 1,
      seed: 123,
      lossPercent: 25,
      collectionWindowMs: 10,
    );
    final decoded = UdpAudit.fromMap(audit.toMap())
        .fold((failure) => throw TestFailure('$failure'), (audit) => audit);
    expect(decoded.receivedSequences, audit.receivedSequences);
    expect(decoded.droppedSequences, audit.droppedSequences);
    expect(decoded.duplicateSequences, audit.duplicateSequences);
    expect(decoded.outOfOrderSequences, audit.outOfOrderSequences);
    expect(() => decoded.receivedSequences.add(3), throwsUnsupportedError);
    for (final mutation in <Map<String, Object?>>[
      <String, Object?>{'bytesReceived': 1},
      <String, Object?>{'received': 'bad base64!'},
      <String, Object?>{'received': 'AA=='},
      <String, Object?>{'received': 'AAA='}, // conflicts with bytes/duplicates
      <String, Object?>{'received': 'AP8='}, // nonzero padding bits
      <String, Object?>{'duplicates': 0},
      <String, Object?>{'simulationDropCount': 0},
      <String, Object?>{'packetCount': 100001},
      <String, Object?>{'datagramSize': 1401},
      <String, Object?>{'lossPercent': double.nan},
      <String, Object?>{'experimentId': 0},
    ]) {
      expect(
        UdpAudit.fromMap(<String, Object?>{...audit.toMap(), ...mutation})
            .isLeft(),
        isTrue,
      );
    }
  });

  test('largest permitted audit is split into bounded TCP response frames', () {
    final audit = UdpAudit(
      experimentId: 1,
      packetCount: 100000,
      datagramSize: 1024,
      receivedSequences: <int>{0, 99999},
      droppedSequences: <int>{2},
      duplicateSequences: <int>{0},
      outOfOrderSequences: <int>{0},
      duplicates: 1,
      simulationDropCount: 1,
      bytesReceived: 2 * (1024 - 36),
      rejectedDatagrams: 0,
      seed: 0,
      lossPercent: 25,
      collectionWindowMs: 100,
    );
    final frames = UdpControlCodec.response(1, <String, Object?>{
      'ok': true,
      ...audit.toMap(),
    }).fold((failure) => throw TestFailure('$failure'), (frames) => frames);
    expect(frames.length, greaterThan(2));
    expect(frames.every((packet) => packet.payload.length <= 65536), isTrue);
    expect(
      UdpControlCodec.decode(
        // The transport reassembles these exact payload bytes before decoding.
        (BytesBuilder()
              ..add(frames[0].payload)
              ..add(frames[1].payload))
            .toBytes(),
      ).isRight(),
      isTrue,
    );
  });
}
