import 'dart:async';
import 'dart:io';

import '../../core/failure.dart';

enum NetworkFailureCode {
  invalidInput,
  malformedPacket,
  portInUse,
  refused,
  timeout,
  disconnected,
  cancelled,
  busy,
  byteCountMismatch,
  io,
}

class NetworkFailure extends Failure {
  final NetworkFailureCode code;

  const NetworkFailure(this.code, super.message, {super.cause});

  static NetworkFailure from(Object error, {bool binding = false}) {
    if (error is NetworkFailure) return error;
    if (error is TimeoutException) {
      return NetworkFailure(
        NetworkFailureCode.timeout,
        'TCP operation timed out.',
        cause: error,
      );
    }
    if (error is SocketException) {
      final code = error.osError?.errorCode;
      // Dart may reject a duplicate in-process bind before an OS bind call;
      // that error has no errno and describes the incompatible shared flag.
      final duplicateBind =
          error.osError?.message.contains(
            'The shared flag to bind() needs to be',
          ) ??
          false;
      if (binding &&
          (const <int>{48, 98, 10048}.contains(code) || duplicateBind)) {
        return NetworkFailure(
          NetworkFailureCode.portInUse,
          'TCP port is already in use.',
          cause: error,
        );
      }
      if (const <int>{61, 111, 10061}.contains(code)) {
        return NetworkFailure(
          NetworkFailureCode.refused,
          'TCP connection refused.',
          cause: error,
        );
      }
      if (const <int>{54, 57, 32, 104, 107, 10054, 10057}.contains(code)) {
        return NetworkFailure(
          NetworkFailureCode.disconnected,
          'TCP peer disconnected.',
          cause: error,
        );
      }
      if (const <int>{60, 110, 10060}.contains(code)) {
        return NetworkFailure(
          NetworkFailureCode.timeout,
          'TCP connection timed out.',
          cause: error,
        );
      }
    }
    return NetworkFailure(
      NetworkFailureCode.io,
      'TCP operation failed.',
      cause: error,
    );
  }
}
