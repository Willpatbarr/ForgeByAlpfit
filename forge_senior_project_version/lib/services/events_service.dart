import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/firebase/firestore_refs.dart';
import 'friends_service.dart';
import 'gyms_service.dart';

Map<String, dynamic>? _normalizeRecurrenceForWrite(
    Map<String, dynamic>? recurrence) {
  if (recurrence == null) return null;
  final frequency = recurrence['frequency'] as String?;
  if (frequency == null || frequency == 'none') return null;

  final normalized = <String, dynamic>{};
  normalized['frequency'] = frequency;
  final endType = recurrence['endType'] as String? ?? 'never';
  normalized['endType'] = endType;

  final untilDate = recurrence['untilDate'] as DateTime?;
  normalized['untilDate'] =
      untilDate != null ? Timestamp.fromDate(untilDate) : null;

  final daysOfWeek = recurrence['daysOfWeek'] as List<dynamic>?;
  if (daysOfWeek != null) {
    normalized['daysOfWeek'] = daysOfWeek.map((e) => e as int).toList();
  }

  return normalized;
}

Map<String, dynamic>? _readRecurrenceFromDoc(Map<String, dynamic> data) {
  final raw = data['recurrence'];
  if (raw is! Map) return null;
  final m = raw.map((k, v) => MapEntry(k.toString(), v));
  final result = Map<String, dynamic>.from(m);
  final untilTs = result['untilDate'] as Timestamp?;
  if (untilTs != null) {
    result['untilDate'] = untilTs.toDate();
  }
  final days = result['daysOfWeek'] as List<dynamic>?;
  if (days != null) {
    result['daysOfWeek'] = days.map((e) => e as int).toList();
  }
  return result;
}

/// Returns the next upcoming workout event for the current user, or null if none.
Future<Map<String, dynamic>?> getNextWorkoutEventForUser() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final now = DateTime.now();
  final rangeEnd = now.add(const Duration(days: 60));

  // Reuse the same logic as the calendar so behavior is consistent,
  // then pick the earliest own workout event in the future.
  final events = await getEventsForDateRangeStream(now, rangeEnd).first;

  DateTime? bestStart;
  Map<String, dynamic>? best;

  for (final e in events) {
    final isOwn = e['isOwnEvent'] == true;
    final type = e['eventType'] as String? ?? 'basic';
    if (!isOwn) continue;
    if (type != 'workout') continue;

    final start = e['start'] as DateTime?;
    final end = e['end'] as DateTime?;
    if (start == null || end == null) continue;
    if (start.isBefore(now)) continue;

    if (bestStart == null || start.isBefore(bestStart)) {
      bestStart = start;
      best = {
        'id': e['id'],
        'title': e['title'] as String? ?? '',
        'startAt': start,
        'endAt': end,
      };
    }
  }

  return best;
}

/// Creates an event in Firestore under the current user's events subcollection.
/// Returns the new event document id.
Future<String> createEvent({
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
  Map<String, dynamic>? recurrence,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');

  final trimmedTitle = title.trim();
  if (trimmedTitle.isEmpty) throw Exception('Event title is required');

  final ref = await FirestoreRefs.userEvents(user.uid).add({
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
    'recurrence': _normalizeRecurrenceForWrite(recurrence),
    'createdAt': FieldValue.serverTimestamp(),
  });
  return ref.id;
}

/// Loads a single event for calendar display (owner's doc). Caller must have read
/// access (e.g. invitee or public friend/gym rules).
Future<Map<String, dynamic>?> getCalendarEventForDeepLink({
  required String ownerUid,
  required String eventId,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final doc = await FirestoreRefs.userEvents(ownerUid).doc(eventId).get();
  if (!doc.exists || doc.data() == null) return null;
  final d = doc.data()!;
  if (d['startAt'] == null || d['endAt'] == null) return null;

  if (user.uid == ownerUid) {
    return _mapDocToEvent(
      doc,
      owner: 'You',
      isOwnEvent: true,
      ownerId: ownerUid,
      color: _ownEventColor,
    );
  }

  final ownerDoc = await FirestoreRefs.userDoc(ownerUid).get();
  final dn = ownerDoc.data()?['displayName'] as String?;
  final ownerName =
      (dn != null && dn.trim().isNotEmpty) ? dn.trim() : 'Friend';

  return _mapDocToEvent(
    doc,
    owner: ownerName,
    isOwnEvent: false,
    ownerId: ownerUid,
    color: _friendEventColor,
  );
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
    'recurrence': _readRecurrenceFromDoc(d),
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
  Map<String, dynamic>? recurrence,
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
    'recurrence': _normalizeRecurrenceForWrite(recurrence),
  });
}

/// Default colors for calendar events.
const Color _ownEventColor = Color(0xFF4D7CFF); // forge blue
const Color _friendEventColor = Color(0xFF4CAF50); // green
const Color _gymEventColor = Color(0xFFFFA726); // orange

Map<String, dynamic> _mapDocToEvent(
  DocumentSnapshot<Map<String, dynamic>> doc, {
  required String owner,
  required bool isOwnEvent,
  String? ownerId,
  required Color color,
  DateTime? startOverride,
  DateTime? endOverride,
}) {
  final d = doc.data();
  if (d == null) {
    throw StateError('Event snapshot has no data');
  }
  final originalStart = (d['startAt'] as Timestamp).toDate();
  final originalEnd = (d['endAt'] as Timestamp).toDate();
  final start = startOverride ?? originalStart;
  final end = endOverride ?? originalEnd;
  final inviteeIds = d['inviteeIds'] as List<dynamic>? ?? [];
  final inviteeNames = d['inviteeNames'] as List<dynamic>? ?? [];
  return <String, dynamic>{
    'id': doc.id,
    'ownerId': ownerId,
    'isOwnEvent': isOwnEvent,
    'eventType': d['eventType'] as String? ?? 'basic',
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

bool _eventOccursOnDate(
  Map<String, dynamic> data,
  DateTime targetDate,
) {
  final recurrence = _readRecurrenceFromDoc(data);
  final tsStart = data['startAt'] as Timestamp?;
  if (tsStart == null) return false;
  final start = tsStart.toDate();
  final baseDate = DateTime(start.year, start.month, start.day);
  final target = DateTime(targetDate.year, targetDate.month, targetDate.day);

  if (recurrence == null || recurrence['frequency'] == null) {
    return baseDate == target;
  }

  final frequency = recurrence['frequency'] as String? ?? 'none';
  if (frequency == 'none') {
    return baseDate == target;
  }

  final untilDate = recurrence['untilDate'] as DateTime?;
  if (target.isBefore(baseDate)) return false;
  if (untilDate != null) {
    final until = DateTime(untilDate.year, untilDate.month, untilDate.day, 23, 59, 59, 999);
    if (target.isAfter(until)) return false;
  }

  switch (frequency) {
    case 'weekly':
      return target.weekday == baseDate.weekday;
    case 'every_other_day':
      final diff = target.difference(baseDate).inDays;
      return diff % 2 == 0;
    case 'monthly':
      return target.day == baseDate.day;
    case 'custom_weekly':
      final days = (recurrence['daysOfWeek'] as List<dynamic>? ?? [])
          .map((e) => e as int)
          .toSet();
      return days.contains(target.weekday);
    default:
      return false;
  }
}

Iterable<Map<String, dynamic>> _expandDocToEventsForDay(
  DocumentSnapshot<Map<String, dynamic>> doc,
  DateTime targetDate, {
  required String owner,
  required bool isOwnEvent,
  String? ownerId,
  required Color color,
}) sync* {
  final data = doc.data();
  if (data == null) return;
  if (!_eventOccursOnDate(data, targetDate)) return;

  final tsStart = data['startAt'] as Timestamp?;
  final tsEnd = data['endAt'] as Timestamp?;
  if (tsStart == null || tsEnd == null) return;
  final originalStart = tsStart.toDate();
  final originalEnd = tsEnd.toDate();
  final duration = originalEnd.difference(originalStart);

  final occurrenceStart = DateTime(
    targetDate.year,
    targetDate.month,
    targetDate.day,
    originalStart.hour,
    originalStart.minute,
    originalStart.second,
    originalStart.millisecond,
    originalStart.microsecond,
  );
  final occurrenceEnd = occurrenceStart.add(duration);

  yield _mapDocToEvent(
    doc,
    owner: owner,
    isOwnEvent: isOwnEvent,
    ownerId: ownerId,
    color: color,
    startOverride: occurrenceStart,
    endOverride: occurrenceEnd,
  );
}

Iterable<Map<String, dynamic>> _expandDocToEventsForRange(
  DocumentSnapshot<Map<String, dynamic>> doc,
  DateTime rangeStart,
  DateTime rangeEnd, {
  required String owner,
  required bool isOwnEvent,
  String? ownerId,
  required Color color,
}) sync* {
  final data = doc.data();
  if (data == null) return;
  final recurrence = _readRecurrenceFromDoc(data);
  final tsStart = data['startAt'] as Timestamp?;
  final tsEnd = data['endAt'] as Timestamp?;
  if (tsStart == null || tsEnd == null) return;
  final originalStart = tsStart.toDate();
  final originalEnd = tsEnd.toDate();
  final baseDate = DateTime(originalStart.year, originalStart.month, originalStart.day);

  if (recurrence == null || recurrence['frequency'] == null || recurrence['frequency'] == 'none') {
    final startDate = DateTime(originalStart.year, originalStart.month, originalStart.day);
    if (!startDate.isBefore(rangeStart) && !startDate.isAfter(rangeEnd)) {
      yield _mapDocToEvent(
        doc,
        owner: owner,
        isOwnEvent: isOwnEvent,
        ownerId: ownerId,
        color: color,
      );
    }
    return;
  }

  final untilDate = recurrence['untilDate'] as DateTime?;
  final limitEnd = untilDate != null && untilDate.isBefore(rangeEnd) ? untilDate : rangeEnd;
  if (limitEnd.isBefore(rangeStart)) return;

  DateTime current = rangeStart.isAfter(baseDate) ? rangeStart : baseDate;
  while (!current.isAfter(limitEnd)) {
    if (_eventOccursOnDate(data, current)) {
      final occurrenceStart = DateTime(
        current.year,
        current.month,
        current.day,
        originalStart.hour,
        originalStart.minute,
        originalStart.second,
        originalStart.millisecond,
        originalStart.microsecond,
      );
      final occurrenceEnd = occurrenceStart.add(originalEnd.difference(originalStart));
      yield _mapDocToEvent(
        doc,
        owner: owner,
        isOwnEvent: isOwnEvent,
        ownerId: ownerId,
        color: color,
        startOverride: occurrenceStart,
        endOverride: occurrenceEnd,
      );
    }
    current = current.add(const Duration(days: 1));
  }
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
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final e in merged) {
      final start = e['start'] as DateTime;
      final ownerKey = e['ownerId']?.toString() ?? '';
      final id = e['id']?.toString() ?? '';
      final key = '${ownerKey}_${id}_${start.millisecondsSinceEpoch}';
      if (seen.add(key)) deduped.add(e);
    }
    deduped.sort(
      (a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime),
    );
    if (!controller.isClosed) controller.add(deduped);
  }

  for (var i = 0; i < streams.length; i++) {
    final idx = i;
    subs.add(streams[i].listen(
      (data) {
        latest[idx] = data;
        emit();
      },
      onError: (Object e, StackTrace st) {
        controller.addError(e, st);
      },
      cancelOnError: false,
    ));
  }

  controller.onCancel = () async {
    for (final s in subs) {
      await s.cancel();
    }
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
      .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
      .orderBy('startAt')
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.data()['endAt'] != null)
          .expand((d) => _expandDocToEventsForDay(
                d,
                dayStart,
                owner: 'You',
                isOwnEvent: true,
                ownerId: user.uid,
                color: _ownEventColor,
              ))
          .toList());

  try {
    final friends = await getFriendIdsWithNames();
    final gyms = await getJoinedGymsWithNames();
    final streams = <Stream<List<Map<String, dynamic>>>>[ownEventsStream];

    for (final f in friends) {
      final uid = f['uid']!;
      final name = f['name']!;
      final friendStream = FirestoreRefs.userEvents(uid)
          .where('isPublic', isEqualTo: true)
          .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .expand((d) => _expandDocToEventsForDay(
                    d,
                    dayStart,
                    owner: name,
                    isOwnEvent: false,
                    ownerId: uid,
                    color: _friendEventColor,
                  ))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint('[Calendar] Friend $name ($uid) events error: $e');
        }
      });
      streams.add(friendStream);

      final friendInvitedStream = FirestoreRefs.userEvents(uid)
          .where('inviteeIds', arrayContains: user.uid)
          .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .expand((d) => _expandDocToEventsForDay(
                    d,
                    dayStart,
                    owner: name,
                    isOwnEvent: false,
                    ownerId: uid,
                    color: _friendEventColor,
                  ))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint(
              '[Calendar] Friend $name ($uid) invited events error: $e');
        }
      });
      streams.add(friendInvitedStream);
    }

    for (final g in gyms) {
      final gymUid = g['uid']!;
      final gymName = g['name']!;
      final gymStream = FirestoreRefs.userEvents(gymUid)
          .where('isPublic', isEqualTo: true)
          .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .expand((d) => _expandDocToEventsForDay(
                    d,
                    dayStart,
                    owner: gymName,
                    isOwnEvent: false,
                    ownerId: gymUid,
                    color: _gymEventColor,
                  ))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint('[Calendar] Gym $gymName ($gymUid) events error: $e');
        }
      });
      streams.add(gymStream);

      final gymInvitedStream = FirestoreRefs.userEvents(gymUid)
          .where('inviteeIds', arrayContains: user.uid)
          .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .expand((d) => _expandDocToEventsForDay(
                    d,
                    dayStart,
                    owner: gymName,
                    isOwnEvent: false,
                    ownerId: gymUid,
                    color: _gymEventColor,
                  ))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint(
              '[Calendar] Gym $gymName ($gymUid) invited events error: $e');
        }
      });
      streams.add(gymInvitedStream);
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
      .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
      .orderBy('startAt')
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.data()['endAt'] != null)
          .expand((d) => _expandDocToEventsForRange(
                d,
                rangeStart,
                rangeEnd,
                owner: 'You',
                isOwnEvent: true,
                ownerId: user.uid,
                color: _ownEventColor,
              ))
          .toList());

  try {
    final friends = await getFriendIdsWithNames();
    final gyms = await getJoinedGymsWithNames();
    final streams = <Stream<List<Map<String, dynamic>>>>[ownEventsStream];

    for (final f in friends) {
      final uid = f['uid']!;
      final name = f['name']!;
      final friendStream = FirestoreRefs.userEvents(uid)
          .where('isPublic', isEqualTo: true)
          .where('startAt',
              isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .expand((d) => _expandDocToEventsForRange(
                    d,
                    rangeStart,
                    rangeEnd,
                    owner: name,
                    isOwnEvent: false,
                    ownerId: uid,
                    color: _friendEventColor,
                  ))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint('[Calendar] Friend $name ($uid) events error: $e');
        }
      });
      streams.add(friendStream);

      final friendInvitedStream = FirestoreRefs.userEvents(uid)
          .where('inviteeIds', arrayContains: user.uid)
          .where('startAt',
              isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .expand((d) => _expandDocToEventsForRange(
                    d,
                    rangeStart,
                    rangeEnd,
                    owner: name,
                    isOwnEvent: false,
                    ownerId: uid,
                    color: _friendEventColor,
                  ))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint(
              '[Calendar] Friend $name ($uid) invited events error: $e');
        }
      });
      streams.add(friendInvitedStream);
    }

    for (final g in gyms) {
      final gymUid = g['uid']!;
      final gymName = g['name']!;
      final gymStream = FirestoreRefs.userEvents(gymUid)
          .where('isPublic', isEqualTo: true)
          .where('startAt',
              isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .expand((d) => _expandDocToEventsForRange(
                    d,
                    rangeStart,
                    rangeEnd,
                    owner: gymName,
                    isOwnEvent: false,
                    ownerId: gymUid,
                    color: _gymEventColor,
                  ))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint('[Calendar] Gym $gymName ($gymUid) events error: $e');
        }
      });
      streams.add(gymStream);

      final gymInvitedStream = FirestoreRefs.userEvents(gymUid)
          .where('inviteeIds', arrayContains: user.uid)
          .where('startAt',
              isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['endAt'] != null)
              .expand((d) => _expandDocToEventsForRange(
                    d,
                    rangeStart,
                    rangeEnd,
                    owner: gymName,
                    isOwnEvent: false,
                    ownerId: gymUid,
                    color: _gymEventColor,
                  ))
              .toList())
          .handleError((e) {
        if (kDebugMode) {
          debugPrint(
              '[Calendar] Gym $gymName ($gymUid) invited events error: $e');
        }
      });
      streams.add(gymInvitedStream);
    }

    yield* _mergeEventStreams(streams);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Calendar] getFriendsOrGyms error: $e');
    }
    yield* ownEventsStream;
  }
}
