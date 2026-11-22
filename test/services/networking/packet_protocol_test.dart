import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../lib/core/failure.dart';
import '../../../lib/services/networking/frame_buffer.dart';
import '../../../lib/services/networking/packet_protocol.dart';

T value<T>(Either<Failure, T> result) => result.fold(
  (failure) => throw TestFailure(failure.toString()),
  (value) => value,
);

void main() {
  const protocol = PacketProtocol();
  final packet = Packet(
    type: MessageType.dataChunk,
    experimentId: 0x12345678,
    sequence: 19,
    total: 0x100000001,
    timestampUs: 0x100000002,
    payload: <int>[0, 127, 255],
  );

  test('header and payload round trip in network byte order', () {
    final bytes = value(protocol.encode(packet));
    expect(bytes.sublist(0, 6), <int>[0x4e, 0x53, 0x43, 0x50, 1, 4]);
    expect(bytes.sublist(8, 12), <int>[0x12, 0x34, 0x56, 0x78]);
    final decoded = value(protocol.decode(bytes));
    expect(decoded.type, packet.type);
    expect(decoded.experimentId, packet.experimentId);
    expect(decoded.sequence, packet.sequence);
    expect(decoded.total, packet.total);
    expect(decoded.timestampUs, packet.timestampUs);
    expect(decoded.flags, 0);
    expect(decoded.payload, packet.payload);
    expect(() => decoded.payload[0] = 2, throwsUnsupportedError);
  });

  test('all message types round trip', () {
    for (final type in MessageType.values) {
      final bytes = value(
        protocol.encode(
          Packet(
            type: type,
            experimentId: 1,
            payload: type == MessageType.dataChunk ? <int>[42] : <int>[],
          ),
        ),
      );
      expect(value(protocol.decode(bytes)).type, type);
    }
  });

  test(
    'malformed header fields, truncation and trailing bytes are rejected',
    () {
      final valid = value(protocol.encode(packet));
      for (final offset in <int>[0, 4, 5, 6, 16, 28]) {
        final bytes = Uint8List.fromList(valid);
        bytes[offset] = 255;
        expect(
          protocol.decode(bytes).isLeft(),
          isTrue,
          reason: 'offset $offset',
        );
      }
      final noId = Uint8List.fromList(valid);
      ByteData.sublistView(noId).setUint32(8, 0);
      expect(protocol.decode(noId).isLeft(), isTrue);
      final oversized = Uint8List.fromList(valid);
      ByteData.sublistView(oversized)
          .setUint32(24, PacketProtocol.maxPayloadLength + 1);
      expect(protocol.decode(oversized).isLeft(), isTrue);
      for (var length = 0; length < valid.length; length++) {
        expect(
          protocol.decode(Uint8List.sublistView(valid, 0, length)).isLeft(),
          isTrue,
        );
      }
      expect(
        protocol.decode(Uint8List.fromList(<int>[...valid, 0])).isLeft(),
        isTrue,
      );
      expect(protocol.decodeHeader(valid).isLeft(), isTrue);
    },
  );

  test(
    'encode rejects overflow, reserved flags and invalid message payloads',
    () {
      for (final invalid in <Packet>[
        Packet(type: MessageType.ack, experimentId: 0),
        Packet(type: MessageType.ack, experimentId: 0x100000000),
        Packet(type: MessageType.ack, experimentId: 1, sequence: -1),
        Packet(type: MessageType.ack, experimentId: 1, sequence: 0x100000000),
        Packet(type: MessageType.ack, experimentId: 1, total: -1),
        Packet(type: MessageType.ack, experimentId: 1, timestampUs: -1),
        Packet(type: MessageType.ack, experimentId: 1, flags: 1),
        Packet(type: MessageType.ack, experimentId: 1, payload: <int>[1]),
        Packet(type: MessageType.dataChunk, experimentId: 1),
        Packet(
          type: MessageType.dataChunk,
          experimentId: 1,
          payload: Uint8List(PacketProtocol.maxPayloadLength + 1),
        ),
      ]) {
        expect(protocol.encode(invalid).isLeft(), isTrue);
      }
    },
  );

  test('FrameBuffer handles every two-way split and byte-by-byte input', () {
    final bytes = value(protocol.encode(packet));
    for (var split = 0; split <= bytes.length; split++) {
      final buffer = FrameBuffer();
      final frames = <Packet>[
        ...value(buffer.add(Uint8List.sublistView(bytes, 0, split))),
        ...value(buffer.add(Uint8List.sublistView(bytes, split))),
      ];
      expect(frames, hasLength(1));
      expect(frames.single.payload, packet.payload);
      expect(buffer.pendingBytes, 0);
      expect(buffer.finish().isRight(), isTrue);
    }
    final buffer = FrameBuffer();
    final frames = <Packet>[];
    for (final byte in bytes) {
      frames.addAll(value(buffer.add(Uint8List.fromList(<int>[byte]))));
    }
    expect(frames, hasLength(1));
  });

  test('FrameBuffer handles coalesced frames and a partial final frame', () {
    final bytes = value(protocol.encode(packet));
    final buffer = FrameBuffer();
    final frames = value(
      buffer.add(
        Uint8List.fromList(<int>[...bytes, ...bytes, ...bytes.sublist(0, 17)]),
      ),
    );
    expect(frames, hasLength(2));
    expect(buffer.pendingBytes, 17);
    expect(value(buffer.add(Uint8List.sublistView(bytes, 17))), hasLength(1));
    expect(value(buffer.add(Uint8List(0))), isEmpty);
    expect(buffer.finish().isRight(), isTrue);
  });

  test(
    'FrameBuffer rejects malformed headers immediately and incomplete EOF',
    () {
      final buffer = FrameBuffer();
      final header = Uint8List(PacketProtocol.headerSize);
      expect(buffer.add(header).isLeft(), isTrue);
      expect(buffer.add(Uint8List(0)).isLeft(), isTrue);
      expect(buffer.finish().isLeft(), isTrue);
      final incomplete = FrameBuffer();
      value(incomplete.add(Uint8List.fromList(<int>[1, 2])));
      expect(incomplete.finish().isLeft(), isTrue);
    },
  );
}
