// lib/main.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:url_launcher/url_launcher.dart';

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
  final authorizationEndpoint =
      Uri.parse('https://accounts.google.com/o/oauth2/auth');
  final tokenEndpoint = Uri.parse('https://oauth2.googleapis.com/token');
  final identifier = '99345842123-qmj0uj6l5v2dosdbhsdredcfveokp10m.apps.googleusercontent.com';
  final secret = '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';
  final redirectUrl = Uri.parse('http://localhost:8080');
  final scopes = ['https://www.googleapis.com/auth/photoslibrary'];

  oauth2.Client? _client;

  Future<void> _signIn() async {
    final grant = oauth2.AuthorizationCodeGrant(
        identifier, authorizationEndpoint, tokenEndpoint,
        secret: secret);
    final authorizationUrl = grant.getAuthorizationUrl(redirectUrl,
        scopes: scopes);

    // Launch the authorization URL in the user's browser
    if (await canLaunch(authorizationUrl.toString())) {
      await launch(authorizationUrl.toString());
    } else {
      throw 'Could not launch $authorizationUrl';
    }

    // Listen on a local port for the redirect from the authorization server
    final responseUrl = await listenForRedirect(redirectUrl);

    // Handle the redirect response and obtain the credentials
    _client = await grant.handleAuthorizationResponse(
        responseUrl.queryParameters);

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

  Future<void> _uploadPhoto() async {
    if (_client == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();
    final filename = pickedFile.name;

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
        print('Photo uploaded successfully!');
      } else {
        print('Failed to create media item.');
      }
    } else {
      print('Failed to upload photo.');
    }
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
                    child: Text('Upload Photo'),
                    onPressed: _uploadPhoto,
                  ),
                ],
              )
            : ElevatedButton(
                child: Text('Sign in with Google'),
                onPressed: _signIn,
              ),
      ),
    );
  }
}
