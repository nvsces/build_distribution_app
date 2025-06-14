import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:build_distribution_app/bloc/download_bloc.dart';
import 'package:build_distribution_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:open_file/open_file.dart';

const apiKey = 'AIzaSyCawdEsGKARCuxOO1KbqOk5h2fUjPZd7y4';

class ApkWidget extends StatefulWidget {
  final drive.File file;
  final String packageName;
  const ApkWidget({super.key, required this.file, required this.packageName});

  @override
  State<ApkWidget> createState() => _ApkWidgetState();
}

class _ApkWidgetState extends State<ApkWidget> {
  static const platform = MethodChannel('apk_install_channel');

  @override
  void initState() {
    _checkInstalled();
    localFile = getCurrentFile(widget.file.name ?? '');
    super.initState();
  }

  bool isDownloading = false;
  String progress = '';
  File? downloadedApk;
  bool isInstalled = false;

  Map<String, String> parseBuildInfo(String input) {
    final buildNameRegex = RegExp(r'^([\d\.]+)');
    final buildNumberRegex = RegExp(r'\((\d+)\)');

    final buildNameMatch = buildNameRegex.firstMatch(input);
    final buildNumberMatch = buildNumberRegex.firstMatch(input);

    final buildName = buildNameMatch?.group(1);
    final buildNumber = buildNumberMatch?.group(1);

    if (buildName == null || buildNumber == null) {
      throw FormatException('Строка не соответствует ожидаемому формату');
    }

    return {'buildName': buildName, 'buildNumber': buildNumber};
  }

  Future<bool> canInstallApk() async {
    try {
      final result = await platform.invokeMethod<bool>('canInstallApk');
      return result ?? false;
    } on PlatformException {
      print('PlatformException');
      return false;
    }
  }

  String currentAppName = '';
  String currentBuildNumber = '';

  String serverAppName = '';
  String serverBuildNumber = '';

  File? localFile;

  Future<void> _checkInstalled() async {
    final installed = await InstalledApps.isAppInstalled(widget.packageName);
    final info = await InstalledApps.getAppInfo(
      widget.packageName,
      BuiltWith.flutter,
    );
    final buildInfo = parseBuildInfo(widget.file.name ?? '');

    setState(() {
      isInstalled = installed ?? false;
      currentAppName = info?.versionName ?? '';
      currentBuildNumber = '${info?.versionCode}';
      serverAppName = buildInfo['buildName'] ?? '';
      serverBuildNumber = buildInfo['buildNumber'] ?? '';
    });
  }

  Widget getButton() {
    final currentFile = getCurrentFile(widget.file.name ?? '');
    if (currentFile != null) {
      if (currentAppName == serverAppName &&
          serverBuildNumber == currentBuildNumber &&
          isInstalled) {
        return ElevatedButton(
          onPressed: () {
            InstalledApps.startApp(widget.packageName);
          },
          child: Text('Открыть'),
        );
      }
    }
    if (currentFile != null) {
      final state = context.read<DownloadBloc>().state;
      return ElevatedButton(
        onPressed: state.isQueueRunning
            ? null
            : () {
                installApk(currentFile);
              },
        child: Text('Установить'),
      );
    }
    return downloadedApk != null
        ? ElevatedButton(
            onPressed: () {
              installApk(downloadedApk);
            },
            child: Text('Установить'),
          )
        : isDownloading
        ? Text('Загрузка... $progress')
        : ElevatedButton(
            onPressed: context.read<DownloadBloc>().state.isQueueRunning
                ? null
                : () {
                    context.read<DownloadBloc>().add(
                      DownloadStartEvent(
                        fileId: widget.file.id ?? '',
                        fileName:
                            '${widget.packageName}-${widget.file.name ?? ''}',
                      ),
                    );
                  },
            child: Text('Скачать'),
          );
  }

  File? getCurrentFile(String fileName) {
    final file = File('${dir.path}/${widget.packageName}-$fileName');
    if (file.existsSync()) {
      return file;
    }
    return null;
  }

  Future<void> downloadFileWithProgress({
    required String fileId,
    required String fileName,
    required void Function(double progress) onProgress,
  }) async {
    setState(() {
      isDownloading = true;
      progress = '';
      downloadedApk = null;
    });

    final file = await fileManager.downloadFileWithProgress(
      fileId: fileId,
      fileName: fileName,
      onProgress: onProgress,
    );

    setState(() {
      downloadedApk = file;
    });
  }

  Future<void> openInstallPermissionSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
      data:
          'package:com.example.build_distribution_app', // замени на свой packageName
    );
    await intent.launch();
  }

  Future<void> installApk(File? file) async {
    if (file != null && await file.exists()) {
      bool canInstall = await canInstallApk();
      if (!canInstall) {
        openInstallPermissionSettings();
        return;
      }

      try {
        final result = await OpenFile.open(file.path);
        print(result);
        setState(() {});
      } catch (e) {
        print('Ошибка установки APK: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.android, color: Colors.green, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.file.name ?? 'Неизвестный файл',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [_buildVersionInfo(), getButton()],
                  ),
                  if (isDownloading) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: double.tryParse(progress) ?? 0,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Загрузка... $progress%',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сервер: $serverAppName ($serverBuildNumber)',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        Text(
          'Установлено: $currentAppName ($currentBuildNumber)',
          style: TextStyle(
            fontSize: 12,
            color: isInstalled ? Colors.green : Colors.redAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    String label;
    Color color;

    if (isInstalled &&
        currentAppName == serverAppName &&
        currentBuildNumber == serverBuildNumber) {
      label = 'Установлено';
      color = Colors.green;
    } else if (isInstalled) {
      label = 'Нужна переустановка';
      color = Colors.orange;
    } else {
      label = 'Не установлено';
      color = Colors.red;
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
      shape: StadiumBorder(side: BorderSide(color: color)),
    );
  }
}
