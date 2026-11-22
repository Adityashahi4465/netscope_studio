import 'dart:math';

/// Simulated application discard after a valid UDP request arrives. This is
/// independent of RTT echo delivery and does not model TCP retransmissions.
/// Decisions depend only on seed and sequence, so duplicates and reordering
/// cannot consume random draws and change another sequence's outcome.
class UdpDropPolicy {
  final double probability;
  final int seed;

  const UdpDropPolicy({required this.probability, required this.seed});

  bool shouldDrop(int sequence) =>
      Random((seed ^ (sequence * 0x9e3779b9)) & 0xffffffff).nextDouble() <
      probability;
}
