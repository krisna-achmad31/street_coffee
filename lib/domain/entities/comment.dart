import 'package:equatable/equatable.dart';

class Comment extends Equatable {
  final String id;
  final String shopId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String text;
  final double? rating;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.text,
    this.rating,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}
