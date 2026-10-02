import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/comment.dart';
import 'json_reader.dart';

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
    final d = Json.of(doc.data());
    final rating = d.dblOrNull('rating');
    return CommentModel(
      id: doc.id,
      shopId: d.str('shopId'),
      userId: d.str('userId'),
      userName: d.strOrNull('userName') ?? 'Anonim',
      userPhotoUrl: _photo(d.raw['userPhotoUrl']),
      text: d.str('text').trim(),
      rating: rating?.clamp(1, 5).toDouble(),
      // Pending serverTimestamp() reads back as null on the writer's device.
      createdAt: d.date('createdAt') ?? DateTime.now(),
    );
  }

  static String? _photo(Object? v) {
    final u = Json.url(v);
    return u.isEmpty ? null : u;
  }
}
