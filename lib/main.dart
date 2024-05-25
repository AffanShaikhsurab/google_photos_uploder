import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SignInDemo(),
    );
  }
}

class SignInDemo extends StatefulWidget {
  @override
  _SignInDemoState createState() => _SignInDemoState();
}

class _SignInDemoState extends State<SignInDemo> {
  final authorizationEndpoint = Uri.parse('https://accounts.google.com/o/oauth2/auth');
  final tokenEndpoint = Uri.parse('https://oauth2.googleapis.com/token');
  final identifier = '99345842123-qmj0uj6l5v2dosdbhsdredcfveokp10m.apps.googleusercontent.com';
  final secret = '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';
  final redirectUrl = Uri.parse('http://localhost:8080');
  final scopes = ['https://www.googleapis.com/auth/photoslibrary'];

  oauth2.Client? _client;

  final ValueNotifier<int> _uploadedCount = ValueNotifier<int>(0);
  final ValueNotifier<int> _totalCount = ValueNotifier<int>(0);
  final ValueNotifier<double> _uploadSpeed = ValueNotifier<double>(0.0);
  final ValueNotifier<int> _estimatedTime = ValueNotifier<int>(0);
  final ValueNotifier<int> _currentFileSize = ValueNotifier<int>(0);

  bool _isPaused = false;
  List<Map<String, dynamic>> _uploadHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString('uploadHistory');
    if (historyString != null) {
      _uploadHistory = List<Map<String, dynamic>>.from(jsonDecode(historyString));
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uploadHistory', jsonEncode(_uploadHistory));
  }

  Future<void> _signIn() async {
    final grant = oauth2.AuthorizationCodeGrant(identifier, authorizationEndpoint, tokenEndpoint, secret: secret);
    final authorizationUrl = grant.getAuthorizationUrl(redirectUrl, scopes: scopes);

    if (await canLaunch(authorizationUrl.toString())) {
      await launch(authorizationUrl.toString());
    } else {
      throw 'Could not launch $authorizationUrl';
    }

    final responseUrl = await listenForRedirect(redirectUrl);
    _client = await grant.handleAuthorizationResponse(responseUrl.queryParameters);

    setState(() {});
  }

  Future<Uri> listenForRedirect(Uri redirectUrl) async {
    final server = await HttpServer.bind(redirectUrl.host, redirectUrl.port);
    final request = await server.first;
    final responseUrl = request.uri;
    request.response
      ..statusCode = 200
      ..headers.set('Content-Type', ContentType.html.mimeType)
      ..write('You can now close this window.')
      ..close();
    await server.close();
    return responseUrl;
  }

  Future<void> _uploadFile(File file, String filename, int totalBytes, Stopwatch stopwatch, StreamController<double> uploadSpeedController) async {
    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;
    _currentFileSize.value = fileSize;

    final uploadTokenResponse = await _client!.post(
      Uri.parse('https://photoslibrary.googleapis.com/v1/uploads'),
      headers: {
        'Content-type': 'application/octet-stream',
        'X-Goog-Upload-File-Name': filename,
        'X-Goog-Upload-Protocol': 'raw',
      },
      body: bytes,
    );

    if (uploadTokenResponse.statusCode == 200) {
      final uploadToken = uploadTokenResponse.body;

      final createMediaItemResponse = await _client!.post(
        Uri.parse('https://photoslibrary.googleapis.com/v1/mediaItems:batchCreate'),
        headers: {
          'Content-type': 'application/json',
        },
        body: jsonEncode({
          'newMediaItems': [
            {
              'description': 'Uploaded from Flutter app',
              'simpleMediaItem': {
                'uploadToken': uploadToken,
              }
            }
          ]
        }),
      );

      if (createMediaItemResponse.statusCode == 200) {
        _uploadHistory.add({'filename': filename, 'status': 'Success'});
      } else {
        _uploadHistory.add({'filename': filename, 'status': 'Failed to create media item'});
      }
    } else {
      _uploadHistory.add({'filename': filename, 'status': 'Failed to upload photo'});
    }

    await _saveHistory();

    final elapsedTime = stopwatch.elapsedMilliseconds / 1000; // seconds
    final uploadedBytes = bytes.length;
    final uploadSpeed = uploadedBytes / elapsedTime / 1024; // kB/s

    _uploadedCount.value++;
    uploadSpeedController.add(uploadSpeed);
  }

  Future<void> _uploadFolder() async {
    if (_client == null) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mov', 'mp4', 'heic'],
    );

    if (result == null || result.count == 0) {
      return;
    }

    _totalCount.value = result.files.length;
    _uploadedCount.value = 0;
    _uploadSpeed.value = 0.0;
    _estimatedTime.value = 0;

    int totalBytes = 0;
    for (var pickedFile in result.files) {
      final file = File(pickedFile.path!);
      totalBytes += await file.length();
    }

    final stopwatch = Stopwatch()..start();

    final uploadSpeedController = StreamController<double>();
    uploadSpeedController.stream.listen((uploadSpeed) {
      _uploadSpeed.value = (_uploadSpeed.value * (_uploadedCount.value - 1) + uploadSpeed) / _uploadedCount.value;
      final remainingBytes = totalBytes - (_uploadSpeed.value * 1024 * stopwatch.elapsedMilliseconds / 1000).toInt();
      final estimatedRemainingTime = remainingBytes / (_uploadSpeed.value * 1024);
      _estimatedTime.value = estimatedRemainingTime.toInt();
    });

    for (var pickedFile in result.files) {
      while (_isPaused) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      final file = File(pickedFile.path!);
      final filename = pickedFile.name;
      await _uploadFile(file, filename, totalBytes, stopwatch, uploadSpeedController);
    }

    uploadSpeedController.close();
  }

  Future<void> _retryFailedUploads() async {
    if (_client == null) return;

    final failedUploads = _uploadHistory.where((item) => item['status'] != 'Success').toList();
    _totalCount.value = failedUploads.length;
    _uploadedCount.value = 0;
    _uploadSpeed.value = 0.0;
    _estimatedTime.value = 0;

    final stopwatch = Stopwatch()..start();
    final uploadSpeedController = StreamController<double>();
    uploadSpeedController.stream.listen((uploadSpeed) {
      _uploadSpeed.value = (_uploadSpeed.value * (_uploadedCount.value - 1) + uploadSpeed) / _uploadedCount.value;
      final remainingBytes = (_totalCount.value * _currentFileSize.value) - (_uploadSpeed.value * 1024 * stopwatch.elapsedMilliseconds / 1000).toInt();
      final estimatedRemainingTime = remainingBytes / (_uploadSpeed.value * 1024);
      _estimatedTime.value = estimatedRemainingTime.toInt();
    });

    for (var upload in failedUploads) {
      while (_isPaused) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      final file = File(upload['filename']);
      final filename = upload['filename'];
      await _uploadFile(file, filename, _totalCount.value * _currentFileSize.value, stopwatch, uploadSpeedController);
    }

    uploadSpeedController.close();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Upload History'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: _uploadHistory.length,
              itemBuilder: (context, index) {
                final historyItem = _uploadHistory[index];
                return ListTile(
                  title: Text(historyItem['filename']),
                  subtitle: Text(historyItem['status']),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google Photos Uploader'),
        actions: <Widget>[
          if (_client != null)
            IconButton(
              icon: Icon(Icons.exit_to_app),
              onPressed: () {
                setState(() {
                  _client = null;
                });
              },
            )
        ],
      ),
      body: Center(
        child: _client != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    child: Text('Upload Folder'),
                    onPressed: _uploadFolder,
                  ),
                  ElevatedButton(
                    child: Text(_isPaused ? 'Resume' : 'Pause'),
                    onPressed: _togglePause,
                  ),
                  ElevatedButton(
                    child: Text('View History'),
                    onPressed: _showHistory,
                  ),
                  ElevatedButton(
                    child: Text('Retry Failed Uploads'),
                    onPressed: _retryFailedUploads,
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _uploadedCount,
                    builder: (context, uploadedCount, child) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _totalCount,
                        builder: (context, totalCount, child) {
                          if (totalCount == 0) return Container();
                          return Column(
                            children: [
                              SizedBox(height: 20),
                              Text('Uploading $uploadedCount / $totalCount files'),
                              SizedBox(height: 20),
                              LinearProgressIndicator(
                                value: uploadedCount / totalCount,
                              ),
                              SizedBox(height: 20),
                              ValueListenableBuilder<double>(
                                valueListenable: _uploadSpeed,
                                builder: (context, uploadSpeed, child) {
                                  return Text('Upload Speed: ${uploadSpeed.toStringAsFixed(2)} kB/s');
                                },
                              ),
                              SizedBox(height: 20),
                              ValueListenableBuilder<int>(
                                valueListenable: _estimatedTime,
                                builder: (context, estimatedTime, child) {
                                  return Text('Estimated Time Remaining: ${estimatedTime.toString()} seconds');
                                },
                              ),
                              SizedBox(height: 20),
                              ValueListenableBuilder<int>(
                                valueListenable: _currentFileSize,
                                builder: (context, currentFileSize, child) {
                                  return Text('Current File Size: ${currentFileSize / 1024} kB');
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              )
            : ElevatedButton(
                child: Text('Sign In with Google'),
                onPressed: _signIn,
              ),
      ),
    );
  }
}
