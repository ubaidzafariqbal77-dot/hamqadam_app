import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/content_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../repositories/content_repository.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';

/// Upcoming webinars with one-tap registration.
class WebinarsView extends StatefulWidget {
  const WebinarsView({super.key});

  @override
  State<WebinarsView> createState() => _WebinarsViewState();
}

class _WebinarsViewState extends State<WebinarsView> {
  final ContentController _controller = Get.find<ContentController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadWebinars());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.roseCanvas,
      appBar: const PremiumAppBar(title: 'Webinars', subtitle: 'Live sessions with relationship experts'),
      body: Obx(() {
        final ApiState<ContentPage<Map<String, dynamic>>> state = _controller.webinarsState.value;

        switch (state.status) {
          case ApiStatus.initial:
          case ApiStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.regAccent));
          case ApiStatus.noInternet:
            return NoInternetWidget(onRetry: _controller.loadWebinars);
          case ApiStatus.unauthorized:
          case ApiStatus.serverError:
          case ApiStatus.validationError:
            return ErrorStateWidget(message: state.message, onRetry: _controller.loadWebinars);
          case ApiStatus.empty:
            return const EmptyStateWidget(
              title: 'No webinars scheduled',
              message: 'Check back soon — new sessions are announced regularly.',
            );
          case ApiStatus.success:
            final List<Map<String, dynamic>> items = state.data?.items ?? <Map<String, dynamic>>[];
            return RefreshIndicator(
              color: AppColors.regAccent,
              onRefresh: () => _controller.loadWebinars(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (BuildContext ctx, int i) => _WebinarCard(item: items[i]),
              ),
            );
        }
      }),
    );
  }
}

class _WebinarCard extends StatelessWidget {
  const _WebinarCard({required this.item});

  final Map<String, dynamic> item;

  String _field(List<String> keys) {
    for (final String k in keys) {
      final dynamic v = item[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final ContentController controller = Get.find<ContentController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int id = (item['id'] as num?)?.toInt() ?? 0;
    final String title = _field(<String>['title', 'name']);
    final String host = _field(<String>['host', 'speaker', 'presenter_name', 'created_by_name']);
    final String desc = _field(<String>['description', 'details', 'summary']);
    final DateTime? when = DateTime.tryParse(_field(<String>['scheduled_at', 'start_at', 'starts_at', 'webinar_date', 'date']));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[AppColors.regAccent.withValues(alpha: 0.12), AppColors.regAccent.withValues(alpha: 0.03)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.regAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.videocam_rounded, color: AppColors.regAccent, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (when != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEE, d MMM • h:mm a').format(when),
                          style: AppTextStyles.caption.copyWith(color: AppColors.regAccent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (host.isNotEmpty)
                  Row(children: <Widget>[
                    const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.lightTextHint),
                    const SizedBox(width: 4),
                    Flexible(child: Text('Hosted by $host', style: AppTextStyles.caption)),
                  ]),
                if (desc.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(desc, style: AppTextStyles.caption.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 12),
                Obx(() {
                  final bool registered = controller.registeredWebinars.contains(id);
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: registered ? AppColors.success : AppColors.regAccent,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      ),
                      onPressed: registered || id <= 0 ? null : () => controller.registerWebinar(id),
                      icon: Icon(registered ? Icons.check_circle_rounded : Icons.how_to_reg_rounded,
                          color: Colors.white, size: 18),
                      label: Text(
                        registered ? 'Registered' : 'Register Now',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
