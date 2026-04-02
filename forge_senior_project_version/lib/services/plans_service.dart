import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/firebase/firestore_refs.dart';

class PlanSummary {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime updatedAt;

  const PlanSummary({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.updatedAt,
  });
}

class PlanDetails extends PlanSummary {
  final String description;
  final int repeatWindowWeeks;
  final Map<String, int> linkedEventWeekdays;

  const PlanDetails({
    required super.id,
    required super.name,
    required super.startDate,
    required super.endDate,
    required super.status,
    required super.updatedAt,
    required this.description,
    required this.repeatWindowWeeks,
    required this.linkedEventWeekdays,
  });
}

class LinkableEvent {
  final String id;
  final String title;
  final String notes;
  final String eventType;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isPublic;
  final List<Map<String, dynamic>> exercises;
  final String? locationGymId;
  final String? locationGymName;

  const LinkableEvent({
    required this.id,
    required this.title,
    required this.notes,
    required this.eventType,
    required this.startAt,
    required this.endAt,
    required this.isPublic,
    required this.exercises,
    required this.locationGymId,
    required this.locationGymName,
  });
}

DateTime _dateAtTime(DateTime date, DateTime sourceTime) {
  return DateTime(
    date.year,
    date.month,
    date.day,
    sourceTime.hour,
    sourceTime.minute,
  );
}

DateTime _firstOnOrAfterForWeekday(DateTime startDate, int weekday) {
  final normalized = DateTime(startDate.year, startDate.month, startDate.day);
  final delta = (weekday - normalized.weekday + 7) % 7;
  return normalized.add(Duration(days: delta));
}

PlanSummary _planSummaryFromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> d,
) {
  final m = d.data();
  return PlanSummary(
    id: d.id,
    name: (m['name'] as String? ?? '').trim(),
    startDate: (m['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    endDate: (m['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    status: m['status'] as String? ?? 'active',
    updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

PlanDetails _planDetailsFromMap(String id, Map<String, dynamic> m) {
  final linked = (m['linkedEvents'] as List<dynamic>?) ?? const [];
  final linkedMap = <String, int>{};
  for (final e in linked) {
    final mm = Map<String, dynamic>.from(e as Map);
    final sourceId = mm['sourceEventId'] as String?;
    final weekday = mm['weekday'] as int?;
    if (sourceId != null && weekday != null) {
      linkedMap[sourceId] = weekday;
    }
  }
  return PlanDetails(
    id: id,
    name: (m['name'] as String? ?? '').trim(),
    description: m['description'] as String? ?? '',
    repeatWindowWeeks: m['repeatWindowWeeks'] as int? ?? 1,
    startDate: (m['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    endDate: (m['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    status: m['status'] as String? ?? 'active',
    updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    linkedEventWeekdays: linkedMap,
  );
}

Stream<List<PlanSummary>> getAllPlansStreamForCurrentUser() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(const []);

  return FirestoreRefs.userPlans(user.uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(_planSummaryFromDoc).toList());
}

Stream<List<PlanSummary>> getCurrentPlansStreamForCurrentUser() {
  final now = DateTime.now();
  return getAllPlansStreamForCurrentUser().map(
    (plans) => plans.where((p) => !p.endDate.isBefore(now)).toList(),
  );
}

Stream<List<PlanSummary>> getPreviousPlansStreamForCurrentUser() {
  final now = DateTime.now();
  return getAllPlansStreamForCurrentUser().map(
    (plans) => plans.where((p) => p.endDate.isBefore(now)).toList(),
  );
}

Future<PlanDetails?> getPlanDetailsForCurrentUser(String planId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final doc = await FirestoreRefs.userPlans(user.uid).doc(planId).get();
  if (!doc.exists || doc.data() == null) return null;
  return _planDetailsFromMap(doc.id, doc.data()!);
}

Future<PlanDetails?> findPlanByNameForCurrentUser(String name) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final snap = await FirestoreRefs.userPlans(user.uid)
      .where('name', isEqualTo: name)
      .orderBy('updatedAt', descending: true)
      .limit(1)
      .get();
  if (snap.docs.isEmpty) return null;
  final d = snap.docs.first;
  return _planDetailsFromMap(d.id, d.data());
}

Future<List<LinkableEvent>> getLinkableEventsForCurrentUser() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];

  final snap = await FirestoreRefs.userEvents(user.uid)
      .orderBy('createdAt', descending: true)
      .limit(200)
      .get();

  return snap.docs.map((d) {
    final m = d.data();
    return LinkableEvent(
      id: d.id,
      title: (m['title'] as String? ?? '').trim(),
      notes: m['notes'] as String? ?? '',
      eventType: m['eventType'] as String? ?? 'basic',
      startAt: (m['startAt'] as Timestamp?)?.toDate(),
      endAt: (m['endAt'] as Timestamp?)?.toDate(),
      isPublic: m['isPublic'] as bool? ?? false,
      exercises: (m['exercises'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      locationGymId: m['locationGymId'] as String?,
      locationGymName: m['locationGymName'] as String?,
    );
  }).where((e) => e.title.isNotEmpty).toList();
}

Future<String> createPlanForCurrentUser({
  required String name,
  required String description,
  required int repeatWindowWeeks,
  required DateTime startDate,
  required DateTime endDate,
  required Map<String, int> selectedEventWeekdays,
  int maxGeneratedInstances = 250,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');

  final trimmedName = name.trim();
  if (trimmedName.isEmpty) throw Exception('Plan name is required');
  if (repeatWindowWeeks <= 0) {
    throw Exception('Repeat window must be at least 1 week');
  }
  if (!endDate.isAfter(startDate)) {
    throw Exception('End date must be after start date');
  }
  if (selectedEventWeekdays.isEmpty) {
    throw Exception('Select at least one event for this plan');
  }

  final uniqueIds = selectedEventWeekdays.keys.toSet().toList();
  final sourceSnaps = await Future.wait(
    uniqueIds.map((id) => FirestoreRefs.userEvents(user.uid).doc(id).get()),
  );

  final sources = <String, LinkableEvent>{};
  for (final d in sourceSnaps) {
    if (!d.exists || d.data() == null) continue;
    final m = d.data()!;
    sources[d.id] = LinkableEvent(
      id: d.id,
      title: (m['title'] as String? ?? '').trim(),
      notes: m['notes'] as String? ?? '',
      eventType: m['eventType'] as String? ?? 'basic',
      startAt: (m['startAt'] as Timestamp?)?.toDate(),
      endAt: (m['endAt'] as Timestamp?)?.toDate(),
      isPublic: m['isPublic'] as bool? ?? false,
      exercises: (m['exercises'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      locationGymId: m['locationGymId'] as String?,
      locationGymName: m['locationGymName'] as String?,
    );
  }

  if (sources.isEmpty) {
    throw Exception('Could not load selected events');
  }

  final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
  final endOnly = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

  final planRef = FirestoreRefs.userPlans(user.uid).doc();
  final batch = FirebaseFirestore.instance.batch();
  final now = DateTime.now();

  int generatedCount = 0;
  final linkedEventsForPlan = <Map<String, dynamic>>[];

  for (final entry in selectedEventWeekdays.entries) {
    final source = sources[entry.key];
    if (source == null) continue;

    final weekday = entry.value;
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw Exception('Invalid weekday mapping for selected event');
    }

    linkedEventsForPlan.add({
      'sourceEventId': source.id,
      'title': source.title,
      'weekday': weekday,
    });

    final sourceStart = source.startAt ?? DateTime(2000, 1, 1, 9, 0);
    final sourceEnd = source.endAt ?? sourceStart.add(const Duration(hours: 1));
    final duration = sourceEnd.difference(sourceStart);

    DateTime occurrenceDate = _firstOnOrAfterForWeekday(startOnly, weekday);

    while (!occurrenceDate.isAfter(endOnly)) {
      if (generatedCount >= maxGeneratedInstances) {
        break;
      }

      final startAt = _dateAtTime(occurrenceDate, sourceStart);
      final endAt = startAt.add(duration.isNegative ? const Duration(hours: 1) : duration);

      final newEventRef = FirestoreRefs.userEvents(user.uid).doc();
      batch.set(newEventRef, {
        'title': source.title,
        'notes': source.notes,
        'eventType': source.eventType,
        'isPublic': source.isPublic,
        'inviteeIds': <String>[],
        'inviteeNames': <String>[],
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'exercises': source.exercises,
        'locationGymId': source.locationGymId,
        'locationGymName': source.locationGymName,
        'recurrence': null,
        'planId': planRef.id,
        'planSourceEventId': source.id,
        'createdAt': Timestamp.fromDate(now),
      });

      generatedCount++;
      occurrenceDate = occurrenceDate.add(Duration(days: 7 * repeatWindowWeeks));
    }
  }

  if (generatedCount == 0) {
    throw Exception('No event instances were generated. Check dates/day mapping.');
  }

  batch.set(planRef, {
    'userId': user.uid,
    'name': trimmedName,
    'description': description.trim(),
    'repeatWindowWeeks': repeatWindowWeeks,
    'startDate': Timestamp.fromDate(startOnly),
    'endDate': Timestamp.fromDate(endOnly),
    'linkedEvents': linkedEventsForPlan,
    'generatedInstanceCount': generatedCount,
    'maxGenerationCap': maxGeneratedInstances,
    'status': endOnly.isBefore(now) ? 'archived' : 'active',
    'createdAt': Timestamp.fromDate(now),
    'updatedAt': Timestamp.fromDate(now),
  });

  await batch.commit();
  return planRef.id;
}

Future<void> updatePlanForCurrentUser({
  required String planId,
  required String name,
  required String description,
  required int repeatWindowWeeks,
  required DateTime startDate,
  required DateTime endDate,
  required Map<String, int> selectedEventWeekdays,
  int maxGeneratedInstances = 180,
  bool updateFutureInstances = true,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');

  final trimmedName = name.trim();
  if (trimmedName.isEmpty) throw Exception('Plan name is required');
  if (repeatWindowWeeks <= 0) {
    throw Exception('Repeat window must be at least 1 week');
  }
  if (!endDate.isAfter(startDate)) {
    throw Exception('End date must be after start date');
  }
  if (selectedEventWeekdays.isEmpty) {
    throw Exception('Select at least one event for this plan');
  }

  final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
  final endOnly = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
  final now = DateTime.now();

  if (!updateFutureInstances) {
    final linkedEventsForPlan = selectedEventWeekdays.entries
        .map((e) => {
              'sourceEventId': e.key,
              'weekday': e.value,
            })
        .toList();

    await FirestoreRefs.userPlans(user.uid).doc(planId).update({
      'name': trimmedName,
      'description': description.trim(),
      'repeatWindowWeeks': repeatWindowWeeks,
      'startDate': Timestamp.fromDate(startOnly),
      'endDate': Timestamp.fromDate(endOnly),
      'linkedEvents': linkedEventsForPlan,
      'status': endOnly.isBefore(now) ? 'archived' : 'active',
      'updatedAt': Timestamp.fromDate(now),
    });
    return;
  }

  // Remove only future instances; leave historical occurrences untouched.
  final existingFuture = await FirestoreRefs.userEvents(user.uid)
      .where('planId', isEqualTo: planId)
      .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
      .get();
  for (int i = 0; i < existingFuture.docs.length; i += 300) {
    final chunk = existingFuture.docs.skip(i).take(300);
    final b = FirebaseFirestore.instance.batch();
    for (final d in chunk) {
      b.delete(d.reference);
    }
    await b.commit();
  }

  // Reuse create generation by creating a temp map of source events.
  final uniqueIds = selectedEventWeekdays.keys.toSet().toList();
  final sourceSnaps = await Future.wait(
    uniqueIds.map((id) => FirestoreRefs.userEvents(user.uid).doc(id).get()),
  );
  final sources = <String, LinkableEvent>{};
  for (final d in sourceSnaps) {
    if (!d.exists || d.data() == null) continue;
    final m = d.data()!;
    sources[d.id] = LinkableEvent(
      id: d.id,
      title: (m['title'] as String? ?? '').trim(),
      notes: m['notes'] as String? ?? '',
      eventType: m['eventType'] as String? ?? 'basic',
      startAt: (m['startAt'] as Timestamp?)?.toDate(),
      endAt: (m['endAt'] as Timestamp?)?.toDate(),
      isPublic: m['isPublic'] as bool? ?? false,
      exercises: (m['exercises'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      locationGymId: m['locationGymId'] as String?,
      locationGymName: m['locationGymName'] as String?,
    );
  }
  if (sources.isEmpty) throw Exception('Could not load selected events');

  int generatedCount = 0;
  final linkedEventsForPlan = <Map<String, dynamic>>[];
  final toCreate = <Map<String, dynamic>>[];

  for (final entry in selectedEventWeekdays.entries) {
    final source = sources[entry.key];
    if (source == null) continue;
    final weekday = entry.value;
    linkedEventsForPlan.add({
      'sourceEventId': source.id,
      'title': source.title,
      'weekday': weekday,
    });

    final sourceStart = source.startAt ?? DateTime(2000, 1, 1, 9, 0);
    final sourceEnd = source.endAt ?? sourceStart.add(const Duration(hours: 1));
    final duration = sourceEnd.difference(sourceStart);
    DateTime occurrenceDate = _firstOnOrAfterForWeekday(startOnly, weekday);

    while (!occurrenceDate.isAfter(endOnly)) {
      if (generatedCount >= maxGeneratedInstances) break;
      final startAt = _dateAtTime(occurrenceDate, sourceStart);
      if (!startAt.isBefore(now)) {
        final endAt = startAt.add(duration.isNegative ? const Duration(hours: 1) : duration);
        toCreate.add({
          'title': source.title,
          'notes': source.notes,
          'eventType': source.eventType,
          'isPublic': source.isPublic,
          'inviteeIds': <String>[],
          'inviteeNames': <String>[],
          'startAt': Timestamp.fromDate(startAt),
          'endAt': Timestamp.fromDate(endAt),
          'exercises': source.exercises,
          'locationGymId': source.locationGymId,
          'locationGymName': source.locationGymName,
          'recurrence': null,
          'planId': planId,
          'planSourceEventId': source.id,
          'createdAt': Timestamp.fromDate(now),
        });
        generatedCount++;
      }
      occurrenceDate = occurrenceDate.add(Duration(days: 7 * repeatWindowWeeks));
    }
  }

  for (int i = 0; i < toCreate.length; i += 300) {
    final b = FirebaseFirestore.instance.batch();
    for (final data in toCreate.skip(i).take(300)) {
      b.set(FirestoreRefs.userEvents(user.uid).doc(), data);
    }
    await b.commit();
  }

  await FirestoreRefs.userPlans(user.uid).doc(planId).update({
    'name': trimmedName,
    'description': description.trim(),
    'repeatWindowWeeks': repeatWindowWeeks,
    'startDate': Timestamp.fromDate(startOnly),
    'endDate': Timestamp.fromDate(endOnly),
    'linkedEvents': linkedEventsForPlan,
    'generatedInstanceCount': generatedCount,
    'maxGenerationCap': maxGeneratedInstances,
    'status': endOnly.isBefore(now) ? 'archived' : 'active',
    'updatedAt': Timestamp.fromDate(now),
  });
}

