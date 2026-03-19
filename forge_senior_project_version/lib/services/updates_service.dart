import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase/firestore_refs.dart';
import 'events_service.dart';
import 'gyms_service.dart';

/// Update item types:
/// - post: gym channel post (shows likes/comments)
/// - event: upcoming friend/gym public event (shows event details + calendar link)
///
/// Common fields:
/// - type: 'post' | 'event'
/// - ts: DateTime (for sorting)
Map<String, dynamic> _postToUpdate({
  required String gymUid,
  required Map<String, dynamic> post,
}) {
  final createdAt = (post['createdAt'] as Timestamp?)?.toDate();
  return {
    'type': 'post',
    'gymUid': gymUid,
    'postId': post['id'],
    'channelName': post['channelName'],
    'authorUid': post['authorUid'],
    'authorName': post['authorName'],
    'content': post['content'],
    'likeIds': (post['likeIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[],
    'ts': createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
  };
}

Map<String, dynamic> _eventToUpdate(Map<String, dynamic> event) {
  final start = event['start'] as DateTime?;
  return {
    'type': 'event',
    'eventId': event['id'],
    'ownerId': event['ownerId'],
    'owner': event['owner'],
    'title': event['title'],
    'start': event['start'],
    'end': event['end'],
    'location': event['location'],
    'ts': start ?? DateTime.fromMillisecondsSinceEpoch(0),
  };
}

Stream<List<Map<String, dynamic>>> _mergeUpdateStreams(
  List<Stream<List<Map<String, dynamic>>>> streams,
) {
  if (streams.isEmpty) return Stream.value([]);

  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  final latest = List<List<Map<String, dynamic>>>.filled(streams.length, []);
  final subs = <StreamSubscription<List<Map<String, dynamic>>>>[];

  void emit() {
    final merged = latest.expand((l) => l).toList();
    merged.sort((a, b) => (b['ts'] as DateTime).compareTo(a['ts'] as DateTime));
    if (!controller.isClosed) controller.add(merged);
  }

  for (var i = 0; i < streams.length; i++) {
    final idx = i;
    subs.add(streams[i].listen(
      (data) {
        latest[idx] = data;
        emit();
      },
      onError: controller.addError,
      cancelOnError: false,
    ));
  }

  controller.onCancel = () async {
    for (final s in subs) await s.cancel();
  };

  return controller.stream;
}

/// Merged updates stream: gym channel posts + upcoming friend/gym public events.
Stream<List<Map<String, dynamic>>> getFeedUpdatesStream({
  int postsPerGymLimit = 10,
  Duration upcomingWindow = const Duration(days: 14),
}) async* {
  // Upcoming events (friends + gyms) reuses calendar logic. We only surface non-own events here.
  final now = DateTime.now();
  final windowEnd = now.add(upcomingWindow);

  final upcomingEventsStream = getEventsForDateRangeStream(now, windowEnd).map((events) {
    final updates = events
        .where((e) => e['isOwnEvent'] != true)
        .where((e) {
          final start = e['start'] as DateTime?;
          return start != null && start.isAfter(now);
        })
        .map(_eventToUpdate)
        .toList();
    updates.sort((a, b) => (b['ts'] as DateTime).compareTo(a['ts'] as DateTime));
    return updates;
  });

  try {
    final gyms = await getJoinedGymsWithNames();
    if (kDebugMode) {
      debugPrint('[Updates] Loaded ${gyms.length} gyms for posts');
    }

    final streams = <Stream<List<Map<String, dynamic>>>>[
      upcomingEventsStream,
    ];

    for (final g in gyms) {
      final gymUid = g['uid']!;
      final postsStream = FirestoreRefs.channelPosts(gymUid)
          .orderBy('createdAt', descending: true)
          .limit(postsPerGymLimit)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => {
                    'id': d.id,
                    ...?d.data(),
                    'createdAt': d.data()['createdAt'],
                  })
              .map((p) => _postToUpdate(gymUid: gymUid, post: p))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint('[Updates] Gym posts error ($gymUid): $e');
        }
      });
      streams.add(postsStream);
    }

    yield* _mergeUpdateStreams(streams);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Updates] getJoinedGymsWithNames error: $e');
    }
    yield* upcomingEventsStream;
  }
}

