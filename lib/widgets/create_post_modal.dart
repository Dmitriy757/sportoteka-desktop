import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:convert';

import 'package:sportoteka/core/utils/pref_utils.dart';

void showCreatePostModal(BuildContext context, {required String category}) {
  final TextEditingController controller = TextEditingController();
  File? imageFile;
  bool isLoading = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> _pickImage() async {
            final picker = ImagePicker();
            final file = await picker.pickImage(source: ImageSource.gallery);
            if (file != null) setState(() => imageFile = File(file.path));
          }

          Future<void> _submit() async {
            final text = controller.text.trim();
            if (text.isEmpty && imageFile == null) return;

            setState(() => isLoading = true);
            final userId = await PrefUtils.getUserId();

            final uri = Uri.parse('https://sportotekaapp.ru/api/insert_post.php');
            final req = http.MultipartRequest('POST', uri)
              ..fields['title'] = category
              ..fields['body'] = text
              ..fields['category'] = category
              ..fields['team'] = ''
              ..fields['user_id'] = userId.toString();

            if (imageFile != null) {
              req.files.add(await http.MultipartFile.fromPath(
                'image',
                imageFile!.path,
                filename: path.basename(imageFile!.path),
              ));
            }

            try {
              final resp = await req.send();
              if (resp.statusCode == 200) Navigator.pop(context);
            } catch (_) {
              // обработка ошибок (опционально)
            } finally {
              setState(() => isLoading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Новый пост', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(height: 24),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Что нового в $category?',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
                if (imageFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            imageFile!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => imageFile = null),
                            child: const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_library, color: Color(0xFF005AAB)),
                      onPressed: _pickImage,
                    ),
                    const Text("Фото", style: TextStyle(color: Color(0xFF005AAB))),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005AAB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text("Опубликовать"),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
