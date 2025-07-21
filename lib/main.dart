import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Получаем список доступных камер
  final cameras = await availableCameras();

  // Проверяем, есть ли камеры
  if (cameras.isEmpty) {
    print('No cameras found');
    return; // Можно показать экран с ошибкой, если хочешь
  }

  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Capture App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CameraScreen(camera: camera),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _controller = CameraController(widget.camera, ResolutionPreset.medium);

    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndUpload() async {
    try {
      await _initializeControllerFuture;

      // Сделать снимок и сохранить в файл
      final image = await _controller.takePicture();

      // Получить текущие координаты
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Получить комментарий из текстового поля
      String comment = _commentController.text;

      // Отправить данные на сервер
      await _uploadPhoto(
        imagePath: image.path,
        comment: comment,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _uploadPhoto({
    required String imagePath,
    required String comment,
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://flutter-sandbox.free.beeceptor.com/upload_photo/',
    );

    var request = http.MultipartRequest('POST', uri);

    request.fields['comment'] = comment;
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();

    request.files.add(await http.MultipartFile.fromPath('photo', imagePath));

    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('Failed to upload photo');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Photo')),
      body: Column(
        children: [
          // Камера
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: CameraPreview(_controller),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),

          // Поле ввода комментария
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter comment',
              ),
            ),
          ),

          // Кнопка съёмки и отправки
          ElevatedButton(
            onPressed: _takePictureAndUpload,
            child: const Text('Take Picture & Upload'),
          ),
        ],
      ),
    );
  }
}
