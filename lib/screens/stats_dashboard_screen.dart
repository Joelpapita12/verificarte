import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/api_models.dart';
import '../services/current_user_store.dart';
import '../services/feed_api.dart';

class StatsDashboardScreen extends StatefulWidget {
  const StatsDashboardScreen({super.key});

  static const routeName = '/estadisticas';

  @override
  State<StatsDashboardScreen> createState() => _StatsDashboardScreenState();
}

class _StatsDashboardScreenState extends State<StatsDashboardScreen> {
  final FeedApi _api = FeedApi();
  bool _loading = true;
  ArtistStatsDto? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Inicia sesión para ver estadísticas';
      });
      return;
    }
    try {
      final stats = await _api.fetchArtistStats(artistId: userId);
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar estadísticas';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081B3B),
      appBar: AppBar(
        title: const Text('Estadísticas'),
        backgroundColor: const Color(0xFF071A35),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            )
          : _StatsContent(stats: _stats!),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.stats});

  final ArtistStatsDto stats;

  @override
  Widget build(BuildContext context) {
    final bars = [
      _BarData('Likes', stats.likes, Colors.pinkAccent),
      _BarData('Comentarios', stats.comments, Colors.orangeAccent),
      _BarData('Favoritos', stats.favorites, Colors.cyan),
      _BarData('Mensajes', stats.messages, const Color(0xFF8CC84B)),
    ];
    final maxValue = math.max(
      1,
      bars.map((b) => b.value).fold<int>(0, math.max),
    );
    final likersSorted = [...stats.likers]
      ..sort((a, b) => b.total.compareTo(a.total));
    final commentersSorted = [...stats.commenters]
      ..sort((a, b) => b.total.compareTo(a.total));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: bars
              .map(
                (b) =>
                    _StatCard(title: b.label, value: b.value, color: b.color),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F264E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard general',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 270,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: bars
                      .map(
                        (b) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _AnimatedBar(
                              label: b.label,
                              value: b.value,
                              maxValue: maxValue,
                              color: b.color,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ExpansionTile(
          collapsedBackgroundColor: const Color(0xFF102A56),
          backgroundColor: const Color(0xFF0F264E),
          collapsedIconColor: Colors.white,
          iconColor: Colors.white,
          title: Text(
            'Likes (${stats.likers.length} cuentas)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: likersSorted.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Aún no tienes likes',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ]
              : likersSorted
                    .map(
                      (a) =>
                          _AccountRow(account: a, suffix: '${a.total} likes'),
                    )
                    .toList(),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          collapsedBackgroundColor: const Color(0xFF102A56),
          backgroundColor: const Color(0xFF0F264E),
          collapsedIconColor: Colors.white,
          iconColor: Colors.white,
          title: Text(
            'Comentarios (${stats.commenters.length} cuentas)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: commentersSorted.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Aún no tienes comentarios',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ]
              : commentersSorted
                    .map(
                      (a) => _AccountRow(
                        account: a,
                        suffix: '${a.total} comentarios',
                      ),
                    )
                    .toList(),
        ),
      ],
    );
  }
}

class _BarData {
  _BarData(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102A56),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.suffix});

  final InteractionAccountDto account;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final name = account.publicName.trim().isEmpty
        ? account.username
        : account.publicName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return ListTile(
      tileColor: const Color(0xFF0A1F43),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF1B3D74), Color(0xFF0C2348)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFF4D7AB3), width: 1.1),
          image: (account.photoUrl ?? '').trim().isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(account.photoUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: (account.photoUrl ?? '').trim().isEmpty
            ? Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
      title: Text(name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        '@${account.username}',
        style: const TextStyle(color: Color(0xFF8EA8CC)),
      ),
      trailing: Text(suffix, style: const TextStyle(color: Colors.white70)),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final targetHeight = (140 * (value / maxValue)).clamp(8, 140).toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$value', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: targetHeight),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, h, _) {
            return Container(
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

