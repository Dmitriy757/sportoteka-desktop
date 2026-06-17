import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class EditTrainerProfileScreen extends StatefulWidget {
  final int trainerId;
  final String trainerName;

  const EditTrainerProfileScreen({
    super.key,
    required this.trainerId,
    required this.trainerName,
  });

  @override
  State<EditTrainerProfileScreen> createState() => _EditTrainerProfileScreenState();
}

class _EditTrainerProfileScreenState extends State<EditTrainerProfileScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getUrl = "$apiBase/get_trainer_profile.php";
  static const String saveUrl = "$apiBase/update_trainer_profile.php";

  bool loading = true;
  bool saving = false;
  String? error;

  final TextEditingController positionC = TextEditingController();
  final TextEditingController bioC = TextEditingController();
  final TextEditingController bornC = TextEditingController(); // birthday
  final TextEditingController careerC = TextEditingController(); // experience

  // ✅ Фото
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedPhoto;
  String? _currentPhotoUrl; // то, что пришло с сервера

  Map<String, dynamic> _decode(http.Response r) {
    try {
      final j = json.decode(r.body);
      return j is Map<String, dynamic> ? j : {"status": "error", "message": "bad json"};
    } catch (_) {
      return {"status": "error", "message": "bad json"};
    }
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  /// Подстраховка: сервер может вернуть profile/trainer/user/data или вообще плоско
  Map<String, dynamic> _pickProfile(Map<String, dynamic> res) {
    Map<String, dynamic>? m(dynamic v) => (v is Map) ? Map<String, dynamic>.from(v as Map) : null;

    final p1 = m(res["profile"]);
    if (p1 != null) return p1;

    final p2 = m(res["trainer"]);
    if (p2 != null) return p2;

    final p3 = m(res["user"]);
    if (p3 != null) return p3;

    final p4 = m(res["data"]);
    if (p4 != null) return p4;

    return res;
  }

  /// ✅ Нормализуем пути как у тебя в TeamTrainersScreen
  String? _normalizeImage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    String url = raw.trim();

    if (url.startsWith("http://") || url.startsWith("https://")) return url;
    if (url.startsWith("//")) return "https:$url";
    if (url.startsWith("sportotekaapp.ru/")) return "https://$url";
    if (url.startsWith("www.sportotekaapp.ru/")) return "https://$url";
    if (url.startsWith("/")) return "https://sportotekaapp.ru$url";
    if (url.startsWith("uploads/")) return "https://sportotekaapp.ru/$url";

    return "https://sportotekaapp.ru/uploads/$url";
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    positionC.dispose();
    bioC.dispose();
    bornC.dispose();
    careerC.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (x == null) return;

      setState(() => _pickedPhoto = x);
    } catch (e) {
      Get.snackbar(
        "Фото",
        "Не удалось выбрать фото: $e",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse(getUrl),
        headers: const {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({"trainer_id": widget.trainerId}),
      );

      // ignore: avoid_print
      print("LOAD RESP ${resp.statusCode}: ${resp.body}");

      final data = _decode(resp);
      final ok = data["success"] == true || data["status"] == "success";

      if (ok) {
        final p = _pickProfile(data);

        positionC.text = _asStr(p["position"]);
        bioC.text = _asStr(p["bio"]);
        bornC.text = _asStr(p["birthday"]);
        careerC.text = _asStr(p["experience"]);

        // ✅ текущая фотка (ищем по разным ключам на всякий случай)
        final rawPhoto = _asStr(p["photo"]).isNotEmpty
            ? _asStr(p["photo"])
            : (_asStr(p["photo_url"]).isNotEmpty ? _asStr(p["photo_url"]) : "");

        _currentPhotoUrl = _normalizeImage(rawPhoto);
      }

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "Ошибка загрузки: $e";
      });
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);

    try {
      http.Response resp;

      // ✅ Если фото выбрано — отправляем multipart (как твой PHP ожидает $_FILES['photo'])
      if (_pickedPhoto != null) {
        final req = http.MultipartRequest("POST", Uri.parse(saveUrl));

        req.fields["trainer_id"] = widget.trainerId.toString();
        req.fields["position"] = positionC.text.trim();
        req.fields["bio"] = bioC.text.trim();
        req.fields["birthday"] = bornC.text.trim();
        req.fields["experience"] = careerC.text.trim();

        final file = File(_pickedPhoto!.path);
        req.files.add(await http.MultipartFile.fromPath("photo", file.path));

        final streamed = await req.send();
        final body = await streamed.stream.bytesToString();
        resp = http.Response(body, streamed.statusCode);

      } else {
        // ✅ без фото — обычный JSON (твой PHP тоже поддерживает)
        resp = await http.post(
          Uri.parse(saveUrl),
          headers: const {"Content-Type": "application/json; charset=utf-8"},
          body: jsonEncode({
            "trainer_id": widget.trainerId,
            "position": positionC.text.trim(),
            "bio": bioC.text.trim(),
            "birthday": bornC.text.trim(),
            "experience": careerC.text.trim(),
          }),
        );
      }

      // ignore: avoid_print
      print("SAVE RESP ${resp.statusCode}: ${resp.body}");

      final data = _decode(resp);

      final ok = data["success"] == true || data["status"] == "success";
      if (ok) {
        // ✅ если сервер вернул новый путь photo — обновим локально (не обязательно, но удобно)
        final newPhotoRaw = _asStr(data["photo"]);
        if (newPhotoRaw.isNotEmpty) {
          _currentPhotoUrl = _normalizeImage(newPhotoRaw);
        }

        Get.back(result: true);
      } else {
        Get.snackbar(
          "Ошибка",
          _asStr(data["message"]).isEmpty ? "Не удалось сохранить" : _asStr(data["message"]),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      }
    } catch (e) {
      Get.snackbar(
        "Сеть",
        "Ошибка: $e",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8);
    final primary = Theme.of(context).colorScheme.primary;

    ImageProvider? avatarProvider;
    if (_pickedPhoto != null) {
      avatarProvider = FileImage(File(_pickedPhoto!.path));
    } else if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      avatarProvider = NetworkImage(_currentPhotoUrl!);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Профиль тренера",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _card(
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: Colors.black.withOpacity(0.05),
                                backgroundImage: avatarProvider,
                                child: avatarProvider == null
                                    ? const Icon(Icons.person, size: 34, color: Colors.black45)
                                    : null,
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: InkWell(
                                  onTap: saving ? null : _pickPhoto,
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 10,
                                          offset: const Offset(0, 6),
                                        )
                                      ],
                                    ),
                                    child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.trainerName,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "Заполните визитку тренера (можно добавить фото)",
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: saving ? null : _pickPhoto,
                                  icon: const Icon(Icons.image_outlined),
                                  label: Text(_pickedPhoto != null ? "Фото выбрано" : "Выбрать фото"),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        children: [
                          _field(positionC, "Должность", "Главный тренер / Ассистент / Врач"),
                          const SizedBox(height: 10),
                          _field(bornC, "Дата рождения", "YYYY-MM-DD"),
                          const SizedBox(height: 10),
                          _field(
                            careerC,
                            "Опыт / карьера",
                            "Клубы, лицензии, достижения",
                            maxLines: 3,
                          ),
                          const SizedBox(height: 10),
                          _field(
                            bioC,
                            "Описание",
                            "Коротко о тренере",
                            maxLines: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : _save,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined, color: Colors.white),
                        label: const Text(
                          "Сохранить",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _field(TextEditingController c, String label, String hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
