import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/comment.dart';

class CommentModel extends Comment {
  const CommentModel({
    required super.id,
    required super.shopId,
    required super.userId,
    required super.userName,
    super.userPhotoUrl,
    required super.text,
    super.rating,
    required super.createdAt,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      shopId: d['shopId'] ?? '',
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? 'Anonim',
      userPhotoUrl: d['userPhotoUrl'],
      text: d['text'] ?? '',
      rating: (d['rating'] as num?)?.toDouble(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
