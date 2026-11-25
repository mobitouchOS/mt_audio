import 'package:audio_service/audio_service.dart';

/// Past this position, "previous" restarts the current item instead of
/// moving to the one before it.
const restartThreshold = Duration(seconds: 3);

/// Whether [next] holds exactly the same [MediaItem] objects as [current],
/// in the same order.
///
/// Compares with [identical] rather than `==`: `MediaItem.==` compares only
/// `id`, so an item replaced with new metadata under the same id (a new title
/// or artwork) must still count as a change.
bool isSameQueue(List<MediaItem>? current, List<MediaItem> next) {
  if (current == null || current.length != next.length) return false;
  for (var i = 0; i < next.length; i++) {
    if (!identical(current[i], next[i])) return false;
  }
  return true;
}

/// What a "previous" command does.
enum SkipPreviousAction {
  /// Seek to the start of the current item.
  restart,

  /// Move to the previous item.
  previous,
}

/// Standard transport behaviour for "previous": restart the current item when
/// there is nothing before it or when it has played past [restartThreshold].
SkipPreviousAction skipPreviousAction({
  required bool hasPrevious,
  required Duration position,
}) => !hasPrevious || position > restartThreshold
    ? SkipPreviousAction.restart
    : SkipPreviousAction.previous;
