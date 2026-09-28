import 'package:dartz/dartz.dart';
import '../../core/utils/failures.dart';
import '../entities/comment.dart';

abstract class CommentRepository {
  Stream<List<Comment>> watchComments(String shopId);
  Future<Either<Failure, void>> addComment({
    required String shopId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
    double? rating,
  });
  Future<Either<Failure, void>> deleteComment({
    required String shopId,
    required String commentId,
  });
}
