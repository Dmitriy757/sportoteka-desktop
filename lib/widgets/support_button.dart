import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportButton extends StatelessWidget {
  const SupportButton({super.key});

  Future<void> _launchSupportUrl() async {
    final Uri url = Uri.parse("https://sportoteka.by/support");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Можно показать SnackBar вместо throw, если хотите
      throw Exception('Не удалось открыть $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _launchSupportUrl,
          icon: const Icon(Icons.support_agent),
          label: const Text("Поддержка"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E74C4),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
