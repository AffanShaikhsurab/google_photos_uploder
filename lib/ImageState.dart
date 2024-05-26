

import 'package:oauth2/oauth2.dart';

class ImagesState {
  final List<Map<String, dynamic>> uploadHistory;
  final bool isPaused;
  final int uploadedCount;
  final int totalCount;
  final double uploadSpeed;
  final int estimatedTime;
  final int currentFileSize;
  final Client? client;

  ImagesState({
    required this.uploadHistory,
    required this.isPaused,
    required this.uploadedCount,
    required this.totalCount,
    required this.uploadSpeed,
    required this.estimatedTime,
    required this.currentFileSize,
    required this.client,
  });

  ImagesState copyWith({
    List<Map<String, dynamic>>? uploadHistory,
    bool? isPaused,
    int? uploadedCount,
    int? totalCount,
    double? uploadSpeed,
    int? estimatedTime,
    int? currentFileSize,
     Client? client,
  }) {
    return ImagesState(
      uploadHistory: uploadHistory ?? this.uploadHistory,
      isPaused: isPaused ?? this.isPaused,
      uploadedCount: uploadedCount ?? this.uploadedCount,
      totalCount: totalCount ?? this.totalCount,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      currentFileSize: currentFileSize ?? this.currentFileSize,
      client: client ?? this.client,
    );
  }
}
