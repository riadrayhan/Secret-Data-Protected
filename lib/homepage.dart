import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_tflite/flutter_tflite.dart'; 
import 'dart:developer' as devtools;

class MyHomePage2 extends StatefulWidget {
  const MyHomePage2({super.key});

  @override
  State<MyHomePage2> createState() => _MyHomePage2State();
}

class _MyHomePage2State extends State<MyHomePage2> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  int selectedCameraIdx = 0;
  bool isDetecting = false;
  List<Map<String, dynamic>> detectedObjects = [];
  String message = '';
  final double confidenceThreshold = 0.5;
  final FlutterTts _flutterTts = FlutterTts();
  String lastSpokenLabel = '';
  Timer? _speakTimer;

  @override
  void initState() {
    super.initState();
    _initCameras();
    _loadModel();
  }

  Future<void> _initCameras() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      _initializeCamera(selectedCameraIdx);
    } else {
      setState(() {
        message = 'No camera found';
      });
    }
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    _cameraController = CameraController(
      cameras![cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController?.initialize();
    _cameraController?.startImageStream((CameraImage img) {
      if (!isDetecting) {
        isDetecting = true;
        _runModelOnFrame(img);
      }
    });

    setState(() {});
  }

  Future<void> _switchCamera() async {
    selectedCameraIdx = selectedCameraIdx == 0 ? 1 : 0;
    await _initializeCamera(selectedCameraIdx);
  }

  Future<void> _loadModel() async {
    try {
      String? res = await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
      );
      devtools.log("Model loaded: $res");
    } catch (e) {
      devtools.log("Error loading model: $e");
      setState(() {
        message = 'Error: Unable to load model';
      });
    }
  }

  Future<void> _runModelOnFrame(CameraImage img) async {
    var recognitions = await Tflite.runModelOnFrame(
      bytesList: img.planes.map((plane) {
        return plane.bytes;
      }).toList(),
      imageHeight: img.height,
      imageWidth: img.width,
      imageMean: 127.5,
      imageStd: 127.5,
      rotation: 90,
      numResults: 41,
      threshold: 0.5,
      asynch: true,
    );

    if (recognitions != null && recognitions.isNotEmpty) {
      setState(() {
        detectedObjects = recognitions.map((res) => {
          'label': res['label'],
          'confidence': res['confidence']
        }).toList();
        message = detectedObjects.isEmpty ? 'No objects detected' : '';
      });

      _speakDetectedObjects();
    }
    isDetecting = false;
  }

  void _speakDetectedObjects() {
    _speakTimer?.cancel();
    _speakTimer = Timer(const Duration(milliseconds: 100), () {
      if (detectedObjects.isNotEmpty) {
        String textToSpeak = detectedObjects.first['label'];
        if (textToSpeak != lastSpokenLabel) {
          _speak(textToSpeak);
          lastSpokenLabel = textToSpeak;
        }
      }
    });
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    Tflite.close(); // Close the Tflite interpreter
    _flutterTts.stop();
    _speakTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Real-Time Object Detection"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent[100],
        actions: [
          IconButton(
            icon: Icon(Icons.switch_camera,color: Colors.blueAccent,),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox(
              height: 500,
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            message.isNotEmpty ? message : "Detected Objects:",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: detectedObjects.length,
              itemBuilder: (context, index) {
                var obj = detectedObjects[index];
                return ListTile(
                  title: Text(obj['label']),
                  subtitle: Text("Confidence: ${(obj['confidence'] * 100).toStringAsFixed(0)}%"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
