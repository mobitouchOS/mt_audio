import 'package:rxdart/rxdart.dart';

/// Per-parent "children changed" streams for audio_service.
///
/// audio_service subscribes once to a parent the first time Android Auto
/// loads it, and asks Android Auto to reload that parent whenever the stream
/// emits. The streams are unseeded so subscribing never triggers a reload.
class MtChildrenChangeNotifier {
  final Map<String, BehaviorSubject<Map<String, dynamic>>> _subjects = {};

  /// The change stream for [parentMediaId], created on first use.
  ValueStream<Map<String, dynamic>> subscribe(String parentMediaId) => _subjects
      .putIfAbsent(parentMediaId, BehaviorSubject<Map<String, dynamic>>.new);

  /// Asks Android Auto to reload [parentMediaId]; no-op if it never loaded it.
  void notify(String parentMediaId) =>
      _subjects[parentMediaId]?.add(const <String, dynamic>{});

  /// Closes every stream.
  Future<void> dispose() =>
      Future.wait(_subjects.values.map((subject) => subject.close()));
}
