import 'package:dartz/dartz.dart';
import '../../core/utils/failures.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';
import '../datasources/comment_remote_datasource.dart';

class CommentRepositoryImpl implements CommentRepository {
  final CommentRemoteDataSource remoteDataSource;

  CommentRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<Comment>> watchComments(String shopId) {
    return remoteDataSource.watchComments(shopId);
  }

  @override
  Future<Either<Failure, void>> addComment({
    required String shopId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
    double? rating,
  }) async {
    try {
      await remoteDataSource.addComment(
        shopId: shopId,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        text: text,
        rating: rating,
      );
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menyimpan review. Coba lagi.'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment({
    required String shopId,
    required String commentId,
  }) async {
    try {
      await remoteDataSource.deleteComment(
          shopId: shopId, commentId: commentId);
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menyimpan review. Coba lagi.'));
    }
  }
}
