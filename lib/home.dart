
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pics_uploder/ImageCubit_state.dart';
import 'package:pics_uploder/ImageState.dart';
import 'package:animations/animations.dart';
import 'package:pics_uploder/gallery.dart';

class SignInDemo extends StatefulWidget {
  @override
  _SignInDemoState createState() => _SignInDemoState();
}

class _SignInDemoState extends State<SignInDemo> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImagesCubit, ImagesState>(
      builder: (context, state) {
        if (state.client == null) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.read<ImagesCubit>().signIn(),
                child: const Text('Sign In with Google'),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Photos'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  // Implement search functionality
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  // Implement more options
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => context.read<ImagesCubit>().uploadFolder(),
                      child: const Text('Upload Folder'),
                    ),
                    const SizedBox(width: 16.0),
                    ElevatedButton(
                      onPressed: () => _showHistory(context),
                      child: const Text('View History'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: state.uploadHistory.length,
                  itemBuilder: (context, index) {
                    final historyItem = state.uploadHistory[index];
                    return OpenContainer(
                      openBuilder: (context, action) => Gallery(heicBytes: historyItem['fileBytes']),
                      closedElevation: 0.0,
                      closedShape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                      openColor: Colors.black.withOpacity(0.5),
                      closedColor: Colors.transparent,
                      transitionDuration: const Duration(milliseconds: 500),
                      closedBuilder: (context, action) => GestureDetector(
                        onTap: action,
                        child: Hero(
                          tag: 'image_$index',
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                              image: DecorationImage(
                                image: MemoryImage(historyItem['fileBytes']),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () => context.read<ImagesCubit>().pauseUpload(),
                      child: const Text('Pause Upload'),
                    ),
                    ElevatedButton(
                      onPressed: () => context.read<ImagesCubit>().resumeUpload(),
                      child: const Text('Resume Upload'),
                    ),
                    ElevatedButton(
                      onPressed: () => context.read<ImagesCubit>().resetUpload(),
                      child: const Text('Reset Upload'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: ${state.totalCount}'),
                    Text('Uploaded: ${state.uploadedCount}'),
                    Text('Upload Speed: ${state.uploadSpeed.toStringAsFixed(2)} kB/s'),
                    Text('Estimated Time Remaining: ${state.estimatedTime} s'),
                    if (state.totalCount > 0) ...[
                      const SizedBox(height: 10.0),
                      LinearProgressIndicator(
                        value: state.uploadedCount / state.totalCount,
                        semanticsLabel: 'Upload progress',
                        valueColor: _animationController.drive(
                          ColorTween(
                            begin: Colors.red,
                            end: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      Text('Progress: ${(state.uploadedCount / state.totalCount * 100).toStringAsFixed(2)}%'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHistory(BuildContext context) {
    final _uploadHistory = context.read<ImagesCubit>().state.uploadHistory;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upload History',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _uploadHistory.length,
                  itemBuilder: (context, index) {
                    final historyItem = _uploadHistory[index];
                    return ListTile(
                      title: Text(historyItem['filename']),
                      subtitle: Text(historyItem['status']),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Gallery(heicBytes: historyItem['fileBytes']),
                          ),
                        );
                      },
                    );
                  },
                ),
                ),
            ],
          ),
        );
      },
    );
  }
}
