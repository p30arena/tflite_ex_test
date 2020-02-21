import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tensorflow Lite',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Tensorflow Lite'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String res;
  ui.Image image;
  dynamic recognitions;

  @override
  void initState() {
    super.initState();

    Future(() async {
      res = await Tflite.loadModel(
        model: 'assets/detect.tflite',
        labels: 'assets/labelmap.txt',
        numThreads: 1, // defaults to 1
      );

      setState(() {});
    });
  }

  @override
  void dispose() {
    Tflite.close();

    super.dispose();
  }

  Future<ui.Image> _loadImage(File f) async {
    var bytes = await f.readAsBytes();
    var codec = await ui.instantiateImageCodec(bytes);
    var frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    final maxImageWidth = MediaQuery.of(context).size.width - 32.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (res == null) CircularProgressIndicator(),
            if (image == null)
              Image.asset(
                'assets/tensorflow_logo.png',
                width: maxImageWidth,
              ),
            if (image != null)
              CustomPaint(
                size: Size(image.width.toDouble(), image.height.toDouble()),
                painter: MyPainter(
                  image: image,
                  recognitions: recognitions,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: (res == null)
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                var imageFile = await ImagePicker.pickImage(
                  source: ImageSource.gallery,
                );

                if (imageFile == null) {
                  return;
                }

                var croppedFile = await ImageCropper.cropImage(
                  sourcePath: imageFile.path,
                  maxWidth: maxImageWidth.toInt(),
                  maxHeight: maxImageWidth.toInt(),
                  aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
                );

                if (croppedFile == null) {
                  return;
                }

                image = await _loadImage(croppedFile);

                recognitions = await Tflite.detectObjectOnImage(
                  path: croppedFile.path, // required
                  model: "SSDMobileNet",
                  imageMean: 127.5,
                  imageStd: 127.5,
                  threshold: 0.4, // defaults to 0.1
                  numResultsPerClass: 2, // defaults to 5
                  asynch: true, // defaults to true
                );

                setState(() {});
              },
              icon: Icon(Icons.camera_alt),
              label: Text("Pick Image"),
            ),
    );
  }
}

class MyPainter extends CustomPainter {
  final ui.Image image;
  final dynamic recognitions;

  MyPainter({
    this.image,
    this.recognitions,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final colorsList = [
      Colors.blue,
      Colors.red,
      Colors.orange,
      Colors.green,
      Colors.cyan,
      Colors.purple,
      Colors.brown,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.lime,
      Colors.teal,
    ];
    int colorsListIndex = 0;

    canvas.drawImage(image, Offset(0, 0), Paint());

    (recognitions as List).forEach((r) {
      if (r['confidenceInClass'] < 0.5) {
        return;
      }

      double x = r['rect']['x'] * image.width;
      double y = r['rect']['y'] * image.height;
      double w = r['rect']['w'] * image.width;
      double h = r['rect']['h'] * image.height;

      canvas.drawRect(
          Rect.fromLTWH(
            x,
            y,
            w,
            h,
          ),
          Paint()
            ..color = colorsList[colorsListIndex]
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke);

      final tp = TextPainter(
        text: TextSpan(
          text: r['detectedClass'],
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            backgroundColor: colorsList[colorsListIndex],
          ),
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x, y));

      colorsListIndex = (colorsListIndex + 1) % colorsList.length;
    });
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
