import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/firebase/firestore_refs.dart';
import '../firebase_options.dart';

/// Bumps so [AppHeader] rebuilds its profile chip after a new photo is saved.
class AvatarHeaderRefreshNotifier {
  AvatarHeaderRefreshNotifier._();

  static final ValueNotifier<int> version = ValueNotifier(0);

  static void bump() => version.value++;
}

/// In-memory avatar for the signed-in user (survives [ProfilePage] disposal when
/// switching shell routes — each navigation creates a new State).
class ProfileAvatarSessionCache {
  ProfileAvatarSessionCache._();
  static final ProfileAvatarSessionCache instance = ProfileAvatarSessionCache._();

  String? _uid;
  Uint8List? _bytes;
  String? _url;

  void clear() {
    _uid = null;
    _bytes = null;
    _url = null;
  }

  void putForUser({
    required String uid,
    Uint8List? bytes,
    String? url,
  }) {
    if (uid.isEmpty) return;
    if (_uid != uid) {
      _uid = uid;
      _bytes = null;
      _url = null;
    }
    if (bytes != null && bytes.isNotEmpty) _bytes = bytes;
    if (url != null && url.trim().isNotEmpty) _url = url.trim();
  }

  ({Uint8List? bytes, String? url})? snapshotFor(String uid) {
    if (uid.isEmpty || uid != _uid) return null;
    final b = _bytes;
    final u = _url;
    if ((b == null || b.isEmpty) && (u == null || u.isEmpty)) return null;
    return (bytes: b, url: u);
  }
}

FirebaseStorage get _profileAvatarStorage {
  final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
  if (bucket == null || bucket.isEmpty) return FirebaseStorage.instance;
  try {
    return FirebaseStorage.instanceFor(
      app: Firebase.app(),
      bucket: bucket,
    );
  } catch (_) {
    return FirebaseStorage.instance;
  }
}

/// [StorageReference] path: `avatars/{uid}/profile`.
Reference profileAvatarRef(String uid) => _profileAvatarStorage
    .ref()
    .child('avatars')
    .child(uid)
    .child('profile');

/// Result of loading the current profile image object from Storage.
class ProfileAvatarLoad {
  const ProfileAvatarLoad({this.bytes, this.downloadUrl});

  final Uint8List? bytes;
  final String? downloadUrl;
}

/// Loads avatar bytes and/or download URL from Storage.
///
/// [getData] can fail on web even when the object exists; this falls back to
/// an HTTP GET on the download URL to populate [bytes].
Future<ProfileAvatarLoad> loadProfileAvatarFromStorage(String uid) async {
  if (uid.isEmpty) return const ProfileAvatarLoad();

  final ref = profileAvatarRef(uid);

  late final String downloadUrl;
  try {
    downloadUrl = await ref.getDownloadURL();
  } catch (_) {
    return const ProfileAvatarLoad();
  }

  Uint8List? bytes;
  try {
    final raw = await ref.getData(15 * 1024 * 1024);
    if (raw != null && raw.isNotEmpty) bytes = raw;
  } catch (_) {}

  // When [getData] fails (common on web), GET the signed download URL. Requires
  // Storage bucket CORS to allow this origin (see storage-cors.json / gsutil).
  // Populating [bytes] avoids Flutter web quirks with [Image.network] on some builds.
  if (bytes == null && downloadUrl.isNotEmpty) {
    try {
      final res = await http.get(Uri.parse(downloadUrl));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        bytes = Uint8List.fromList(res.bodyBytes);
      }
    } catch (_) {}
  }

  return ProfileAvatarLoad(bytes: bytes, downloadUrl: downloadUrl);
}

/// Deduped in-flight loads + RAM cache for list avatars.
class AvatarBytesMemoryCache {
  AvatarBytesMemoryCache._();

  static final Map<String, Uint8List> _bytes = {};
  static final Map<String, String> _downloadUrlByUid = {};
  static final Map<String, Future<ProfileAvatarLoad>> _inFlight = {};

  /// Full load (bytes may be null on web; [ProfileAvatarLoad.downloadUrl] is still set).
  static Future<ProfileAvatarLoad> load(String uid) async {
    if (uid.isEmpty) return const ProfileAvatarLoad();
    final hit = _bytes[uid];
    final urlHit = _downloadUrlByUid[uid];
    if (hit != null && hit.isNotEmpty) {
      return ProfileAvatarLoad(bytes: hit, downloadUrl: urlHit);
    }
    final inflight = _inFlight[uid];
    if (inflight != null) return inflight;
    final f = loadProfileAvatarFromStorage(uid).then((loaded) {
      _inFlight.remove(uid);
      if (loaded.bytes != null && loaded.bytes!.isNotEmpty) {
        _bytes[uid] = loaded.bytes!;
      }
      final u = loaded.downloadUrl;
      if (u != null && u.isNotEmpty) {
        _downloadUrlByUid[uid] = u;
      }
      return loaded;
    });
    _inFlight[uid] = f;
    return f;
  }

  static Future<Uint8List?> get(String uid) async {
    final l = await load(uid);
    return l.bytes;
  }

  static void invalidate(String uid) {
    if (uid.isEmpty) return;
    _bytes.remove(uid);
    _downloadUrlByUid.remove(uid);
    _inFlight.remove(uid);
  }
}

/// Uploads bytes to Storage at `avatars/{uid}/profile` and writes [avatarUrl] on the user doc.
Future<String> uploadProfileAvatarBytes({
  required List<int> bytes,
  String contentType = 'image/jpeg',
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('Not signed in');
  if (bytes.isEmpty) throw Exception('Empty image');

  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final ref = profileAvatarRef(uid);
  await ref.putData(
    data,
    SettableMetadata(contentType: contentType),
  );
  final url = await ref.getDownloadURL();
  await FirestoreRefs.userDoc(uid).set(
    {
      'avatarUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
  AvatarBytesMemoryCache.invalidate(uid);
  AvatarHeaderRefreshNotifier.bump();
  return url;
}
