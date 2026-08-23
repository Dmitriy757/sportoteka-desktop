import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/booking_screen/venue_booking_screen.dart';

// ✅ импорт экрана каталога площадок
import 'package:sportoteka/presentation/venue/venues_catalog_screen.dart';

class VenueSection extends StatelessWidget {
  final List<Map<String, dynamic>> venues;

  /// если хочешь сразу открыть каталог с выбранным спортом
  final String? initialSport;

  /// если хочешь сразу открыть каталог с выбранным городом
  final String? initialCity;

  const VenueSection({
    super.key,
    required this.venues,
    this.initialSport,
    this.initialCity,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ===== Header + кнопка "Все" =====
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const Text(
                "Площадки",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VenuesCatalogScreen(
                        initialSport: initialSport,
                        initialCity: initialCity,
                      ),
                    ),
                  );
                },
                child: const Text("Все"),
              ),
            ],
          ),
        ),

        // ===== Горизонтальная карусель =====
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: venues.length,
            itemBuilder: (_, i) => _VenueCard(venue: venues[i]),
          ),
        ),
      ],
    );
  }
}

class _VenueCard extends StatelessWidget {
  final Map<String, dynamic> venue;
  const _VenueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final image = (venue['image'] ?? '').toString();
    final title = (venue['title'] ?? '').toString();
    final address = (venue['address'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        // ✅ Тап по карточке = открыть БРОНИРОВАНИЕ (как у тебя было)
        final userId = await PrefUtils.getUserId();
        if (userId == null) return;

        final venueId = int.tryParse((venue['id'] ?? '0').toString()) ?? 0;

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => VenueBookingScreen(
              venueId: venueId,
              venueTitle: title,
              userId: userId,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
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
            if (image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  image,
                  height: 90,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 10),

            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),

            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Spacer(),

            const Row(
              children: [
                Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text("Забронировать", style: TextStyle(color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
