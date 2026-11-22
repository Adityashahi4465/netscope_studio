import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import 'network_failure.dart';

enum MessageType {
  handshake,
  rttProbe,
  rttEcho,
  dataChunk,
  ack,
  summary,
  close,
}

/// Immutable application frame. Timestamps are sender Stopwatch microseconds;
/// receivers must echo them, never subtract clocks from different endpoints.
class Packet {
  final MessageType type;
  final int experimentId;
  final int sequence;
  final int total;
  final int timestampUs;
  final int flags;
  final Uint8List payload;

  Packet({
    required this.type,
    required this.experimentId,
    this.sequence = 0,
    this.total = 0,
    this.timestampUs = 0,
    this.flags = 0,
    List<int> payload = const <int>[],
  }) : payload = Uint8List.fromList(payload).asUnmodifiableView();
}

class PacketHeader {
  final MessageType type;
  final int experimentId;
  final int sequence;
  final int total;
  final int payloadLength;
  final int timestampUs;
  final int flags;

  const PacketHeader({
    required this.type,
    required this.experimentId,
    required this.sequence,
    required this.total,
    required this.payloadLength,
    required this.timestampUs,
    required this.flags,
  });
}

/// Big-endian v1 wire layout (offset: field):
/// 0:u32 magic, 4:u8 version, 5:u8 type (1..7), 6:u16 flags,
/// 8:u32 experiment, 12:u32 sequence, 16:u64 total, 24:u32 payload
/// length, 28:u64 timestamp. Total means expected/acknowledged payload bytes
/// for TCP; it can represent total packet count for a future UDP transport.
class PacketProtocol {
  const PacketProtocol();

  static const int magic = 0x4e534350;
  static const int version = 1;
  static const int headerSize = 36;
  static const int maxPayloadLength = 64 * 1024;
  static const int maxUnsigned32 = 0xffffffff;
  // Dart native ints are signed; v1 deliberately limits u64 fields to 63 bits.
  static const int maxCounter = 0x7fffffffffffffff;

  Either<Failure, Uint8List> encode(Packet packet) {
    final header = PacketHeader(
      type: packet.type,
      experimentId: packet.experimentId,
      sequence: packet.sequence,
      total: packet.total,
      payloadLength: packet.payload.length,
      timestampUs: packet.timestampUs,
      flags: packet.flags,
    );
    final failure = _validate(header);
    if (failure != null) return left(failure);
    final bytes = Uint8List(headerSize + packet.payload.length);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, magic);
    data.setUint8(4, version);
    data.setUint8(5, packet.type.index + 1);
    data.setUint16(6, packet.flags);
    data.setUint32(8, packet.experimentId);
    data.setUint32(12, packet.sequence);
    data.setUint64(16, packet.total);
    data.setUint32(24, packet.payload.length);
    data.setUint64(28, packet.timestampUs);
    bytes.setRange(headerSize, bytes.length, packet.payload);
    return right(bytes);
  }

  Either<Failure, PacketHeader> decodeHeader(Uint8List bytes) {
    if (bytes.length != headerSize) return left(_malformed('Header size.'));
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(0) != magic || data.getUint8(4) != version) {
      return left(_malformed('Unsupported magic or protocol version.'));
    }
    final type = data.getUint8(5);
    if (type < 1 || type > MessageType.values.length) {
      return left(_malformed('Unknown message type.'));
    }
    final header = PacketHeader(
      type: MessageType.values[type - 1],
      flags: data.getUint16(6),
      experimentId: data.getUint32(8),
      sequence: data.getUint32(12),
      total: data.getUint64(16),
      payloadLength: data.getUint32(24),
      timestampUs: data.getUint64(28),
    );
    final failure = _validate(header);
    return failure == null ? right(header) : left(failure);
  }

  Either<Failure, Packet> decode(Uint8List bytes) {
    if (bytes.length < headerSize) return left(_malformed('Truncated header.'));
    return decodeHeader(Uint8List.sublistView(bytes, 0, headerSize))
        .fold(left, (header) {
          if (bytes.length != headerSize + header.payloadLength) {
            return left(_malformed('Frame length does not match header.'));
          }
          return right(
            Packet(
              type: header.type,
              experimentId: header.experimentId,
              sequence: header.sequence,
              total: header.total,
              timestampUs: header.timestampUs,
              flags: header.flags,
              payload: Uint8List.sublistView(bytes, headerSize),
            ),
          );
        });
  }

  Failure? _validate(PacketHeader header) {
    if (header.experimentId <= 0 ||
        header.experimentId > maxUnsigned32 ||
        header.sequence < 0 ||
        header.sequence > maxUnsigned32 ||
        header.total < 0 ||
        header.total > maxCounter ||
        header.timestampUs < 0 ||
        header.timestampUs > maxCounter ||
        header.flags != 0 ||
        header.payloadLength < 0 ||
        header.payloadLength > maxPayloadLength) {
      return _malformed('Invalid field range, reserved flags or payload size.');
    }
    if ((header.type == MessageType.dataChunk) != (header.payloadLength > 0)) {
      return _malformed('Only dataChunk carries a nonempty payload in v1.');
    }
    return null;
  }

  Failure _malformed(String message) =>
      NetworkFailure(NetworkFailureCode.malformedPacket, message);
}
