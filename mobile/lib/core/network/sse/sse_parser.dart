import 'dart:async';
import 'dart:convert';

class SseEvent {
  const SseEvent({required this.event, required this.data, this.id});

  final String event;
  final String data;
  final String? id;

  @override
  bool operator ==(Object other) =>
      other is SseEvent &&
      other.event == event &&
      other.data == data &&
      other.id == id;

  @override
  int get hashCode => Object.hash(event, data, id);

  @override
  String toString() => 'SseEvent($event, ${jsonEncode(data)})';
}

/// Incremental text/event-stream decoder following the WHATWG parsing rules.
class SseParser extends StreamTransformerBase<List<int>, SseEvent> {
  const SseParser();

  @override
  Stream<SseEvent> bind(Stream<List<int>> stream) {
    late StreamController<SseEvent> controller;
    StreamSubscription<String>? subscription;
    final state = _SseState();

    controller = StreamController<SseEvent>(
      onListen: () {
        subscription = stream
            .cast<List<int>>()
            .transform(const Utf8Decoder())
            .listen(
              (chunk) => state.addText(chunk, controller.add),
              onError: controller.addError,
              onDone: () {
                state.finish();
                controller.close();
              },
            );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}

class _SseState {
  final _line = StringBuffer();
  final _data = StringBuffer();
  String _event = '';
  String? _lastId;
  bool _hasData = false;
  bool _pendingCr = false;
  bool _atStart = true;

  void addText(String text, void Function(SseEvent) emit) {
    var start = 0;
    if (_atStart && text.isNotEmpty) {
      _atStart = false;
      if (text.codeUnitAt(0) == 0xFEFF) start = 1;
    }
    for (var i = start; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (_pendingCr) {
        _pendingCr = false;
        if (unit == 0x0A) continue;
      }
      if (unit == 0x0D) {
        _pendingCr = true;
        _endLine(emit);
      } else if (unit == 0x0A) {
        _endLine(emit);
      } else {
        _line.writeCharCode(unit);
      }
    }
  }

  /// An unterminated final event is discarded, as the specification requires.
  void finish() {
    _line.clear();
    _resetEvent();
  }

  void _endLine(void Function(SseEvent) emit) {
    final line = _line.toString();
    _line.clear();
    if (line.isEmpty) {
      _dispatch(emit);
      return;
    }
    if (line.startsWith(':')) return;

    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    switch (field) {
      case 'event':
        _event = value;
      case 'data':
        if (_hasData) _data.write('\n');
        _data.write(value);
        _hasData = true;
      case 'id':
        if (!value.contains('\u0000')) _lastId = value;
    }
  }

  void _dispatch(void Function(SseEvent) emit) {
    if (_hasData) {
      emit(
        SseEvent(
          event: _event.isEmpty ? 'message' : _event,
          data: _data.toString(),
          id: _lastId,
        ),
      );
    }
    _resetEvent();
  }

  void _resetEvent() {
    _data.clear();
    _event = '';
    _hasData = false;
  }
}
