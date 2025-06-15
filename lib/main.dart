import 'dart:convert';
import 'dart:io';
import 'package:build_distribution_app/bloc/download_bloc.dart';
import 'package:build_distribution_app/data/file_manager.dart';
import 'package:build_distribution_app/entity/folder_entity.dart';
import 'package:build_distribution_app/list_apk_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, dynamic>> loadConfig() async {
  final configString = await rootBundle.loadString('assets/config.json');
  return json.decode(configString);
}

late Directory dir;
late AutoRefreshingAuthClient client;
late FileManager fileManager;

late List<FolderEntity> folders;
late ServiceAccountCredentials serviceAccountCredentials;
late SharedPreferences prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await loadConfig();
  serviceAccountCredentials = ServiceAccountCredentials.fromJson(
    config['service_account'],
  );
  folders = (config['folders'] as List)
      .map((e) => FolderEntity.fromMap(e))
      .toList();
  dir = await getApplicationDocumentsDirectory();
  prefs = await SharedPreferences.getInstance();
  final scopes = [DriveApi.driveReadonlyScope];
  client = await clientViaServiceAccount(serviceAccountCredentials, scopes);
  fileManager = FileManager();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DownloadBloc(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'APK Downloader',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.light,
        ),
        home: const ApkDownloadPage(),
      ),
    );
  }
}

class ApkDownloadPage extends StatefulWidget {
  const ApkDownloadPage({super.key});

  @override
  State<ApkDownloadPage> createState() => _ApkDownloadPageState();
}

class _ApkDownloadPageState extends State<ApkDownloadPage> {
  int selectedFolderIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  void _showEnvBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(folders.length, (i) {
              final isSelected =
                  folders[i].name == folders[selectedFolderIndex].name;
              return ListTile(
                leading: Icon(
                  Icons.cloud_queue,
                  color: isSelected ? Colors.blue : null,
                ),
                title: Text(
                  folders[i].name,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? Colors.blue : null,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    selectedFolderIndex = i;
                  });
                  Navigator.pop(context);
                },
              );
            }),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentFolder = folders[selectedFolderIndex];

    return Scaffold(
      appBar: AppBar(
        leading: Image.asset('assets/log_f.png'),
        title: const Text(
          'Build Distribution',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          GestureDetector(
            onTap: () => _showEnvBottomSheet(context),
            child: Row(
              children: [
                const Icon(Icons.cloud_queue, size: 18),
                const SizedBox(width: 4),
                Text(
                  folders[selectedFolderIndex].name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ],
      ),
      body: DownloaderWrapper(
        child: ListApkWidget(
          keyValue: currentFolder.id,
          key: ValueKey(currentFolder.id),
          folder: currentFolder,
        ),
      ),
    );
  }
}

class DownloaderWrapper extends StatefulWidget {
  final Widget child;
  const DownloaderWrapper({super.key, required this.child});

  @override
  State<DownloaderWrapper> createState() => DownloaderWrapperState();
}

class DownloaderWrapperState extends State<DownloaderWrapper> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final showProgress = state.isQueueRunning;
        return Column(
          children: [
            if (showProgress)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.fileName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: state.prograess,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(state.prograess * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}
