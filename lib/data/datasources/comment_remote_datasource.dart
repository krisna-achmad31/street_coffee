import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../core/constants/firebase_paths.dart';
import '../models/comment_model.dart';
import '../models/json_reader.dart';

abstract class CommentRemoteDataSource {
  Stream<List<CommentModel>> watchComments(String shopId);
  Future<void> addComment({
    required String shopId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
    double? rating,
  });
  Future<void> deleteComment({required String shopId, required String commentId});
}

class CommentRemoteDataSourceImpl implements CommentRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _rtdb;

  CommentRemoteDataSourceImpl({
    required FirebaseFirestore firestore,
    required FirebaseDatabase rtdb,
  })  : _firestore = firestore,
        _rtdb = rtdb;

  @override
  Stream<List<CommentModel>> watchComments(String shopId) {
    return _firestore
        .collection(FirebasePaths.shopComments(shopId))
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => parseEach(snap.docs, CommentModel.fromFirestore)
            .where((c) => c.text.isNotEmpty)
            .toList());
  }

  @override
  Future<void> addComment({
    required String shopId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
    double? rating,
  }) async {
    final ref = _firestore
        .collection(FirebasePaths.shopComments(shopId))
        .doc();

    await ref.set({
      'shopId': shopId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'rating': rating,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment RTDB counter
    await _bumpCounter(shopId, 1);
  }

  @override
  Future<void> deleteComment({
    required String shopId,
    required String commentId,
  }) async {
    await _firestore
        .collection(FirebasePaths.shopComments(shopId))
        .doc(commentId)
        .delete();

    await _bumpCounter(shopId, -1);
  }

  /// Best-effort: the review itself is already saved, so a denied or offline
  /// counter write must not surface as a failed review.
  Future<void> _bumpCounter(String shopId, int by) async {
    try {
      await _rtdb
          .ref(FirebasePaths.shopCommentCount(shopId))
          .set(ServerValue.increment(by));
    } catch (_) {}
  }
}
