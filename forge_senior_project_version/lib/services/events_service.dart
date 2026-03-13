import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/firebase/firestore_refs.dart';
import 'friends_service.dart';
import 'gyms_service.dart';

/// Creates an event in Firestore under the current user's events subcollection.
Future<void> createEvent({
  required String title,
  required String notes,
  required String eventType,
  required bool isPublic,
  required List<String> inviteeIds,
  required List<String> inviteeNames,
  required DateTime? startAt,
  required DateTime? endAt,
  required List<Map<String, dynamic>> exercises,
  String? locationGymId,
  String? locationGymName,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');

  final trimmedTitle = title.trim();
  if (trimmedTitle.isEmpty) throw Exception('Event title is required');

  await FirestoreRefs.userEvents(user.uid).add({
    'title': trimmedTitle,
    'notes': notes.trim(),
    'eventType': eventType,
    'isPublic': isPublic,
    'inviteeIds': inviteeIds,
    'inviteeNames': inviteeNames,
    'startAt': startAt != null ? Timestamp.fromDate(startAt) : null,
    'endAt': endAt != null ? Timestamp.fromDate(endAt) : null,
    'exercises': exercises,
    'locationGymId': locationGymId,
    'locationGymName': locationGymName,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// Fetches a single event by ID for the current user. Returns null if not found.
Future<Map<String, dynamic>?> getEvent(String eventId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final doc = await FirestoreRefs.userEvents(user.uid).doc(eventId).get();
  if (!doc.exists || doc.data() == null) return null;

  final d = doc.data()!;
  return {
    'id': doc.id,
    'title': d['title'] as String? ?? '',
    'notes': d['notes'] as String? ?? '',
    'eventType': d['eventType'] as String? ?? 'basic',
    'isPublic': d['isPublic'] as bool? ?? true,
    'inviteeIds': (d['inviteeIds'] as List<dynamic>?)?.cast<String>() ?? [],
    'inviteeNames': (d['inviteeNames'] as List<dynamic>?)?.cast<String>() ?? [],
    'startAt': (d['startAt'] as Timestamp?)?.toDate(),
    'endAt': (d['endAt'] as Timestamp?)?.toDate(),
    'exercises': (d['exercises'] as List<dynamic>?)?.map((e) {
      final m = (e as Map).map((k, v) => MapEntry(k.toString(), v));
      return Map<String, dynamic>.from(m);
    }).toList() ?? [],
    'locationGymId': d['locationGymId'] as String?,
    'locationGymName': d['locationGymName'] as String?,
  };
}

/// Updates an existing event in Firestore.
Future<void> updateEvent({
  required String eventId,
  required String title,
  required String notes,
  required String eventType,
  required bool isPublic,
  required List<String> inviteeIds,
  required List<String> inviteeNames,
  required DateTime? startAt,
  required DateTime? endAt,
  required List<Map<String, dynamic>> exercises,
  String? locationGymId,
  String? locationGymName,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');

  final trimmedTitle = title.trim();
  if (trimmedTitle.isEmpty) throw Exception('Event title is required');

  await FirestoreRefs.userEvents(user.uid).doc(eventId).update({
    'title': trimmedTitle,
    'notes': notes.trim(),
    'eventType': eventType,
    'isPublic': isPublic,
    'inviteeIds': inviteeIds,
    'inviteeNames': inviteeNames,
    'startAt': startAt != null ? Timestamp.fromDate(startAt) : null,
    'endAt': endAt != null ? Timestamp.fromDate(endAt) : null,
    'exercises': exercises,
    'locationGymId': locationGymId,
    'locationGymName': locationGymName,
  });
}

/// Default colors for calendar events.
const Color _ownEventColor = Color(0xFF4D7CFF); // forge blue
const Color _friendEventColor = Color(0xFF4CAF50); // green
const Color _gymEventColor = Color(0xFFFFA726); // orange

Map<String, dynamic> _mapDocToEvent(
  QueryDocumentSnapshot<Map<String, dynamic>> doc, {
  required String owner,
  required bool isOwnEvent,
  String? ownerId,
  required Color color,
}) {
  final d = doc.data();
  final start = (d['startAt'] as Timestamp).toDate();
  final end = (d['endAt'] as Timestamp).toDate();
  final inviteeIds = d['inviteeIds'] as List<dynamic>? ?? [];
  final inviteeNames = d['inviteeNames'] as List<dynamic>? ?? [];
  return <String, dynamic>{
    'id': doc.id,
    'ownerId': ownerId,
    'isOwnEvent': isOwnEvent,
    'title': d['title'] as String? ?? '',
    'start': start,
    'end': end,
    'color': color,
    'owner': owner,
    'hasInvite': inviteeIds.isNotEmpty,
    'hasAttend': false,
    'location': d['locationGymName'] as String?,
    'attendees': inviteeNames.cast<String>(),
    'exercises': (d['exercises'] as List<dynamic>?)
            ?.map((e) {
              final m = e as Map;
              return <String, String>{
                'name': m['name']?.toString() ?? '',
                'sets': m['sets']?.toString() ?? '',
                'weight': m['weight']?.toString() ?? '',
              };
            })
            .toList() ??
        [],
    'notes': d['notes'] as String? ?? '',
    'privacy': (d['isPublic'] == true) ? 'Public' : 'Friends Only',
  };
}

/// Merges multiple event streams into one, sorted by start time.
Stream<List<Map<String, dynamic>>> _mergeEventStreams(
  List<Stream<List<Map<String, dynamic>>>> streams,
) {
  if (streams.isEmpty) return Stream.value([]);

  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  final latest = List<List<Map<String, dynamic>>>.filled(streams.length, []);
  final subs = <StreamSubscription<List<Map<String, dynamic>>>>[];

  void emit() {
    final merged = latest.expand((l) => l).toList();
    merged.sort(
        (a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
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

/// Stream of events for a single day: own events + friends' public events + joined gyms' public events.
Stream<List<Map<String, dynamic>>> getEventsForDayStream(DateTime date) async* {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    yield [];
    return;
  }

  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  final ownEventsStream = FirestoreRefs.userEvents(user.uid)
      .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
      .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
      .orderBy('startAt')
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.data()['endAt'] != null)
          .map((d) => _mapDocToEvent(d,
              owner: 'You',
              isOwnEvent: true,
              ownerId: user.uid,
              color: _ownEventColor))
          .toList());

  try {
    final friends = await getFriendIdsWithNames();
    final gyms = await getJoinedGymsWithNames();
    if (kDebugMode) {
      debugPrint(
          '[Calendar] Loaded ${friends.length} friends and ${gyms.length} gyms for day view');
    }
    final streams = <Stream<List<Map<String, dynamic>>>>[ownEventsStream];

    for (final f in friends) {
      final uid = f['uid']!;
      final name = f['name']!;
      final friendStream = FirestoreRefs.userEvents(uid)
          .where('isPublic', isEqualTo: true)
          .where('startAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .map((d) => _mapDocToEvent(d,
                  owner: name,
                  isOwnEvent: false,
                  ownerId: uid,
                  color: _friendEventColor))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint('[Calendar] Friend $name ($uid) events error: $e');
        }
      });
      streams.add(friendStream);
    }

    for (final g in gyms) {
      final gymUid = g['uid']!;
      final gymName = g['name']!;
      final gymStream = FirestoreRefs.userEvents(gymUid)
          .where('isPublic', isEqualTo: true)
          .where('startAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .map((d) => _mapDocToEvent(d,
                  owner: gymName,
                  isOwnEvent: false,
                  ownerId: gymUid,
                  color: _gymEventColor))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint('[Calendar] Gym $gymName ($gymUid) events error: $e');
        }
      });
      streams.add(gymStream);
    }

    yield* _mergeEventStreams(streams);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Calendar] getFriendsOrGyms error: $e');
    }
    yield* ownEventsStream;
  }
}

/// Stream of events for a date range (inclusive): own + friends' public events + joined gyms' public events.
Stream<List<Map<String, dynamic>>> getEventsForDateRangeStream(
  DateTime startDate,
  DateTime endDate,
) async* {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    yield [];
    return;
  }

  final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
  final rangeEnd = DateTime(
    endDate.year,
    endDate.month,
    endDate.day,
    23,
    59,
    59,
    999,
  );

  final ownEventsStream = FirestoreRefs.userEvents(user.uid)
      .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
      .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
      .orderBy('startAt')
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.data()['endAt'] != null)
          .map((d) => _mapDocToEvent(d,
              owner: 'You',
              isOwnEvent: true,
              ownerId: user.uid,
              color: _ownEventColor))
          .toList());

  try {
    final friends = await getFriendIdsWithNames();
    final gyms = await getJoinedGymsWithNames();
    if (kDebugMode) {
      debugPrint(
          '[Calendar] Loaded ${friends.length} friends and ${gyms.length} gyms for range view');
    }
    final streams = <Stream<List<Map<String, dynamic>>>>[ownEventsStream];

    for (final f in friends) {
      final uid = f['uid']!;
      final name = f['name']!;
      final friendStream = FirestoreRefs.userEvents(uid)
          .where('isPublic', isEqualTo: true)
          .where('startAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
          .where('startAt',
              isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .map((d) => _mapDocToEvent(d,
                  owner: name,
                  isOwnEvent: false,
                  ownerId: uid,
                  color: _friendEventColor))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint('[Calendar] Friend $name ($uid) events error: $e');
        }
      });
      streams.add(friendStream);
    }

    for (final g in gyms) {
      final gymUid = g['uid']!;
      final gymName = g['name']!;
      final gymStream = FirestoreRefs.userEvents(gymUid)
          .where('isPublic', isEqualTo: true)
          .where('startAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
          .where('startAt',
              isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .map((d) => _mapDocToEvent(d,
                  owner: gymName,
                  isOwnEvent: false,
                  ownerId: gymUid,
                  color: _gymEventColor))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint('[Calendar] Gym $gymName ($gymUid) events error: $e');
        }
      });
      streams.add(gymStream);
    }

    yield* _mergeEventStreams(streams);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Calendar] getFriendsOrGyms error: $e');
    }
    yield* ownEventsStream;
  }
}
