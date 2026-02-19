import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase/firestore_refs.dart';

/// Filter for search: all accounts, users only, or gyms only.
enum SearchFilter { all, users, gyms }

/// Result item for search list: name, isGym, uid, and optional avatar/contact.
Map<String, dynamic> _docToResult(DocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data();
  if (d == null) return {};
  final accountType = d['accountType'] as String? ?? 'user';
  final isGym = accountType == 'gym';
  return {
    'uid': doc.id,
    'name': d['displayName'] as String? ?? 'Unknown',
    'isGym': isGym,
    'avatar': d['avatarUrl'] as String?,
    'contactInfo': d['contactInfo'] as String?,
  };
}

/// Search users and gyms by display name (prefix, case-insensitive).
/// Fetches users from Firestore and filters in memory so existing docs
/// without displayNameLower still show up. Limited to 100 docs for now.
Future<List<Map<String, dynamic>>> searchUsersAndGyms({
  required String query,
  SearchFilter filter = SearchFilter.all,
  int limit = 30,
}) async {
  final term = query.trim();
  if (term.isEmpty) return [];
  final termLower = term.toLowerCase();
  final currentUid = FirebaseAuth.instance.currentUser?.uid;

  // Fetch recent users (no index on displayName required). Cap at 100 for now.
  final snapshot = await FirestoreRefs.users.limit(100).get();

  var list = snapshot.docs
      .map(_docToResult)
      .where((r) => r.isNotEmpty)
      .where((r) {
        final name = (r['name'] as String?) ?? '';
        if (!name.toLowerCase().contains(termLower)) return false;
        if (currentUid != null && r['uid'] == currentUid) return false;
        switch (filter) {
          case SearchFilter.users:
            if (r['isGym'] == true) return false;
            break;
          case SearchFilter.gyms:
            if (r['isGym'] != true) return false;
            break;
          case SearchFilter.all:
            break;
        }
        return true;
      })
      .take(limit)
      .toList();

  return list;
}
