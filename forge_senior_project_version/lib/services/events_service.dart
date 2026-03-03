import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/firebase/firestore_refs.dart';

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

/// Default color for calendar events when no type-specific color is set.
const Color _defaultEventColor = Color(0xFF4D7CFF); // forge blue

/// Stream of events for a single day for the current user. Only includes events
/// that have both startAt and endAt set. Events are mapped to the shape expected
/// by the calendar UI (start/end as DateTime, color, owner, etc.).
Stream<List<Map<String, dynamic>>> getEventsForDayStream(DateTime date) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  return FirestoreRefs.userEvents(user.uid)
      .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
      .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
      .orderBy('startAt')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .where((doc) => doc.data()['endAt'] != null)
            .map((doc) {
          final d = doc.data();
          final start = (d['startAt'] as Timestamp).toDate();
          final end = (d['endAt'] as Timestamp).toDate();
          final inviteeIds = d['inviteeIds'] as List<dynamic>? ?? [];
          final inviteeNames = d['inviteeNames'] as List<dynamic>? ?? [];
          return <String, dynamic>{
            'id': doc.id,
            'title': d['title'] as String? ?? '',
            'start': start,
            'end': end,
            'color': _defaultEventColor,
            'owner': 'You',
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
        })
            .toList();
      });
}

/// Stream of events for a date range (inclusive) for the current user.
/// Only includes events with both startAt and endAt. Same event shape as [getEventsForDayStream].
Stream<List<Map<String, dynamic>>> getEventsForDateRangeStream(
  DateTime startDate,
  DateTime endDate,
) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

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

  return FirestoreRefs.userEvents(user.uid)
      .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
      .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
      .orderBy('startAt')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .where((doc) => doc.data()['endAt'] != null)
            .map((doc) {
          final d = doc.data();
          final start = (d['startAt'] as Timestamp).toDate();
          final end = (d['endAt'] as Timestamp).toDate();
          final inviteeIds = d['inviteeIds'] as List<dynamic>? ?? [];
          final inviteeNames = d['inviteeNames'] as List<dynamic>? ?? [];
          return <String, dynamic>{
            'id': doc.id,
            'title': d['title'] as String? ?? '',
            'start': start,
            'end': end,
            'color': _defaultEventColor,
            'owner': 'You',
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
        })
            .toList();
      });
}
