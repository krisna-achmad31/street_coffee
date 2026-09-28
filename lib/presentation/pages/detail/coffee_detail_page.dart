import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/firebase_paths.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../blocs/admin/admin_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/comment/comment_bloc.dart';
import '../../blocs/detail/detail_bloc.dart';
import '../../widgets/common/comment_section.dart';
import '../../../injection_container.dart';

class CoffeeDetailPage extends StatefulWidget {
  final String shopId;
  const CoffeeDetailPage({super.key, required this.shopId});

  @override
  State<CoffeeDetailPage> createState() => _CoffeeDetailPageState();
}

class _CoffeeDetailPageState extends State<CoffeeDetailPage> {
  bool _isRedirecting = false;
  String? _redirectMenuName;

  // Real-time isOpen from RTDB
  bool? _rtdbIsOpen;

  @override
  void initState() {
    super.initState();
    context.read<DetailBloc>().add(DetailLoadShop(widget.shopId));
    _listenRtdbPresence();
  }

  void _listenRtdbPresence() {
    FirebaseDatabase.instance
        .ref(FirebasePaths.shopPresence(widget.shopId))
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        setState(() => _rtdbIsOpen = data['isOpen'] as bool?);
      }
    });
  }

  Future<void> _openWhatsApp(CoffeeShop shop, {String? menuItem}) async {
    setState(() {
      _isRedirecting = true;
      _redirectMenuName = menuItem;
    });

    final message = WhatsAppLauncher.buildOrderMessage(
      shopName: shop.name,
      menuItem: menuItem,
    );

    final success = await WhatsAppLauncher.openChat(
      phone: shop.whatsappNumber,
      message: message,
    );

    if (mounted) {
      setState(() => _isRedirecting = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp tidak tersedia'),
            backgroundColor: AppColors.closed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<CommentBloc>()),
        BlocProvider(create: (_) => sl<AdminBloc>()),
      ],
      child: BlocBuilder<DetailBloc, DetailState>(
        builder: (context, state) {
          if (state is DetailLoading || state is DetailInitial) {
            return const Scaffold(
              backgroundColor: AppColors.bgDark,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          if (state is DetailError) {
            return Scaffold(
              backgroundColor: AppColors.bgDark,
              appBar: AppBar(backgroundColor: AppColors.bgDark),
              body: Center(child: Text(state.message)),
            );
          }
          if (state is DetailLoaded) return _buildDetail(state.shop);
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDetail(CoffeeShop shop) {
    final isOpen = _rtdbIsOpen ?? shop.isOpen;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Hero ─────────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppColors.bgDark,
                leading: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.overlay,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                actions: [
                  // Admin action button
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      if (authState is AuthAuthenticated &&
                          authState.user.isAdmin) {
                        return _buildAdminActions(shop);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: CachedNetworkImage(
                    imageUrl: shop.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.bgCard,
                      child: const Icon(Icons.coffee,
                          size: 64, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Name + Status ─────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(shop.name,
                                  style: AppTextStyles.headingLarge)),
                          _StatusBadge(isOpen: isOpen, openUntil: shop.openUntil),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: AppColors.textMuted, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(shop.address,
                                style: AppTextStyles.bodySmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Rating
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: AppColors.star, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${shop.rating} (${shop.reviewCount} reviews)',
                            style: AppTextStyles.bodySmall,
                          ),
                          if (shop.distanceKm != null) ...[
                            const SizedBox(width: 12),
                            Text(shop.distanceText,
                                style: AppTextStyles.bodySmall),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(shop.description,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary)),

                      const SizedBox(height: 20),
                      const Divider(color: AppColors.divider),
                      const SizedBox(height: 16),

                      // ── Fasilitas ─────────────────────────────────────────
                      Text('Vibe & Fasilitas',
                          style: AppTextStyles.headingSmall),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: shop.facilities
                            .map((f) => _FacilityItem(facility: f))
                            .toList(),
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: AppColors.divider),
                      const SizedBox(height: 16),

                      // ── Menu ──────────────────────────────────────────────
                      Text('Menu Favorit', style: AppTextStyles.headingSmall),
                      const SizedBox(height: 12),
                      if (shop.menuFavorites.isNotEmpty)
                        Row(
                          children: shop.menuFavorites
                              .take(4)
                              .map((menu) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap: () => _openWhatsApp(
                                          shop,
                                          menuItem: menu.name,
                                        ),
                                        child: Column(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: CachedNetworkImage(
                                                imageUrl: menu.imageUrl,
                                                height: 80,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    Container(
                                                  height: 80,
                                                  color: AppColors.bgCard,
                                                  child: const Icon(
                                                      Icons.local_cafe_outlined,
                                                      color:
                                                          AppColors.textMuted),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              menu.name,
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                      color: AppColors
                                                          .textPrimary),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        )
                      else
                        Text('Belum ada menu ditambahkan',
                            style: AppTextStyles.bodySmall),

                      // ── Sosmed ────────────────────────────────────────────
                      // TODO: render instagramUrl, tiktokUrl, googleMapsUrl if present

                      const SizedBox(height: 24),
                      const Divider(color: AppColors.divider),
                      const SizedBox(height: 16),

                      // ── Comments ──────────────────────────────────────────
                      CommentSection(shopId: shop.id),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // WhatsApp redirect overlay
          if (_isRedirecting) _buildRedirectOverlay(shop),

          // Bottom CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () => _openWhatsApp(shop),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.whatsapp,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'HUBUNGI WA PENJUAL',
                        style: AppTextStyles.button
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActions(CoffeeShop shop) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          // Toggle open/closed
          BlocBuilder<AdminBloc, AdminState>(
            builder: (context, state) {
              final isOpen = _rtdbIsOpen ?? shop.isOpen;
              return GestureDetector(
                onTap: () {
                  context.read<AdminBloc>().add(AdminToggleOpen(
                        shopId: shop.id,
                        isOpen: !isOpen,
                      ));
                  setState(() => _rtdbIsOpen = !isOpen);
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isOpen ? AppColors.open : AppColors.closed)
                        .withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOpen ? 'BUKA' : 'TUTUP',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
          // Edit button
          GestureDetector(
            onTap: () => context.push(
              AppRouter.adminEditShop,
              extra: shop,
            ),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.overlay,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.edit_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedirectOverlay(CoffeeShop shop) {
    return Container(
      color: AppColors.bgDark.withOpacity(0.9),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.bgCardAlt,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.phone_android_rounded,
                        color: AppColors.textPrimary, size: 30),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.whatsapp.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.chat_rounded,
                        color: AppColors.whatsapp, size: 30),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgCardAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  WhatsAppLauncher.buildOrderMessage(
                    shopName: shop.name,
                    menuItem: _redirectMenuName,
                  ),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text('Redirecting to WhatsApp...',
                      style: AppTextStyles.bodySmall),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isRedirecting = false),
                child: Text('BATAL',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOpen;
  final String openUntil;
  const _StatusBadge({required this.isOpen, required this.openUntil});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isOpen ? AppColors.open : AppColors.closed).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOpen ? 'BUKA NOW - S/D $openUntil' : 'TUTUP',
        style: AppTextStyles.caption.copyWith(
          color: isOpen ? AppColors.open : AppColors.closed,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FacilityItem extends StatelessWidget {
  final String facility;
  const _FacilityItem({required this.facility});

  static const _icons = {
    'WiFi': Icons.wifi_rounded,
    'Outdoor': Icons.deck_rounded,
    'Musik': Icons.music_note_rounded,
    'Parkir': Icons.local_parking_rounded,
    'AC': Icons.ac_unit_rounded,
    'Colokan': Icons.electrical_services_rounded,
    'Toilet': Icons.wc_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[facility] ?? Icons.check_circle_rounded;
    return Column(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 22),
        ),
        const SizedBox(height: 4),
        Text(facility,
            style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}
