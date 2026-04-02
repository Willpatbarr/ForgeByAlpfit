import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/firebase/firestore_refs.dart';
import 'friends_service.dart';

String _threadIdForPair(String a, String b) {
  final ordered = [a, b]..sort();
  return '${ordered.first}__${ordered.last}';
}

/// Public thread id for the current user and [otherUid] (for deletes / navigation).
String directThreadIdForPair(String currentUid, String otherUid) {
  return _threadIdForPair(currentUid, otherUid);
}

Future<bool> _isFriend(String currentUid, String otherUid) async {
  final doc = await FirestoreRefs.userDoc(currentUid).get();
  final friendIds = (doc.data()?['friendIds'] as List<dynamic>?)
          ?.whereType<String>()
          .toSet() ??
      <String>{};
  return friendIds.contains(otherUid);
}

Future<bool> _isGymAccount(String uid) async {
  final doc = await FirestoreRefs.userDoc(uid).get();
  final accountType = doc.data()?['accountType'] as String?;
  return accountType == 'gym';
}

Future<bool> _isGymMember({
  required String gymUid,
  required String userUid,
}) async {
  final gymDoc = await FirestoreRefs.userDoc(gymUid).get();
  final memberIds = (gymDoc.data()?['memberUserIds'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toSet() ??
      <String>{};
  return memberIds.contains(userUid);
}

/// True if the current user may send normal (non–friend-request) chats to [otherUid].
Future<bool> canSendDirectChatTo(String otherUid) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || otherUid.isEmpty || otherUid == uid) return false;
  if (await _isFriend(uid, otherUid)) return true;
  if (await _isGymAccount(otherUid)) return true;
  if (await _isGymAccount(uid) &&
      await _isGymMember(gymUid: uid, userUid: otherUid)) {
    return true;
  }
  return false;
}

Future<String?> _currentDisplayName() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final doc = await FirestoreRefs.userDoc(uid).get();
  final name = doc.data()?['displayName'] as String?;
  return (name == null || name.trim().isEmpty) ? 'User' : name.trim();
}

Stream<List<Map<String, dynamic>>> getDirectMessagesStream(String otherUid) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  final threadId = _threadIdForPair(uid, otherUid);
  return FirestoreRefs.directThreadMessages(threadId)
      .orderBy('sentAt')
      .snapshots()
        .map(
        (snap) => snap.docs.map((d) {
          final m = d.data();
          return {
            'id': d.id,
            'senderUid': m['senderUid'] as String?,
            'senderName': m['senderName'] as String? ?? 'User',
            'text': m['text'] as String? ?? '',
            'sentAt': (m['sentAt'] as Timestamp?)?.toDate(),
            'messageKind': m['messageKind'] as String?,
            'eventId': m['eventId'] as String?,
            'eventOwnerUid': m['eventOwnerUid'] as String?,
            'recipientUid': m['recipientUid'] as String?,
          };
        }).toList(),
      );
}

/// Incoming friend request entries for the Social Friends tab (collection group).
class IncomingFriendRequest {
  IncomingFriendRequest({
    required this.messageId,
    required this.threadId,
    required this.requesterUid,
    required this.requesterName,
    required this.text,
    this.sentAt,
  });

  final String messageId;
  final String threadId;
  final String requesterUid;
  final String requesterName;
  final String text;
  final DateTime? sentAt;
}

Stream<List<IncomingFriendRequest>> getIncomingFriendRequestsStream() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  return FirestoreRefs.directThreads
      .where('participants', arrayContains: uid)
      .snapshots()
      .asyncMap((threadsSnap) async {
    final list = <IncomingFriendRequest>[];
    for (final threadDoc in threadsSnap.docs) {
      final threadId = threadDoc.id;
      final msgs = await FirestoreRefs.directThreadMessages(threadId)
          .where('messageKind', isEqualTo: 'friend_request')
          .where('recipientUid', isEqualTo: uid)
          .get();

      for (final d in msgs.docs) {
        final m = d.data();
        list.add(
          IncomingFriendRequest(
            messageId: d.id,
            threadId: threadId,
            requesterUid: (m['senderUid'] as String?) ?? '',
            requesterName:
                (m['senderName'] as String?)?.trim().isNotEmpty == true
                    ? (m['senderName'] as String).trim()
                    : 'User',
            text: (m['text'] as String?) ?? '',
            sentAt: (m['sentAt'] as Timestamp?)?.toDate(),
          ),
        );
      }
    }
    list.sort((a, b) {
      final ta = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return list;
  });
}

Future<void> sendFriendRequestDm(String recipientUid) async {
  final senderUid = FirebaseAuth.instance.currentUser?.uid;
  if (senderUid == null) throw Exception('Not signed in');
  if (recipientUid.isEmpty || recipientUid == senderUid) {
    throw Exception('Invalid user');
  }
  if (await areFriendsWith(recipientUid)) {
    throw Exception('You are already friends');
  }
  if (await _isGymAccount(recipientUid)) {
    throw Exception('Use Join to connect with gym accounts');
  }

  final threadId = _threadIdForPair(senderUid, recipientUid);
  final existingReq = await FirestoreRefs.directThreadMessages(threadId)
      .where('messageKind', isEqualTo: 'friend_request')
      .where('senderUid', isEqualTo: senderUid)
      .limit(1)
      .get();
  if (existingReq.docs.isNotEmpty) {
    throw Exception('Friend request already sent');
  }

  final senderName = await _currentDisplayName() ?? 'User';
  final text = '$senderName would like to be friends with you.';
  final now = Timestamp.now();
  final threadRef = FirestoreRefs.directThreadDoc(threadId);
  final participants = [senderUid, recipientUid]..sort();

  await threadRef.set(
    {
      'participants': participants,
      'lastMessage': text,
      'lastSenderUid': senderUid,
      'lastMessageAt': now,
      'unreadCounts': {senderUid: 0},
      'updatedAt': now,
      'createdAt': now,
    },
    SetOptions(merge: true),
  );

  await threadRef.update({
    'unreadCounts.$recipientUid': FieldValue.increment(1),
  });

  await FirestoreRefs.directThreadMessages(threadId).add({
    'senderUid': senderUid,
    'senderName': senderName,
    'text': text,
    'sentAt': now,
    'messageKind': 'friend_request',
    'recipientUid': recipientUid,
  });
}

Future<void> acceptIncomingFriendRequest({
  required String requesterUid,
  required String threadId,
  required String messageId,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('Not signed in');
  if (requesterUid.isEmpty) throw Exception('Invalid request');

  await acceptFriendBidirectional(requesterUid: requesterUid);
  await FirestoreRefs.directThreadMessages(threadId).doc(messageId).delete();
}

Future<void> declineIncomingFriendRequest({
  required String threadId,
  required String messageId,
}) async {
  await FirestoreRefs.directThreadMessages(threadId).doc(messageId).delete();
}

Stream<Map<String, int>> getDirectUnreadCountsStream() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const {});

  return FirestoreRefs.directThreads
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((snap) {
    final out = <String, int>{};
    for (final d in snap.docs) {
      final m = d.data();
      final participants =
          (m['participants'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const <String>[];
      if (!participants.contains(uid) || participants.length < 2) continue;
      final other = participants.firstWhere((p) => p != uid, orElse: () => '');
      if (other.isEmpty) continue;

      final unreadRaw = m['unreadCounts'] as Map<String, dynamic>?;
      final count = (unreadRaw?[uid] as num?)?.toInt() ?? 0;
      out[other] = count;
    }
    return out;
  });
}

Future<void> markDirectThreadAsRead(String otherUid) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  final threadId = _threadIdForPair(uid, otherUid);
  final ref = FirestoreRefs.directThreadDoc(threadId);
  final doc = await ref.get();
  if (!doc.exists || doc.data() == null) return;

  final participants = (doc.data()!['participants'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toSet() ??
      <String>{};
  if (!participants.contains(uid)) return;

  await ref.update({
    'unreadCounts.$uid': 0,
    'updatedAt': Timestamp.now(),
  });
}

Future<void> sendDirectMessage({
  required String recipientUid,
  required String text,
  String? messageKind,
  String? eventId,
  String? eventOwnerUid,
}) async {
  final senderUid = FirebaseAuth.instance.currentUser?.uid;
  if (senderUid == null) throw Exception('Not signed in');
  if (recipientUid == senderUid) throw Exception('Cannot message yourself');

  final trimmed = text.trim();
  if (trimmed.isEmpty) throw Exception('Message cannot be empty');

  final isFriend = await _isFriend(senderUid, recipientUid);
  final isGym = await _isGymAccount(recipientUid);
  final senderIsGym = await _isGymAccount(senderUid);
  final recipientIsMember = senderIsGym
      ? await _isGymMember(gymUid: senderUid, userUid: recipientUid)
      : false;

  if (!isFriend && !isGym && !recipientIsMember) {
    throw Exception(
      'You can only message friends, your gyms, or members if you are a gym',
    );
  }

  final senderName = await _currentDisplayName() ?? 'User';
  final now = Timestamp.now();
  final threadId = _threadIdForPair(senderUid, recipientUid);

  final threadRef = FirestoreRefs.directThreadDoc(threadId);
  final participants = [senderUid, recipientUid]..sort();

  // Write order matters for Firestore rules:
  // message create checks that parent thread already exists.
  try {
    await threadRef.set(
      {
        'participants': participants,
        'lastMessage': trimmed,
        'lastSenderUid': senderUid,
        'lastMessageAt': now,
        'unreadCounts': {
          senderUid: 0,
        },
        'updatedAt': now,
        'createdAt': now,
      },
      SetOptions(merge: true),
    );
  } on FirebaseException catch (e) {
    throw Exception('DM thread set failed: ${e.message ?? e.code}');
  }

  try {
    await threadRef.update({
      'unreadCounts.$recipientUid': FieldValue.increment(1),
    });
  } on FirebaseException catch (e) {
    throw Exception('DM unread update failed: ${e.message ?? e.code}');
  }

  try {
    final payload = <String, dynamic>{
      'senderUid': senderUid,
      'senderName': senderName,
      'text': trimmed,
      'sentAt': now,
    };
    if (messageKind != null) {
      payload['messageKind'] = messageKind;
    }
    if (eventId != null) {
      payload['eventId'] = eventId;
    }
    if (eventOwnerUid != null) {
      payload['eventOwnerUid'] = eventOwnerUid;
    }
    await FirestoreRefs.directThreadMessages(threadId).add(payload);
  } on FirebaseException catch (e) {
    throw Exception('DM message create failed: ${e.message ?? e.code}');
  }
}

String _formatEventInviteDate(DateTime? dt) {
  if (dt == null) return 'TBD';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final suffix = dt.hour >= 12 ? 'PM' : 'AM';
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$m $suffix';
}

/// Sends one DM per invitee after an event is created. Invitees are expected
/// to be friends (same as the event creator UI). Individual failures are logged only.
Future<void> sendEventInviteDirectMessages({
  required List<String> inviteeIds,
  required String eventName,
  required DateTime? eventStart,
  required String eventId,
  required String eventOwnerUid,
}) async {
  if (FirebaseAuth.instance.currentUser == null) return;
  if (inviteeIds.isEmpty) return;
  final trimmedTitle = eventName.trim();
  if (trimmedTitle.isEmpty) return;
  if (eventId.trim().isEmpty || eventOwnerUid.trim().isEmpty) return;

  final inviterName = await _currentDisplayName() ?? 'Someone';
  final eventDateStr = _formatEventInviteDate(eventStart);
  final text =
      '$inviterName has invited you to $trimmedTitle at $eventDateStr';

  final seen = <String>{};
  for (final raw in inviteeIds) {
    final uid = raw.trim();
    if (uid.isEmpty || seen.contains(uid)) continue;
    seen.add(uid);
    try {
      await sendDirectMessage(
        recipientUid: uid,
        text: text,
        messageKind: 'event_invite',
        eventId: eventId.trim(),
        eventOwnerUid: eventOwnerUid.trim(),
      );
    } catch (e, st) {
      debugPrint('sendEventInviteDirectMessages failed for $uid: $e\n$st');
    }
  }
}
