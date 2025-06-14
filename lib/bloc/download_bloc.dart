import 'dart:collection';

import 'package:build_distribution_app/data/file_manager.dart';
import 'package:build_distribution_app/main.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DownloadState {
  final Queue<Future<dynamic> Function()> downloadQueue;
  final bool isQueueRunning;
  final double prograess;
  final String fileName;

  const DownloadState({
    required this.downloadQueue,
    required this.prograess,
    required this.isQueueRunning,
    required this.fileName,
  });

  DownloadState copyWith({
    Queue<Future<dynamic> Function()>? downloadQueue,
    bool? isQueueRunning,
    double? prograess,
    String? fileName,
  }) {
    return DownloadState(
      fileName: fileName ?? this.fileName,
      downloadQueue: downloadQueue ?? this.downloadQueue,
      isQueueRunning: isQueueRunning ?? this.isQueueRunning,
      prograess: prograess ?? this.prograess,
    );
  }
}

sealed class DownloadEvent {}

class DownloadStartEvent extends DownloadEvent {
  final String fileName;
  final String fileId;

  DownloadStartEvent({required this.fileName, required this.fileId});
}

class DownloadStopEvent extends DownloadEvent {}

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  DownloadBloc()
    : super(
        DownloadState(
          downloadQueue: Queue<Future Function()>(),
          prograess: 0.0,
          isQueueRunning: false,
          fileName: '',
        ),
      ) {
    on<DownloadStopEvent>(_stop);
    on<DownloadStartEvent>(_start);
  }

  Future<void> _start(
    DownloadStartEvent event,
    Emitter<DownloadState> emitter,
  ) async {
    emitter(state.copyWith(isQueueRunning: true, fileName: event.fileName));
    final file = await fileManager.downloadFileWithProgress(
      fileId: event.fileId,
      fileName: event.fileName,
      onProgress: (p) {
        emitter(state.copyWith(prograess: p));
      },
    );
    emitter(state.copyWith(isQueueRunning: false, fileName: ''));
  }

  Future<void> _stop(
    DownloadStopEvent event,
    Emitter<DownloadState> emitter,
  ) async {}
}
