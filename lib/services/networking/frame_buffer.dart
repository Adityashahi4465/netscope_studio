import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import 'network_failure.dart';
import 'packet_protocol.dart';

/// Holds at most one bounded incomplete frame. A malformed frame poisons the
/// buffer: callers must disconnect rather than attempt unsafe resynchronization.
class FrameBuffer {
  final PacketProtocol protocol;
  final Uint8List _pending = Uint8List(
    PacketProtocol.headerSize + PacketProtocol.maxPayloadLength,
  );
  int _length = 0;
  int _target = PacketProtocol.headerSize;
  Failure? _failure;

  FrameBuffer({this.protocol = const PacketProtocol()});

  int get pendingBytes => _length;

  Either<Failure, List<Packet>> add(Uint8List bytes) {
    if (_failure != null) return left(_failure!);
    final packets = <Packet>[];
    var offset = 0;
    while (offset < bytes.length) {
      final remaining = _target - _length;
      final count = remaining < bytes.length - offset
          ? remaining
          : bytes.length - offset;
      _pending.setRange(_length, _length + count, bytes, offset);
      _length += count;
      offset += count;
      if (_length < _target) continue;
      if (_target == PacketProtocol.headerSize) {
        protocol
            .decodeHeader(
              Uint8List.sublistView(_pending, 0, PacketProtocol.headerSize),
            )
            .fold((failure) => _failure = failure, (header) {
              _target = PacketProtocol.headerSize + header.payloadLength;
            });
        if (_failure != null) return left(_failure!);
        if (_length < _target) continue;
      }
      protocol
          .decode(Uint8List.sublistView(_pending, 0, _target))
          .fold((failure) => _failure = failure, packets.add);
      if (_failure != null) return left(_failure!);
      _length = 0;
      _target = PacketProtocol.headerSize;
    }
    return right(List<Packet>.unmodifiable(packets));
  }

  Either<Failure, void> finish() {
    if (_failure != null) return left(_failure!);
    if (_length != 0) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.disconnected,
          'TCP peer closed during an incomplete frame.',
        ),
      );
    }
    return right(null);
  }
}
