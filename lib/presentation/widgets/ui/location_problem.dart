import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/failures.dart';
import '../../blocs/location/location_bloc.dart';
import 'common.dart';

/// Screen 15 "Izin lokasi": shown wherever shops depend on a location we
/// couldn't get. Always offers the manual area picker as a way out.
class LocationProblemView extends StatelessWidget {
  final LocationError error;
  const LocationProblemView({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LocationBloc>();
    final (title, action, icon, onAction) = switch (error.issue) {
      LocationIssue.permissionDeniedForever => (
          'Izin lokasi diblokir',
          'Buka pengaturan',
          Icons.settings_rounded,
          () => Geolocator.openAppSettings(),
        ),
      LocationIssue.serviceDisabled => (
          'GPS kamu mati',
          'Nyalakan lokasi',
          Icons.gps_fixed_rounded,
          () => Geolocator.openLocationSettings(),
        ),
      LocationIssue.permissionDenied => (
          'Izinkan akses lokasi',
          'Izinkan lokasi',
          Icons.my_location_rounded,
          () async => bloc.add(LocationGetCurrent()),
        ),
      LocationIssue.unavailable => (
          'Lokasi belum ketemu',
          'Coba lagi',
          Icons.refresh_rounded,
          () async => bloc.add(LocationGetCurrent()),
        ),
    };
    return StateView(
      icon: Icons.location_off_rounded,
      title: title,
      message: error.message,
      actionLabel: action,
      actionIcon: icon,
      onAction: () async {
        await onAction();
      },
      secondary: TextButton(
        onPressed: () => context.push(AppRouter.pickLocation),
        child: Text('Pilih area manual',
            style: AppTextStyles.body.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Re-asks the GPS when the user comes back from system settings.
class LocationResumeRetry extends StatefulWidget {
  final Widget child;
  const LocationResumeRetry({super.key, required this.child});

  @override
  State<LocationResumeRetry> createState() => _LocationResumeRetryState();
}

class _LocationResumeRetryState extends State<LocationResumeRetry>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed || !mounted) return;
    final bloc = context.read<LocationBloc>();
    final st = bloc.state;
    if (st is LocationError && st.isPermission) bloc.add(LocationGetCurrent());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
