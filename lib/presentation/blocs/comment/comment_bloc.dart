import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/failures.dart';
import '../../../domain/entities/comment.dart';
import '../../../domain/repositories/comment_repository.dart';
import '../transformers.dart';

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

  CommentBloc({required CommentRepository repository})
      : _repository = repository,
        super(CommentInitial()) {
    on<CommentWatch>(_onWatch, transformer: restartable);
    on<CommentAdd>(_onAdd);
    on<CommentDelete>(_onDelete);
  }

  Future<void> _onWatch(CommentWatch event, Emitter<CommentState> emit) async {
    emit(CommentLoading());
    // emit.forEach keeps emitting legal for the stream's lifetime; the old
    // listen(onError: emit) threw because the handler had already completed.
    await emit.forEach<List<Comment>>(
      _repository.watchComments(event.shopId),
      onData: CommentLoaded.new,
      onError: (e, _) => CommentError(Failure.from(e, 'Review gagal dimuat.').message),
    );
  }

  Future<void> _onAdd(CommentAdd event, Emitter<CommentState> emit) async {
    final r = await _repository.addComment(
      shopId: event.shopId,
      userId: event.userId,
      userName: event.userName,
      userPhotoUrl: event.userPhotoUrl,
      text: event.text,
      rating: event.rating,
    );
    // Success arrives through the watch stream; failures go to the UI once.
    r.fold((f) => _failures.add(f.message), (_) {});
  }

  Future<void> _onDelete(
      CommentDelete event, Emitter<CommentState> emit) async {
    final r = await _repository.deleteComment(
      shopId: event.shopId,
      commentId: event.commentId,
    );
    r.fold((f) => _failures.add(f.message), (_) {});
  }

  /// One-shot write errors (add/delete) — shown as a snackbar, without
  /// replacing the loaded list with an error state.
  final _failures = StreamController<String>.broadcast();
  Stream<String> get failures => _failures.stream;

  @override
  Future<void> close() {
    _failures.close();
    return super.close();
  }
}
