import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'dart:developer' as devtools;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  int selectedCameraIdx = 0;
  bool isDetecting = false;
  List<Map<String, dynamic>> detectedObjects = [];
  String message = '';
  final double confidenceThreshold = 0.5;

  @override
  void initState() {
    super.initState();
    _initCameras();
    _loadModel();
  }

  Future<void> _initCameras() async {
    cameras = await availableCameras();

    if (cameras != null && cameras!.isNotEmpty) {
      // Find the front camera
      selectedCameraIdx = cameras!.indexWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front);

      if (selectedCameraIdx != -1) {
        await _initializeCamera(selectedCameraIdx);
      } else {
        setState(() {
          message = 'No front camera found';
        });
      }
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

    try {
      await _cameraController!.initialize();
      _cameraController!.startImageStream((CameraImage img) {
        if (!isDetecting) {
          isDetecting = true;
          _runModelOnFrame(img);
        }
      });
      setState(() {});
    } catch (e) {
      devtools.log("Error initializing camera: $e");
      setState(() {
        message = 'Error: Unable to initialize camera';
      });
    }
  }

  Future<void> _loadModel() async {
    try {
      String? res = await Tflite.loadModel(
        model: "assets/Newfolder/model.tflite",
        labels: "assets/Newfolder/labels.txt",
        numThreads: 1,
        isAsset: true,
        useGpuDelegate: false,
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
      bytesList: img.planes.map((plane) => plane.bytes).toList(),
      imageHeight: img.height,
      imageWidth: img.width,
      imageMean: 127.5,
      imageStd: 127.5,
      rotation: 90,
      numResults: 2,
      threshold: 0.1,
      asynch: true,
    );

    if (recognitions != null && recognitions.isNotEmpty) {
      detectedObjects = recognitions
          .map((res) => {
        'label': res['label'],
        'confidence': res['confidence']
      })
          .where((obj) => obj['confidence'] > confidenceThreshold)
          .toList();
    }

    setState(() {});
    isDetecting = false;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    Tflite.close();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Secret File"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent[100],
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.switch_camera),
          //   onPressed: _switchCamera,
          // ),
        ],
      ),
      body: Column(
        children: [

          if (_cameraController != null && _cameraController!.value.isInitialized)
            Opacity(
              opacity: 0.0, // Set opacity to 0 to make it invisible
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            ),


          //============//
          Expanded(
            child: ListView.builder(
              itemCount: detectedObjects.length,
              itemBuilder: (context, index) {
                var obj = detectedObjects[index];
                bool isCameraDetected = obj['label'].toLowerCase().contains('camera');

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "THIS IS PRIVATE DATA.\n\nName:Riad Rayhan Bijoy\nACC:53453423423\nPhone Number:+8801615-573020\nPIN Code:54354\nCard Number:1101231232314301\nCVC:631",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isCameraDetected ? Colors.white : Colors.black, // Change color based on condition
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text(
                        obj['label'],
                        style: TextStyle(
                          color: isCameraDetected ? Colors.white : Colors.white, // Change color here as well
                        ),
                      ),
                      // subtitle: Text(
                      //   "Confidence: ${(obj['confidence'] * 100).toStringAsFixed(0)}%",
                      // ),
                    ),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }
}