import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/comment.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/comment/comment_bloc.dart';
import '../ui/buttons.dart';
import '../ui/common.dart';

/// Shop reviews: rating summary, composer (or login prompt), list.
class CommentSection extends StatefulWidget {
  final String shopId;
  const CommentSection({super.key, required this.shopId});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _textCtrl = TextEditingController();
  double _rating = 5.0;
  String? _lastSent;
  StreamSubscription<String>? _failures;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<CommentBloc>()..add(CommentWatch(widget.shopId));
    _failures = bloc.failures.listen((msg) {
      if (!mounted) return;
      // Give the user their review back instead of silently losing it.
      if (_lastSent != null && _textCtrl.text.isEmpty) _textCtrl.text = _lastSent!;
      _lastSent = null;
      showAppSnack(context, msg, error: true);
    });
  }

  @override
  void dispose() {
    _failures?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit(AuthAuthenticated auth) {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _lastSent = text;
    context.read<CommentBloc>().add(CommentAdd(
          shopId: widget.shopId,
          userId: auth.user.uid,
          userName: auth.user.displayName,
          userPhotoUrl: auth.user.photoUrl,
          text: text,
          rating: _rating,
        ));
    _textCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlocBuilder<CommentBloc, CommentState>(
          builder: (context, state) {
            if (state is CommentLoaded && state.comments.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _Summary(comments: state.comments),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, auth) => auth is AuthAuthenticated
              ? _composer(auth)
              : _loginPrompt(context),
        ),
        const SizedBox(height: 14),
        BlocBuilder<CommentBloc, CommentState>(
          builder: (context, state) {
            if (state is CommentLoading) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state is CommentLoaded) {
              if (state.comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Belum ada review. Jadi yang pertama!',
                      textAlign: TextAlign.center, style: AppTextStyles.meta),
                );
              }
              return Column(children: [
                for (final c in state.comments)
                  _CommentCard(comment: c, shopId: widget.shopId),
              ]);
            }
            if (state is CommentError) {
              return InlineError(
                state.message,
                onRetry: () => context
                    .read<CommentBloc>()
                    .add(CommentWatch(widget.shopId)),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _composer(AuthAuthenticated auth) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rating kamu', style: AppTextStyles.meta),
            const SizedBox(height: 6),
            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              itemCount: 5,
              itemSize: 28,
              itemBuilder: (_, __) =>
                  const Icon(Icons.star_rounded, color: AppColors.star),
              onRatingUpdate: (r) => setState(() => _rating = r),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              maxLines: 3,
              minLines: 2,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                hintText: 'Tulis review kamu…',
                fillColor: AppColors.surfaceAlt,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 120,
                child: PrimaryButton(
                    label: 'Kirim', height: 44, onPressed: () => _submit(auth)),
              ),
            ),
          ],
        ),
      );

  Widget _loginPrompt(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Masuk untuk kasih review', style: AppTextStyles.meta),
          ),
          SizedBox(
            width: 88,
            child: PrimaryButton(
              label: 'Masuk',
              height: 38,
              onPressed: () => context.push(AppRouter.login),
            ),
          ),
        ]),
      );
}

class _Summary extends StatelessWidget {
  final List<Comment> comments;
  const _Summary({required this.comments});

  @override
  Widget build(BuildContext context) {
    final rated = comments.where((c) => c.rating != null).toList();
    if (rated.isEmpty) return const SizedBox.shrink();
    final avg = rated.map((c) => c.rating!).reduce((a, b) => a + b) / rated.length;
    final dist = List<int>.filled(5, 0);
    for (final c in rated) {
      dist[(c.rating!.round().clamp(1, 5)) - 1]++;
    }
    final maxCount = dist.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Column(children: [
          Text(avg.toStringAsFixed(1),
              style: AppTextStyles.display.copyWith(fontSize: 36)),
          Row(children: [
            for (var i = 0; i < 5; i++)
              Icon(Icons.star_rounded,
                  size: 12,
                  color: i < avg.round() ? AppColors.star : AppColors.textMuted),
          ]),
          const SizedBox(height: 2),
          Text('${rated.length} review',
              style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted)),
        ]),
        const SizedBox(width: 20),
        Expanded(
          child: Column(children: [
            for (var s = 5; s >= 1; s--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Text('$s',
                      style: AppTextStyles.meta
                          .copyWith(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: maxCount == 0 ? 0 : dist[s - 1] / maxCount,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceAlt,
                        color: s >= 4 ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Comment comment;
  final String shopId;
  const _CommentCard({required this.comment, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final canDelete = auth is AuthAuthenticated &&
        (auth.user.uid == comment.userId || auth.user.isAdmin);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            UserAvatar(url: comment.userPhotoUrl, name: comment.userName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comment.userName,
                      style: AppTextStyles.body
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(Fmt.timeAgo(comment.createdAt),
                      style: AppTextStyles.meta
                          .copyWith(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (comment.rating != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.star_rounded, size: 12, color: AppColors.star),
                  const SizedBox(width: 3),
                  Text(comment.rating!.toStringAsFixed(1),
                      style: AppTextStyles.meta.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            if (canDelete)
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted, size: 18),
                onPressed: () => context.read<CommentBloc>().add(
                    CommentDelete(shopId: shopId, commentId: comment.id)),
              ),
          ]),
          const SizedBox(height: 10),
          Text(comment.text,
              style: AppTextStyles.body
                  .copyWith(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
