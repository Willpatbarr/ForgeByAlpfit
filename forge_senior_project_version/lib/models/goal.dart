import 'package:cloud_firestore/cloud_firestore.dart';

/// Reset period for a goal. Stored as string in Firestore.
enum ResetPeriod {
  daily,
  weekly,
  biweekly,
  monthly;

  static ResetPeriod fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'daily':
        return ResetPeriod.daily;
      case 'weekly':
        return ResetPeriod.weekly;
      case 'biweekly':
        return ResetPeriod.biweekly;
      case 'monthly':
        return ResetPeriod.monthly;
      default:
        return ResetPeriod.weekly;
    }
  }

  String toFirestore() => name;
}

/// Status of a goal. Stored as string in Firestore.
enum GoalStatus {
  active,
  archived;

  static GoalStatus fromString(String? s) =>
      s == 'archived' ? GoalStatus.archived : GoalStatus.active;

  String toFirestore() => name;
}

/// Record of a completed goal period (for history).
class GoalPeriodRecord {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int requiredCheckups;
  final int completedCheckups;

  const GoalPeriodRecord({
    required this.periodStart,
    required this.periodEnd,
    required this.requiredCheckups,
    required this.completedCheckups,
  });

  double get completionRate =>
      requiredCheckups == 0 ? 0 : completedCheckups / requiredCheckups;

  Map<String, dynamic> toJson() => {
        'periodStart': Timestamp.fromDate(periodStart),
        'periodEnd': Timestamp.fromDate(periodEnd),
        'requiredCheckups': requiredCheckups,
        'completedCheckups': completedCheckups,
      };

  factory GoalPeriodRecord.fromJson(Map<String, dynamic> m) {
    return GoalPeriodRecord(
      periodStart: (m['periodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodEnd: (m['periodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      requiredCheckups: m['requiredCheckups'] as int? ?? 0,
      completedCheckups: m['completedCheckups'] as int? ?? 0,
    );
  }
}

/// Goal data model. Business logic (period reset, archiving) lives in GoalService.
class Goal {
  final String id;
  final String userId;
  String name;
  String description;
  DateTime startDate;
  DateTime endDate;
  int requiredCheckupsPerPeriod;
  ResetPeriod resetPeriod;
  int currentCheckupsCompleted;
  DateTime currentPeriodStart;
  DateTime currentPeriodEnd;
  GoalStatus status;
  List<GoalPeriodRecord> periodHistory;
  DateTime createdAt;
  DateTime updatedAt;

  Goal({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.requiredCheckupsPerPeriod,
    required this.resetPeriod,
    required this.currentCheckupsCompleted,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.status,
    required this.periodHistory,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Progress within the current period (0.0 to 1.0).
  double get currentProgress =>
      requiredCheckupsPerPeriod == 0
          ? 0
          : (currentCheckupsCompleted / requiredCheckupsPerPeriod).clamp(0.0, 1.0);

  /// Overall completion rate across all completed periods.
  double get overallCompletionRate {
    if (periodHistory.isEmpty) return currentProgress;
    final totalRequired =
        periodHistory.fold<int>(0, (s, r) => s + r.requiredCheckups);
    final totalCompleted =
        periodHistory.fold<int>(0, (s, r) => s + r.completedCheckups);
    if (totalRequired == 0) return 0;
    return totalCompleted / totalRequired;
  }

  bool get isCurrentPeriodComplete =>
      currentCheckupsCompleted >= requiredCheckupsPerPeriod &&
      requiredCheckupsPerPeriod > 0;

  bool get isActive => status == GoalStatus.active;
  bool get isArchived => status == GoalStatus.archived;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'description': description,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'requiredCheckupsPerPeriod': requiredCheckupsPerPeriod,
        'resetPeriod': resetPeriod.toFirestore(),
        'currentCheckupsCompleted': currentCheckupsCompleted,
        'currentPeriodStart': Timestamp.fromDate(currentPeriodStart),
        'currentPeriodEnd': Timestamp.fromDate(currentPeriodEnd),
        'status': status.toFirestore(),
        'periodHistory': periodHistory.map((r) => r.toJson()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  static DateTime _timestampToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }

  factory Goal.fromFirestore(String id, Map<String, dynamic> data) {
    final hist = (data['periodHistory'] as List<dynamic>?)
            ?.map((e) => GoalPeriodRecord.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    return Goal(
      id: id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      startDate: _timestampToDate(data['startDate']),
      endDate: _timestampToDate(data['endDate']),
      requiredCheckupsPerPeriod:
          data['requiredCheckupsPerPeriod'] as int? ?? 1,
      resetPeriod: ResetPeriod.fromString(data['resetPeriod'] as String?),
      currentCheckupsCompleted: data['currentCheckupsCompleted'] as int? ?? 0,
      currentPeriodStart: _timestampToDate(data['currentPeriodStart']),
      currentPeriodEnd: _timestampToDate(data['currentPeriodEnd']),
      status: GoalStatus.fromString(data['status'] as String?),
      periodHistory: hist,
      createdAt: _timestampToDate(data['createdAt']),
      updatedAt: _timestampToDate(data['updatedAt']),
    );
  }
}
