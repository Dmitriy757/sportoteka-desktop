// lib/presentation/tickets/tickets_section.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TicketsSection extends StatelessWidget {
  final String? selectedClub;
  final List<Map<String, dynamic>> tickets;

  const TicketsSection({
    super.key,
    required this.selectedClub,
    required this.tickets,
  });

  @override
  Widget build(BuildContext context) {
    final items = tickets.map((t) => _TicketItem(
      title: t['teams'] ?? '',
      subtitle: "${t['date']} • ${t['venue']}",
      price: t['price'] ?? '',
      url: t['url'] ?? '',
      gradient: const [Color(0xFF005AAB), Color(0xFF007BFF)],
    )).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            "Билеты на матчи ${selectedClub ?? ''}".trim().isEmpty
                ? "Ближайшие билеты"
                : "Билеты на матчи ${selectedClub!}",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: items.length,
            itemBuilder: (_, i) => _TicketCard(item: items[i]),
          ),
        ),
      ],
    );
  }
}

class _TicketItem {
  final String title;
  final String subtitle;
  final String price;
  final String url;
  final List<Color> gradient;

  const _TicketItem({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.url,
    required this.gradient,
  });
}

class _TicketCard extends StatelessWidget {
  final _TicketItem item;
  const _TicketCard({super.key, required this.item});

  Future<void> _openUrl(BuildContext context) async {
    if (item.url.isEmpty) return;
    final uri = Uri.parse(item.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось открыть ссылку")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openUrl(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.price,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Row(
                  children: const [
                    Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text("Купить", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
