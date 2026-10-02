import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/comment.dart';
import '../../../domain/entities/social.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../../injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/common.dart';

Future<void> showDropComments(BuildContext context, Drop drop) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: _CommentsSheet(drop: drop),
      ),
    );

class _CommentsSheet extends StatefulWidget {
  final Drop drop;
  const _CommentsSheet({required this.drop});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _repo = sl<SocialRepository>();
  final _ctrl = TextEditingController();
  late final _comments$ = _repo.watchDropComments(widget.drop.id);
  bool _sending = false;

  static const _quick = [
    'Parkir aman? 🛵',
    'Rame jam berapa?',
    'Worth it! ☕',
    'Ada colokan?',
  ];

  Future<void> _send() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      context.push(AppRouter.login);
      return;
    }
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final r = await _repo.addDropComment(widget.drop.id, auth.user, text);
    if (!mounted) return;
    setState(() => _sending = false);
    r.fold((f) => showAppSnack(context, f.message, error: true), (_) => _ctrl.clear());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('${Fmt.compact(widget.drop.commentCount)} komentar',
              style: AppTextStyles.section.copyWith(fontSize: 17)),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<Comment>>(
            stream: _comments$,
            builder: (context, snap) {
              if (snap.hasError && !snap.hasData) {
                return const Center(
                    child: InlineError('Komentar gagal dimuat. Tutup lalu buka lagi.'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return Center(
                  child: Text('Belum ada komentar. Mulai obrolan!',
                      style: AppTextStyles.meta),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (_, i) {
                  final c = list[i];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(url: c.userPhotoUrl, name: c.userName),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(c.userName,
                                  style: AppTextStyles.body.copyWith(
                                      fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              Text(Fmt.timeAgo(c.createdAt),
                                  style: AppTextStyles.meta.copyWith(
                                      fontSize: 11, color: AppColors.textMuted)),
                            ]),
                            const SizedBox(height: 4),
                            Text(c.text,
                                style: AppTextStyles.body.copyWith(
                                    fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Column(children: [
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quick.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(_quick[i]),
                  labelStyle: AppTextStyles.meta,
                  backgroundColor: AppColors.surfaceAlt,
                  side: const BorderSide(color: AppColors.divider),
                  shape: const StadiumBorder(),
                  onPressed: () => setState(() => _ctrl.text = _quick[i]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              UserAvatar(
                url: auth is AuthAuthenticated ? auth.user.photoUrl : null,
                name: auth is AuthAuthenticated ? auth.user.displayName : '?',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'Tambah komentar…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(6),
                      child: IconButton.filled(
                        tooltip: 'Kirim',
                        style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.arrow_upward_rounded,
                            size: 16, color: AppColors.onPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ],
    );
  }
}

Future<void> showReportSheet(BuildContext context,
        {required Drop drop, required String reporterUid}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReportSheet(drop: drop, reporterUid: reporterUid),
    );

class _ReportSheet extends StatefulWidget {
  final Drop drop;
  final String reporterUid;
  const _ReportSheet({required this.drop, required this.reporterUid});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  bool _block = false;
  bool _sending = false;

  static const _labels = {
    ReportReason.spam: 'Spam atau promosi palsu',
    ReportReason.inappropriate: 'Konten tidak pantas',
    ReportReason.harassment: 'Pelecehan atau ujaran kebencian',
    ReportReason.wrongInfo: 'Informasi kedai salah',
    ReportReason.other: 'Lainnya',
  };

  Future<void> _submit() async {
    setState(() => _sending = true);
    final r = await sl<SocialRepository>().report(
      reporterUid: widget.reporterUid,
      targetType: 'drop',
      targetId: widget.drop.id,
      reason: _reason!,
      blockAuthor: _block,
      authorUid: widget.drop.userId,
    );
    if (!mounted) return;
    Navigator.pop(context);
    r.fold(
      (f) => showAppSnack(context, f.message, error: true),
      (_) => showAppSnack(context, 'Laporan terkirim. Kami tinjau dalam 24 jam.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Laporkan Drop ini', style: AppTextStyles.section),
          const SizedBox(height: 4),
          Text('Laporanmu anonim. Tim kami meninjau dalam 24 jam.',
              style: AppTextStyles.meta.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(children: [
                for (final e in _labels.entries)
                  RadioListTile<ReportReason>(
                    value: e.key,
                    title: Text(e.value, style: AppTextStyles.body),
                    controlAffinity: ListTileControlAffinity.trailing,
                    activeColor: AppColors.primary,
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              color: AppColors.closedSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.block_rounded, size: 16, color: AppColors.closed),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Blokir @${widget.drop.userHandle} juga',
                    style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.closed)),
              ),
              Switch(value: _block, onChanged: (v) => setState(() => _block = v)),
            ]),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Kirim laporan',
            icon: Icons.flag_rounded,
            background: AppColors.closed,
            foreground: AppColors.textPrimary,
            loading: _sending,
            onPressed: _reason == null ? null : _submit,
          ),
        ],
      ),
    );
  }
}
