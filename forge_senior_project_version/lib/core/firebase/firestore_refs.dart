import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FirestoreRefs {
  static FirebaseFirestore get _store => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users =>
      _store.collection('users');

  static DocumentReference<Map<String, dynamic>> userDoc(String userId) =>
      users.doc(userId);

  /// Events created by a user. Doc: title, notes, eventType, isPublic, inviteeNames, startAt, endAt, exercises, createdAt.
  static CollectionReference<Map<String, dynamic>> userEvents(String userId) =>
      userDoc(userId).collection('events');

  /// Goals for a user. Doc: name, description, startDate, endDate, requiredCheckupsPerPeriod, resetPeriod, etc.
  static CollectionReference<Map<String, dynamic>> userGoals(String userId) =>
      userDoc(userId).collection('goals');

  /// Plans for a user. Doc: name, repeatWindowWeeks, startDate, endDate, linkedEvents, createdAt, etc.
  static CollectionReference<Map<String, dynamic>> userPlans(String userId) =>
      userDoc(userId).collection('plans');

  /// Posts in a gym's channel. Doc: channelName, authorUid, authorName, content, createdAt, likeIds.
  static CollectionReference<Map<String, dynamic>> channelPosts(String gymUid) =>
      userDoc(gymUid).collection('channelPosts');

  static DocumentReference<Map<String, dynamic>> channelPostDoc(
          String gymUid, String postId) =>
      channelPosts(gymUid).doc(postId);

  /// Comments on a channel post. Doc: authorUid, authorName, content, createdAt.
  static CollectionReference<Map<String, dynamic>> postComments(
          String gymUid, String postId) =>
      channelPostDoc(gymUid, postId).collection('comments');

  /// Direct message threads. Doc: participants, lastMessage, lastSenderUid, updatedAt, createdAt.
  static CollectionReference<Map<String, dynamic>> get directThreads =>
      _store.collection('directThreads');

  static DocumentReference<Map<String, dynamic>> directThreadDoc(
          String threadId) =>
      directThreads.doc(threadId);

  /// Messages in a direct thread. Doc: senderUid, senderName, text, sentAt.
  static CollectionReference<Map<String, dynamic>> directThreadMessages(
          String threadId) =>
      directThreadDoc(threadId).collection('messages');
}
