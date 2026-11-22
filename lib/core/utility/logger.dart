import 'dart:developer' as developer;

import 'package:fpdart/fpdart.dart';

import '../failure.dart';
import '../type_defs.dart';

class AppLogger {
  const AppLogger();

  FutureEither<T> guard<T>(
    String action,
    Future<T> Function() operation,
  ) async {
    try {
      return right(await operation());
    } on Failure catch (failure) {
      return left(failure);
    } on Object catch (error, stack) {
      developer.log(
        action,
        name: 'NetScope Studio',
        error: error,
        stackTrace: stack,
      );
      return left(Failure('$action: $error', cause: error));
    }
  }
}
