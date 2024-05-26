import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fw_dltime/fw_dltime.dart';
import 'package:bloc/bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:pics_uploder/ImageState.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ImagesCubit extends Cubit<ImagesState> {
  ImagesCubit()
      : super(ImagesState(
          uploadHistory: [],
          isPaused: false,
          uploadedCount: 0,
          totalCount: 0,
          uploadSpeed: 0.0,
          estimatedTime: 0,
          currentFileSize: 0,
          client: null,
        ));


  final authorizationEndpoint = Uri.parse('https://accounts.google.com/o/oauth2/auth');
  final tokenEndpoint = Uri.parse('https://oauth2.googleapis.com/token');
  final identifier = '99345842123-qmj0uj6l5v2dosdbhsdredcfveokp10m.apps.googleusercontent.com';
  final secret = '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';
  final redirectUrl = Uri.parse('http://localhost:8080');
  final scopes = ['https://www.googleapis.com/auth/photoslibrary'];

  Future<void> initialize() async {
    await _loadHistory();
    await _loadClient();
    await _loadUploadState();

    if (state.uploadHistory.any((upload) => upload['status'] != 'Success')) {
      await _retryFailedUploads();
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString('uploadHistory');
    if (historyString != null) {
      emit(state.copyWith(uploadHistory: List<Map<String, dynamic>>.from(jsonDecode(historyString))));
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uploadHistory', jsonEncode(state.uploadHistory));
  }

  Future<void> _saveClient(oauth2.Client client) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clientCredentials', jsonEncode(client.credentials.toJson()));
  }

  Future<void> _loadClient() async {
    final prefs = await SharedPreferences.getInstance();
    final credentialsJson = prefs.getString('clientCredentials');
    if (credentialsJson != null) {
      final credentials = oauth2.Credentials.fromJson(jsonDecode(credentialsJson));
      emit(state.copyWith(client: oauth2.Client(credentials, identifier: identifier, secret: secret)));
    }
  }

  Future<void> _saveUploadState() async {
    final prefs = await SharedPreferences.getInstance();
    final uploadState = {
      'isPaused': state.isPaused,
      'uploadedCount': state.uploadedCount,
      'totalCount': state.totalCount,
      'uploadHistory': state.uploadHistory,
    };
    await prefs.setString('uploadState', jsonEncode(uploadState));
  }

  Future<void> _loadUploadState() async {
    final prefs = await SharedPreferences.getInstance();
    final uploadStateString = prefs.getString('uploadState');
    if (uploadStateString != null) {
      final uploadState = jsonDecode(uploadStateString);
      emit(state.copyWith(
        isPaused: uploadState['isPaused'],
        uploadedCount: uploadState['uploadedCount'],
        totalCount: uploadState['totalCount'],
        uploadHistory: List<Map<String, dynamic>>.from(uploadState['uploadHistory']),
      ));
    }
  }

  Future<void> signIn() async {
    final grant = oauth2.AuthorizationCodeGrant(identifier, authorizationEndpoint, tokenEndpoint, secret: secret);
    final authorizationUrl = grant.getAuthorizationUrl(redirectUrl, scopes: scopes);

    if (await canLaunch(authorizationUrl.toString())) {
      await launch(authorizationUrl.toString());
    } else {
      throw 'Could not launch $authorizationUrl';
    }

    final responseUrl = await listenForRedirect(redirectUrl);
    final client = await grant.handleAuthorizationResponse(responseUrl.queryParameters);

    await _saveClient(client);

    emit(state.copyWith(client: client));
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

   FwDltime? _fwDltime;
Future<void> uploadFolder() async {
    if (state.client == null) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mov', 'mp4', 'heic'],
    );

    if (result == null || result.count == 0) {
      return;
    }

    emit(state.copyWith(totalCount: result.files.length, uploadedCount: 0, uploadSpeed: 0.0, estimatedTime: 0));

    int totalBytes = 0;

    for (var pickedFile in result.files) {
      final file = File(pickedFile.path!);
      totalBytes += await file.length();
    }

    _fwDltime = FwDltime(debug: true, fwRevision: 'upload');
    final stopwatch = Stopwatch()..start();

    final uploadSpeedController = StreamController<double>();
uploadSpeedController.stream.listen((uploadSpeed) {
  final updatedUploadSpeed = (state.uploadSpeed * (state.uploadedCount - 1) + uploadSpeed) / state.uploadedCount;
  final uploadedBytes = state.uploadedCount * (totalBytes / state.totalCount);
  final remainingBytes = totalBytes - uploadedBytes;
  final estimatedRemainingTime = remainingBytes / (updatedUploadSpeed * 1024);
  emit(state.copyWith(uploadSpeed: updatedUploadSpeed, estimatedTime: estimatedRemainingTime.toInt()));
});

    for (var pickedFile in result.files) {
      while (state.isPaused) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      final file = File(pickedFile.path!);
      final filename = pickedFile.name;
      await _uploadFile(file, filename, totalBytes, stopwatch, uploadSpeedController);
    }

    uploadSpeedController.close();
  }

  Future<void> _uploadFile(File file, String filename, int totalBytes, Stopwatch stopwatch, StreamController<double> uploadSpeedController) async {
    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;
    emit(state.copyWith(currentFileSize: fileSize));

    final uploadTokenResponse = await state.client!.post(
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

      final createMediaItemResponse = await state.client!.post(
        Uri.parse('https://photoslibrary.googleapis.com/v1/mediaItems:batchCreate'),
        headers: {
          'Content-type': 'application/json',
        },
        body: jsonEncode({
          'newMediaItems': [
            {
              'description': '',
              'simpleMediaItem': {
                'uploadToken': uploadToken,
              }
            }
          ]
        }),
      );

      if (createMediaItemResponse.statusCode == 200) {
        state.uploadHistory.add({'filename': filename, 'status': 'Success', 'fileBytes': bytes});
      } else {
        state.uploadHistory.add({'filename': filename, 'status': 'Failed to create media item', 'fileBytes': bytes});
      }
    } else {
      state.uploadHistory.add({'filename': filename, 'status': 'Failed to upload photo', 'fileBytes': bytes});
    }

    await _saveHistory();

    final elapsedTime = stopwatch.elapsedMilliseconds / 1000; // seconds
    final uploadedBytes = bytes.length;
    final uploadSpeed = uploadedBytes / elapsedTime / 1024; // kB/s

    emit(state.copyWith(uploadedCount: state.uploadedCount + 1));
    uploadSpeedController.add(uploadSpeed);
  }
  Future<void> _retryFailedUploads() async {
    if (state.client == null) return;

    final failedUploads = state.uploadHistory.where((item) => item['status'] != 'Success').toList();
    emit(state.copyWith(totalCount: failedUploads.length, uploadedCount: 0, uploadSpeed: 0.0, estimatedTime: 0));

    final stopwatch = Stopwatch()..start();
    final uploadSpeedController = StreamController<double>();
    uploadSpeedController.stream.listen((uploadSpeed) {
      final updatedUploadSpeed = (state.uploadSpeed * (state.uploadedCount - 1) + uploadSpeed) / state.uploadedCount;
      final remainingBytes = failedUploads.length - (updatedUploadSpeed * 1024 * stopwatch.elapsedMilliseconds / 1000).toInt();
      final estimatedRemainingTime = remainingBytes / (updatedUploadSpeed * 1024);
      emit(state.copyWith(uploadSpeed: updatedUploadSpeed, estimatedTime: estimatedRemainingTime.toInt()));
    });

    for (var item in failedUploads) {
      final bytes = item['fileBytes'] as Uint8List;
      final filename = item['filename'] as String;
      await _uploadFile(File.fromRawPath(bytes), filename, bytes.length, stopwatch, uploadSpeedController);
    }

    uploadSpeedController.close();
  }

  Future<void> pauseUpload() async {
    emit(state.copyWith(isPaused: true));
    await _saveUploadState();
  }

  Future<void> resumeUpload() async {
    emit(state.copyWith(isPaused: false));
    await _saveUploadState();
  }

  Future<void> resetUpload() async {
    emit(state.copyWith(
      isPaused: false,
      uploadedCount: 0,
      totalCount: 0,
      uploadSpeed: 0.0,
      estimatedTime: 0,
      currentFileSize: 0,
      uploadHistory: [],
    ));
    await _saveHistory();
    await _saveUploadState();
  }
}
