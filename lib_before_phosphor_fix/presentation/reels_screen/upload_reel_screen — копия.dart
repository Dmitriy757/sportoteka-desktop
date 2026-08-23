import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';

class UploadReelScreen extends StatefulWidget {
  final VoidCallback onUploadComplete;

  const UploadReelScreen({Key? key, required this.onUploadComplete}) : super(key: key);

  @override
  _UploadReelScreenState createState() => _UploadReelScreenState();
}

class _UploadReelScreenState extends State<UploadReelScreen> {
  File? _videoFile;
  final TextEditingController _descriptionController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _isUploading = false;

  Future<void> _pickVideo() async {
    final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _videoFile = File(pickedFile.path);
        _videoController = VideoPlayerController.file(_videoFile!)
          ..initialize().then((_) {
            setState(() {});
          });
      });
    }
  }

  Future<void> _uploadReel() async {
    if (_videoFile == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Заполните все поля")));
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String uploadUrl = "https://sportotekaapp.ru/api/upload_reel.php";

      FormData formData = FormData.fromMap({
        "user_id": "1",
        "username": "@sportoteka_user",
        "description": _descriptionController.text,
        "user_avatar": "https://sportotekaapp.ru/uploads/avatars/default_avatar.png",
        "video": await MultipartFile.fromFile(_videoFile!.path, filename: "reel.mp4"),
      });

      var response = await Dio().post(uploadUrl, data: formData);

      if (response.statusCode == 200 && response.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Видео загружено")));
        widget.onUploadComplete();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка при загрузке")));
      }
    } catch (e) {
      print("Ошибка: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка сети")));
    }

    setState(() {
      _isUploading = false;
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color mainColor = Color(0xFF1E74C4);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildCustomHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_videoFile == null)
                    GestureDetector(
                      onTap: _pickVideo,
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E74C4), Color(0xFF007AD9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              offset: Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_circle_outline, size: 48, color: Colors.white),
                              SizedBox(height: 12),
                              Text(
                                "Выбрать видео",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "Введите описание...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  _isUploading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _uploadReel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          child: const Text(
                            "Загрузить видео",
                            style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E74C4), Color(0xFF007AD9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Загрузка Reels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
