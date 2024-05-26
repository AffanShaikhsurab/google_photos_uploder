import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;

class Gallery extends StatefulWidget {
  final Uint8List heicBytes;

  Gallery({required this.heicBytes});

  @override
  _GalleryState createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  Uint8List? jpgBytes;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    convertImage();
  }

  Future<void> convertImage() async {
    print("converting...........");
    jpgBytes = await convertHeicToJpg(widget.heicBytes);
    if (jpgBytes != null) {
      setState(() {
        isLoading = false;
      });
    } else {
      // Handle error
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to convert image.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Image'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
        ),
        child: Center(
          child: isLoading
              ? CircularProgressIndicator()
              : PhotoView(
                  imageProvider: MemoryImage(jpgBytes!),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  backgroundDecoration: BoxDecoration(
                    color: Colors.black,
                  ),
                  loadingBuilder: (context, event) => Center(
                    child: CircularProgressIndicator(
                      value: event == null
                          ? 0
                          : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}



Future<Uint8List?> convertHeicToJpg(Uint8List heicBytes) async {
  var request = http.MultipartRequest('POST', Uri.parse('https://heic-converter-1cjl.onrender.com/convert/'));

  // Add HEIC file to the request
  request.files.add(http.MultipartFile.fromBytes('files', heicBytes, filename: 'image.heic'));

  // Send the request
  var response = await request.send();

  if (response.statusCode == 200) {
    // Read the response as bytes
    print("response" + response.toString());
    var responseBytes = await response.stream.toBytes();
    return responseBytes;
  } else {
    print('Failed to convert image. Status code: ${response.statusCode}');
    return null;
  }
}
