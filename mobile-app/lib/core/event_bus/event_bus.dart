import 'dart:async';

/// A simple Event Bus implementation based on Dart Streams.
/// This allows decoupled components to publish and subscribe to domain-level events.
class EventBus {
  final StreamController _streamController;

  EventBus({bool sync = false})
      : _streamController = StreamController.broadcast(sync: sync);

  /// Subscribe to events of type [T].
  Stream<T> on<T>() {
    if (T == dynamic) {
      return _streamController.stream.cast<T>();
    } else {
      return _streamController.stream.where((event) => event is T).cast<T>();
    }
  }

  /// Publish a new event to the bus.
  void fire(dynamic event) {
    _streamController.add(event);
  }

  /// Clean up and close the event stream.
  void destroy() {
    _streamController.close();
  }
}
