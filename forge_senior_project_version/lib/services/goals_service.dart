import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/firebase/firestore_refs.dart';
import '../models/goal.dart';

/// Computes the end of a period given its start and reset type.
DateTime _periodEnd(DateTime periodStart, ResetPeriod period) {
  switch (period) {
    case ResetPeriod.daily:
      return periodStart.add(const Duration(days: 1));
    case ResetPeriod.weekly:
      return periodStart.add(const Duration(days: 7));
    case ResetPeriod.biweekly:
      return periodStart.add(const Duration(days: 14));
    case ResetPeriod.monthly:
      return periodStart.add(const Duration(days: 30));
  }
}

/// Finds the current period start for a goal (the period containing [now] or the first period after goal start).
DateTime _currentPeriodStart(DateTime startDate, ResetPeriod period, DateTime now) {
  if (now.isBefore(startDate)) return startDate;

  DateTime candidate = startDate;
  while (true) {
    final end = _periodEnd(candidate, period);
    if (now.isBefore(end)) return candidate;
    candidate = end;
  }
}

/// Validation per spec.
void _validateGoalInput({
  required String name,
  required DateTime startDate,
  required DateTime endDate,
  required int requiredCheckupsPerPeriod,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) throw Exception('Goal name cannot be empty');
  if (requiredCheckupsPerPeriod <= 0) {
    throw Exception('Required check-ins per period must be greater than 0');
  }
  if (!endDate.isAfter(startDate)) {
    throw Exception('End date must be after start date');
  }
  final oneYear = Duration(days: 365);
  if (endDate.difference(startDate) > oneYear) {
    throw Exception('End date must be within 1 year of start date');
  }
}

/// Creates a new goal for the current user.
Future<String> createGoal({
  required String name,
  required String description,
  required DateTime startDate,
  required DateTime endDate,
  required int requiredCheckupsPerPeriod,
  required ResetPeriod resetPeriod,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');

  _validateGoalInput(
    name: name,
    startDate: startDate,
    endDate: endDate,
    requiredCheckupsPerPeriod: requiredCheckupsPerPeriod,
  );

  final now = DateTime.now();
  final effectiveStart = startDate.isAfter(now) ? startDate : now;
  final periodStart = _currentPeriodStart(startDate, resetPeriod, effectiveStart);
  final periodEnd = _periodEnd(periodStart, resetPeriod);

  final doc = await FirestoreRefs.userGoals(user.uid).add({
    'userId': user.uid,
    'name': name.trim(),
    'description': description.trim(),
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'requiredCheckupsPerPeriod': requiredCheckupsPerPeriod,
    'resetPeriod': resetPeriod.toFirestore(),
    'currentCheckupsCompleted': 0,
    'currentPeriodStart': Timestamp.fromDate(periodStart),
    'currentPeriodEnd': Timestamp.fromDate(periodEnd),
    'status': GoalStatus.active.toFirestore(),
    'periodHistory': <Map<String, dynamic>>[],
    'createdAt': Timestamp.fromDate(now),
    'updatedAt': Timestamp.fromDate(now),
  });

  return doc.id;
}

/// Fetches a single goal by ID.
Future<Goal?> getGoal(String goalId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final doc =
      await FirestoreRefs.userGoals(user.uid).doc(goalId).get();
  if (!doc.exists || doc.data() == null) return null;

  return Goal.fromFirestore(doc.id, doc.data()!);
}

/// Updates an existing goal for the current user.
///
/// Edit behavior (v1):
/// - Past check-in history is cleared to keep current period logic consistent.
/// - Future check-ins follow the new reset period / date range.
Future<void> updateGoalForCurrentUser({
  required String goalId,
  required String name,
  required String description,
  required DateTime startDate,
  required DateTime endDate,
  required int requiredCheckupsPerPeriod,
  required ResetPeriod resetPeriod,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');

  _validateGoalInput(
    name: name,
    startDate: startDate,
    endDate: endDate,
    requiredCheckupsPerPeriod: requiredCheckupsPerPeriod,
  );

  final now = DateTime.now();
  final effectiveStart = startDate.isAfter(now) ? startDate : now;
  final periodStart = _currentPeriodStart(startDate, resetPeriod, effectiveStart);
  final periodEnd = _periodEnd(periodStart, resetPeriod);

  final status = endDate.isBefore(now) ? GoalStatus.archived : GoalStatus.active;

  await FirestoreRefs.userGoals(user.uid).doc(goalId).update({
    'name': name.trim(),
    'description': description.trim(),
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'requiredCheckupsPerPeriod': requiredCheckupsPerPeriod,
    'resetPeriod': resetPeriod.toFirestore(),
    'status': status.toFirestore(),
    'currentCheckupsCompleted': 0,
    'currentPeriodStart': Timestamp.fromDate(periodStart),
    'currentPeriodEnd': Timestamp.fromDate(periodEnd),
    'periodHistory': <Map<String, dynamic>>[],
    'updatedAt': Timestamp.fromDate(now),
  });
}

/// Stream of active goals for the current user.
Stream<List<Goal>> getActiveGoalsStream() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirestoreRefs.userGoals(user.uid)
      .where('status', isEqualTo: GoalStatus.active.toFirestore())
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => Goal.fromFirestore(d.id, d.data()))
          .toList());
}

/// Stream of all goals (active + archived) for the current user.
Stream<List<Goal>> getAllGoalsStream() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirestoreRefs.userGoals(user.uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => Goal.fromFirestore(d.id, d.data()))
          .toList());
}

/// Records a check-in. Updates Firestore and handles period reset if needed.
Future<void> checkIn(String goalId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');

  final ref = FirestoreRefs.userGoals(user.uid).doc(goalId);
  return FirebaseFirestore.instance.runTransaction((tx) async {
    final doc = await tx.get(ref);
    if (!doc.exists || doc.data() == null) throw Exception('Goal not found');

    final data = doc.data()!;
    final status = GoalStatus.fromString(data['status'] as String?);
    if (status == GoalStatus.archived) {
      throw Exception('Cannot check in to an archived goal');
    }

    final now = DateTime.now();
    final periodEndTs = data['currentPeriodEnd'] as Timestamp?;
    final periodEnd = periodEndTs?.toDate();
    final required = data['requiredCheckupsPerPeriod'] as int? ?? 1;
    int completed = data['currentCheckupsCompleted'] as int? ?? 0;

    final Map<String, dynamic> updates = {
      'updatedAt': Timestamp.fromDate(now),
    };

    if (periodEnd != null && now.isAfter(periodEnd)) {
      // Period has ended: save old period to history, start new period.
      // This check-in counts for the NEW period.
      final resetPeriod =
          ResetPeriod.fromString(data['resetPeriod'] as String?);
      final periodStart =
          (data['currentPeriodStart'] as Timestamp?)?.toDate() ?? now;
      final newPeriodStart = _periodEnd(periodStart, resetPeriod);
      final newPeriodEnd = _periodEnd(newPeriodStart, resetPeriod);

      final hist = List<Map<String, dynamic>>.from(
          (data['periodHistory'] as List<dynamic>?) ?? []);
      hist.add({
        'periodStart': Timestamp.fromDate(periodStart),
        'periodEnd': periodEndTs!,
        'requiredCheckups': required,
        'completedCheckups': completed,
      });

      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      final shouldArchive = endDate != null && now.isAfter(endDate);

      updates['currentPeriodStart'] = Timestamp.fromDate(newPeriodStart);
      updates['currentPeriodEnd'] = Timestamp.fromDate(newPeriodEnd);
      updates['currentCheckupsCompleted'] = 1;
      updates['periodHistory'] = hist;
      if (shouldArchive) {
        updates['status'] = GoalStatus.archived.toFirestore();
      }
    } else {
      if (completed >= required) {
        throw Exception('Already completed required check-ins for this period');
      }
      updates['currentCheckupsCompleted'] = completed + 1;
    }

    tx.update(ref, updates);
  });
}

/// Removes the most recent check-in. Does not roll back completed periods.
Future<void> uncheckIn(String goalId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');

  final ref = FirestoreRefs.userGoals(user.uid).doc(goalId);
  return FirebaseFirestore.instance.runTransaction((tx) async {
    final doc = await tx.get(ref);
    if (!doc.exists || doc.data() == null) throw Exception('Goal not found');

    final status = GoalStatus.fromString(doc.data()!['status'] as String?);
    if (status == GoalStatus.archived) {
      throw Exception('Cannot uncheck an archived goal');
    }

    int completed = doc.data()!['currentCheckupsCompleted'] as int? ?? 0;
    if (completed <= 0) throw Exception('No check-ins to remove');

    tx.update(ref, {
      'currentCheckupsCompleted': completed - 1,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  });
}

/// Marks a goal as archived.
Future<void> archiveGoal(String goalId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');

  await FirestoreRefs.userGoals(user.uid).doc(goalId).update({
    'status': GoalStatus.archived.toFirestore(),
    'updatedAt': Timestamp.fromDate(DateTime.now()),
  });
}
