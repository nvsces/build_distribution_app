import 'dart:collection';
import 'dart:io' as io;

import 'package:build_distribution_app/main.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class FileManager {
  Future<io.File> downloadFileWithProgress({
    required String fileId,
    required String fileName,
    required void Function(double progress) onProgress,
  }) async {
    final scopes = [DriveApi.driveReadonlyScope];
    final client = await clientViaServiceAccount(
      serviceAccountCredentials,
      scopes,
    );
    // Загрузка через stream
    final url = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);
    final totalBytes = response.contentLength ?? 1.0;
    final path = '${dir.path}/$fileName';

    final file = io.File('$path.download');

    if (file.existsSync()) {
      await file.delete();
    }
    final sink = file.openWrite();

    int downloaded = 0;
    try {
      await response.stream
          .listen(
            (chunk) {
              downloaded += chunk.length;
              onProgress(downloaded / totalBytes);
              sink.add(chunk);
            },
            onError: (e) async {
              await sink.close();
              print('❌ Ошибка при загрузке: $e');
            },
            cancelOnError: true,
          )
          .asFuture();

      print('ondone');
      await sink.close();

      print('✅ Файл загружен: ${file.path}');
      client.close();
      file.rename(path);
      return file;
    } catch (e) {
      print('Ошибка во время загрузки: $e');
      client.close();
      rethrow;
    }
  }
}

final downloadQueue = Queue<Future Function()>();

bool isQueueRunning = false;

void enqueueDownload(Future Function() downloadTask) {
  downloadQueue.add(downloadTask);
  if (!isQueueRunning) {
    runNextInQueue();
  }
}

void runNextInQueue() async {
  if (downloadQueue.isEmpty) {
    isQueueRunning = false;
    return;
  }
  isQueueRunning = true;
  final task = downloadQueue.removeFirst();
  try {
    await task();
  } catch (e) {
    print('❌ Ошибка в задаче загрузки: $e');
  } finally {
    runNextInQueue();
  }
}
