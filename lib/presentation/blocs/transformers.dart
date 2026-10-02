import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// Latest-wins event handling (like bloc_concurrency's `restartable`): a new
/// event cancels the handler still running for the previous one, so a slow
/// older response can never overwrite a newer one, and a re-issued watch
/// never leaves a second subscription emitting.
Stream<E> restartable<E>(Stream<E> events, EventMapper<E> mapper) {
  StreamSubscription<E>? inner;
  StreamSubscription<E>? outer;
  late final StreamController<E> out;
  out = StreamController<E>(
    onListen: () {
      outer = events.listen(
        (e) {
          inner?.cancel();
          inner = mapper(e).listen(out.add, onError: out.addError);
        },
        onError: out.addError,
        onDone: () async {
          await inner?.cancel();
          await out.close();
        },
      );
    },
    onCancel: () async {
      await inner?.cancel();
      await outer?.cancel();
    },
  );
  return out.stream;
}
