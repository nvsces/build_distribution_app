import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:build_distribution_app/apk_version_provider.dart';
import 'package:build_distribution_app/bloc/download_bloc.dart';
import 'package:build_distribution_app/entity/build_item.dart';
import 'package:build_distribution_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:installed_apps/installed_apps.dart';
import 'package:open_file/open_file.dart';

class ApkWidget extends StatefulWidget {
  final BuildItem item;
  final String packageName;

  const ApkWidget({super.key, required this.item, required this.packageName});

  @override
  State<ApkWidget> createState() => _ApkWidgetState();
}

class _ApkWidgetState extends State<ApkWidget> with WidgetsBindingObserver {
  static const platform = MethodChannel('apk_install_channel');

  String get filename => widget.item.apkFile.name ?? "";

  bool isDownloading = false;
  String progress = '';
  File? downloadedApk;

  String? description;
  String serverAppName = '';
  String serverBuildNumber = '';
  File? localFile;

  bool shouldCheckInstalled = true;

  @override
  void initState() {
    _checkInstalled();
    localFile = getCurrentFile(filename);
    if (widget.item.txtFile != null) {
      _loadDescription(widget.item.txtFile!);
    }
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print(state);
    if (state == AppLifecycleState.resumed) {
      if (shouldCheckInstalled) {
        ApkVersionProvider.of(context).update();
        shouldCheckInstalled = false;
      }
    }
  }

  @override
  void didChangeDependencies() {
    setState(() {
      _checkInstalled();
    });
    super.didChangeDependencies();
  }

  void showOldVersionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 16,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.system_update_alt_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Установка старой версии',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  'Перед установкой старой версии необходимо удалить текущую.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          uninstallCurrentApp();
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Ок'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadDescription(drive.File txtFile) async {
    final txtFileId = txtFile.id;
    if (txtFileId == null) return;
    final localText = prefs.getString(txtFileId);
    if (localText != null) {
      setState(() => description = localText);
      return;
    }
    final driveApi = drive.DriveApi(client);
    final media =
        await driveApi.files.get(
              txtFile.id!,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final contents = await media.stream.transform(utf8.decoder).join();
    await prefs.setString(txtFileId, contents);
    setState(() => description = contents);
  }

  Map<String, String> parseBuildInfo(String input) {
    final buildNameMatch = RegExp(r'^([\d\.]+)').firstMatch(input);
    final buildNumberMatch = RegExp(r'\((\d+)\)').firstMatch(input);
    return {
      'buildName': buildNameMatch?.group(1) ?? '',
      'buildNumber': buildNumberMatch?.group(1) ?? '',
    };
  }

  Future<void> _checkInstalled() async {
    final buildInfo = parseBuildInfo(filename);

    setState(() {
      // currentAppName = info?.versionName ?? '';
      // currentBuildNumber = '${info?.versionCode ?? ''}';
      serverAppName = buildInfo['buildName']!;
      serverBuildNumber = buildInfo['buildNumber']!;
    });
  }

  Future<bool> canInstallApk() async {
    try {
      return await platform.invokeMethod<bool>('canInstallApk') ?? false;
    } on PlatformException {
      return false;
    }
  }

  File? getCurrentFile(String fileName) {
    final file = File('${dir.path}/${widget.packageName}-$fileName');
    return file.existsSync() ? file : null;
  }

  Future<void> openInstallPermissionSettings() async {
    final intent = AndroidIntent(
      action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
      data: null,
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      arguments: <String, dynamic>{'package': 'app.nvsces.dba'},
    );
    await intent.launch();
  }

  Future<void> uninstallCurrentApp() async {
    final intent = AndroidIntent(
      action: 'android.intent.action.DELETE',
      data: 'package:${widget.packageName}',
    );
    await intent.launch();
    shouldCheckInstalled = true;
  }

  Future<void> installApk(File? file) async {
    if (file == null || !await file.exists()) return;
    if (!await canInstallApk()) {
      await openInstallPermissionSettings();
      return;
    }

    final currentBuildNumber = ApkVersionProvider.of(context).buildNumber;

    if (currentBuildNumber.isNotEmpty &&
        int.parse(currentBuildNumber) > int.parse(serverBuildNumber)) {
      showOldVersionDialog(context);
      return;
    }

    try {
      shouldCheckInstalled = true;
      await OpenFile.open(file.path);
    } catch (e) {
      print('Ошибка установки APK: $e');
    }
  }

  Widget getStyledActionButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        side: BorderSide(color: Colors.blue),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      child: Text(label),
    );
  }

  Widget getButton() {
    final currentFile = getCurrentFile(filename);
    final state = context.read<DownloadBloc>().state;
    final currentBuildNumber = ApkVersionProvider.of(context).buildNumber;
    final currentAppName = ApkVersionProvider.of(context).version;
    final isInstalled = ApkVersionProvider.of(context).isInstalled;
    if (currentAppName == serverAppName &&
        currentBuildNumber == serverBuildNumber &&
        isInstalled) {
      return _actionButton('Открыть', () {
        InstalledApps.startApp(widget.packageName);
      });
    }

    if (currentFile != null) {
      return _actionButton(
        'Установить',
        state.isQueueRunning ? null : () => installApk(currentFile),
      );
    }

    if (downloadedApk != null) {
      return _actionButton('Установить', () => installApk(downloadedApk));
    }

    if (isDownloading) {
      return Text('Загрузка... $progress', style: _smallGreyStyle());
    }

    return _actionButton(
      'Скачать',
      state.isQueueRunning
          ? null
          : () {
              context.read<DownloadBloc>().add(
                DownloadStartEvent(
                  fileId: widget.item.apkFile.id ?? '',
                  fileName: '${widget.packageName}-$filename',
                ),
              );
            },
    );
  }

  Widget _actionButton(String text, VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: onPressed == null ? Colors.grey : Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Text(text),
    );
  }

  Widget _buildVersionInfo() {
    final currentBuildNumber = ApkVersionProvider.of(context).buildNumber;
    final currentAppName = ApkVersionProvider.of(context).version;
    final isInstalled = ApkVersionProvider.of(context).isInstalled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сервер: $serverAppName ($serverBuildNumber)',
          style: _smallGreyStyle(),
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

  TextStyle _smallGreyStyle() =>
      const TextStyle(fontSize: 12, color: Colors.black54);

  Widget buildStatusChip(String label, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget buildStatus() {
    final isInstalled = ApkVersionProvider.of(context).isInstalled;
    final currentBuildNumber = ApkVersionProvider.of(context).buildNumber;
    if (isInstalled && currentBuildNumber == serverBuildNumber) {
      return buildStatusChip(
        'Установлено',
        Colors.grey.shade200,
        Colors.grey.shade800,
      );
    } else if (isInstalled && currentBuildNumber != serverBuildNumber) {
      return buildStatusChip(
        'Доступно обновление',
        Colors.blue.shade50,
        Colors.blue.shade800,
      );
    } else {
      return buildStatusChip(
        'Не установлено',
        Colors.red.shade50,
        Colors.red.shade700,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/ic_launcher.png',
                      width: 40,
                      height: 40,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.android,
                          color: Colors.green,
                          size: 40,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      filename,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  buildStatus(),
                ],
              ),
              const SizedBox(height: 16),
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
                const SizedBox(height: 6),
                Text('Загрузка... $progress%', style: _smallGreyStyle()),
              ],
              if (description != null) ...[
                const Divider(height: 24),
                Text(description!, style: const TextStyle(fontSize: 14)),
              ],
            ],
          ),
        );
      },
    );
  }
}
