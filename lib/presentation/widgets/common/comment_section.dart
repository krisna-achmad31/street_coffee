import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/entities/comment.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/comment/comment_bloc.dart';

class CommentSection extends StatefulWidget {
  final String shopId;
  const CommentSection({super.key, required this.shopId});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _textCtrl = TextEditingController();
  double _rating = 5.0;

  @override
  void initState() {
    super.initState();
    context.read<CommentBloc>().add(CommentWatch(widget.shopId));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submitComment(AuthAuthenticated authState) {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    context.read<CommentBloc>().add(CommentAdd(
          shopId: widget.shopId,
          userId: authState.user.uid,
          userName: authState.user.displayName,
          userPhotoUrl: authState.user.photoUrl,
          text: text,
          rating: _rating,
        ));

    _textCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & Komentar', style: AppTextStyles.headingSmall),
        const SizedBox(height: 16),

        // Input — only if logged in
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is AuthAuthenticated) {
              return _buildCommentInput(authState);
            }
            return _buildLoginPrompt();
          },
        ),

        const SizedBox(height: 20),

        // Comments list
        BlocBuilder<CommentBloc, CommentState>(
          builder: (context, state) {
            if (state is CommentLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            if (state is CommentLoaded) {
              if (state.comments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Belum ada review. Jadi yang pertama!',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                );
              }
              return Column(
                children: state.comments
                    .map((c) => _CommentCard(
                          comment: c,
                          shopId: widget.shopId,
                        ))
                    .toList(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildCommentInput(AuthAuthenticated authState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating
          Text('Rating kamu:', style: AppTextStyles.bodySmall),
          const SizedBox(height: 6),
          RatingBar.builder(
            initialRating: _rating,
            minRating: 1,
            direction: Axis.horizontal,
            itemCount: 5,
            itemSize: 28,
            itemBuilder: (_, __) => const Icon(
              Icons.star_rounded,
              color: AppColors.star,
            ),
            onRatingUpdate: (r) => setState(() => _rating = r),
          ),
          const SizedBox(height: 12),
          // Text input
          TextField(
            controller: _textCtrl,
            style: AppTextStyles.bodyMedium,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tulis review kamu...',
              hintStyle:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.bgCardAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _submitComment(authState),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Kirim', style: AppTextStyles.button),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Login dengan Google untuk kasih review',
              style: AppTextStyles.bodySmall,
            ),
          ),
          GestureDetector(
            onTap: () =>
                context.read<AuthBloc>().add(AuthSignInGoogle()),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Login', style: AppTextStyles.button.copyWith(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Comment comment;
  final String shopId;
  const _CommentCard({required this.comment, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final isOwner = authState is AuthAuthenticated &&
        authState.user.uid == comment.userId;
    final isAdmin = authState is AuthAuthenticated && authState.user.isAdmin;
    final canDelete = isOwner || isAdmin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: comment.userPhotoUrl != null
                      ? NetworkImage(comment.userPhotoUrl!)
                      : null,
                  backgroundColor: AppColors.bgCardAlt,
                  child: comment.userPhotoUrl == null
                      ? Text(
                          comment.userName[0].toUpperCase(),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.userName,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      Text(
                        DateFormat('d MMM yyyy').format(comment.createdAt),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                if (comment.rating != null)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppColors.star, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        comment.rating!.toStringAsFixed(1),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.textMuted, size: 18),
                    onPressed: () {
                      context.read<CommentBloc>().add(CommentDelete(
                            shopId: shopId,
                            commentId: comment.id,
                          ));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(comment.text, style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}
