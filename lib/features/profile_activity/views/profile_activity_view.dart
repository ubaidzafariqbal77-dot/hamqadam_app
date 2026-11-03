import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../exceptions/app_exceptions.dart';
import '../../../models/appreciation_model.dart';
import '../../../repositories/appreciation_repository.dart';
import '../../../widgets/state_widgets.dart';
import '../../discover/widgets/public_profile_detail_sheet.dart';

/// Profile Activity (spec 13.10): Received / Sent, each split into Likes and
/// Super Likes. Shortlist, Interests, Proposals and Matches keep their own screens.
class ProfileActivityView extends StatelessWidget {
  const ProfileActivityView({super.key, this.initialReceived = true, this.initialType});

  final bool initialReceived;
  final AppreciationType? initialType;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialReceived ? 0 : 1,
      child: Scaffold(
        backgroundColor: AppColors.roseCanvas,
        appBar: AppBar(
          title: const Text('Profile Activity'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.roseTitleInk,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primaryInk,
            indicatorColor: AppColors.primaryDark,
            tabs: <Widget>[Tab(text: 'Received'), Tab(text: 'Sent')],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _DirectionTab(received: true, initialType: initialType),
            _DirectionTab(received: false, initialType: initialType),
          ],
        ),
      ),
    );
  }
}

class _DirectionTab extends StatelessWidget {
  const _DirectionTab({required this.received, this.initialType});

  final bool received;
  final AppreciationType? initialType;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialType == AppreciationType.superLike ? 1 : 0,
      child: Column(
        children: <Widget>[
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: AppColors.roseTitleInk,
              indicatorColor: AppColors.gold,
              tabs: <Widget>[
                Tab(icon: const Icon(Icons.favorite_rounded, color: Color(0xFFE0446A), size: 18),
                    text: received ? 'Likes Received' : 'Likes Sent'),
                Tab(icon: const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                    text: received ? 'Super Likes Received' : 'Super Likes Sent'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _ActivityList(received: received, type: AppreciationType.like),
                _ActivityList(received: received, type: AppreciationType.superLike),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityList extends StatefulWidget {
  const _ActivityList({required this.received, required this.type});

  final bool received;
  final AppreciationType type;

  @override
  State<_ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends State<_ActivityList> with AutomaticKeepAliveClientMixin {
  final AppreciationRepository _repo = Get.find<AppreciationRepository>();
  final List<AppreciationActivity> _items = <AppreciationActivity>[];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      if (_loadingMore || _page >= _lastPage) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final AppreciationActivityPage page = await _repo.fetchActivity(
        received: widget.received,
        type: widget.type,
        page: more ? _page + 1 : 1,
      );
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(page.items);
        _page = page.currentPage;
        _lastPage = page.lastPage;
      });
    } on AppException catch (e) {
      if (mounted && !more) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && !more) setState(() => _error = 'Could not load activity.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorStateWidget(message: _error, onRetry: _load);
    final bool superLike = widget.type == AppreciationType.superLike;
    if (_items.isEmpty) {
      return EmptyStateWidget(
        title: superLike ? 'No Super Likes yet' : 'No Likes yet',
        message: widget.received
            ? 'When someone ${superLike ? 'Super Likes' : 'likes'} your profile, they will appear here.'
            : 'Profiles you ${superLike ? 'Super Like' : 'like'} will appear here.',
        onRefresh: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) _load(more: true);
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _items.length + (_loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int i) {
            if (i >= _items.length) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _ActivityTile(item: _items[i], received: widget.received);
          },
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.received});

  final AppreciationActivity item;
  final bool received;

  @override
  Widget build(BuildContext context) {
    final bool superLike = item.type == AppreciationType.superLike;
    final String name = (item.userName ?? '').trim().isEmpty ? 'HamQadam Member' : item.userName!.trim();
    final String when = item.createdAt == null ? '' : DateFormat('d MMM yyyy, h:mm a').format(item.createdAt!);
    final bool hasPhoto = (item.userPhoto ?? '').isNotEmpty;

    void open() {
      if (item.userId == null) return;
      PublicProfileDetailSheet.show(context, profileId: item.userId!, name: name, photo: item.userPhoto);
    }

    return Material(
      color: superLike ? const Color(0xFFFFF7E6) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: open,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: superLike ? AppColors.gold.withValues(alpha: 0.6) : AppColors.roseFieldBorder,
            ),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: hasPhoto ? NetworkImage(item.userPhoto!) : null,
                child: hasPhoto
                    ? null
                    : Text(name[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.primaryInk, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Icon(superLike ? Icons.star_rounded : Icons.favorite_rounded,
                            size: 15, color: superLike ? AppColors.gold : const Color(0xFFE0446A)),
                        const SizedBox(width: 4),
                        Text(superLike ? 'Super Like' : 'Like',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        if (!received) ...<Widget>[
                          const Text('  ·  ', style: TextStyle(fontSize: 12.5)),
                          const Text('Successfully Sent',
                              style: TextStyle(fontSize: 12.5, color: AppColors.success)),
                        ],
                      ],
                    ),
                    if (when.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(when, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                    ],
                  ],
                ),
              ),
              TextButton(onPressed: open, child: const Text('View Profile')),
            ],
          ),
        ),
      ),
    );
  }
}
