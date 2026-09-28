import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/comment.dart';
import '../../../domain/repositories/comment_repository.dart';

// Events
abstract class CommentEvent extends Equatable {
  const CommentEvent();
  @override
  List<Object?> get props => [];
}

class CommentWatch extends CommentEvent {
  final String shopId;
  const CommentWatch(this.shopId);
  @override
  List<Object?> get props => [shopId];
}

class CommentAdd extends CommentEvent {
  final String shopId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String text;
  final double? rating;

  const CommentAdd({
    required this.shopId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.text,
    this.rating,
  });

  @override
  List<Object?> get props => [shopId, text];
}

class CommentDelete extends CommentEvent {
  final String shopId;
  final String commentId;
  const CommentDelete({required this.shopId, required this.commentId});
  @override
  List<Object?> get props => [shopId, commentId];
}

class _CommentsUpdated extends CommentEvent {
  final List<Comment> comments;
  const _CommentsUpdated(this.comments);
  @override
  List<Object?> get props => [comments];
}

// States
abstract class CommentState extends Equatable {
  const CommentState();
  @override
  List<Object?> get props => [];
}

class CommentInitial extends CommentState {}
class CommentLoading extends CommentState {}

class CommentLoaded extends CommentState {
  final List<Comment> comments;
  const CommentLoaded(this.comments);
  @override
  List<Object?> get props => [comments];
}

class CommentError extends CommentState {
  final String message;
  const CommentError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class CommentBloc extends Bloc<CommentEvent, CommentState> {
  final CommentRepository _repository;
  StreamSubscription<List<Comment>>? _subscription;

  CommentBloc({required CommentRepository repository})
      : _repository = repository,
        super(CommentInitial()) {
    on<CommentWatch>(_onWatch);
    on<CommentAdd>(_onAdd);
    on<CommentDelete>(_onDelete);
    on<_CommentsUpdated>(_onUpdated);
  }

  Future<void> _onWatch(CommentWatch event, Emitter<CommentState> emit) async {
    emit(CommentLoading());
    _subscription?.cancel();
    _subscription = _repository.watchComments(event.shopId).listen(
      (comments) => add(_CommentsUpdated(comments)),
      onError: (e) => emit(CommentError(e.toString())),
    );
  }

  void _onUpdated(_CommentsUpdated event, Emitter<CommentState> emit) {
    emit(CommentLoaded(event.comments));
  }

  Future<void> _onAdd(CommentAdd event, Emitter<CommentState> emit) async {
    await _repository.addComment(
      shopId: event.shopId,
      userId: event.userId,
      userName: event.userName,
      userPhotoUrl: event.userPhotoUrl,
      text: event.text,
      rating: event.rating,
    );
    // Stream auto-updates via _CommentsUpdated
  }

  Future<void> _onDelete(
      CommentDelete event, Emitter<CommentState> emit) async {
    await _repository.deleteComment(
      shopId: event.shopId,
      commentId: event.commentId,
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
