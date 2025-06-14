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

Future<Map<String, dynamic>> loadConfig() async {
  final configString = await rootBundle.loadString('assets/config.json');
  return json.decode(configString);
}

late Directory dir;
late AutoRefreshingAuthClient client;
late FileManager fileManager;

late List<FolderEntity> folders;
late ServiceAccountCredentials serviceAccountCredentials;

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
  _ApkDownloadPageState createState() => _ApkDownloadPageState();
}

class _ApkDownloadPageState extends State<ApkDownloadPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: folders.length,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text(
            'Загрузка и установка APK',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 4,
          shadowColor: Colors.black26,
          bottom: TabBar(
            indicatorColor: Colors.indigo,
            labelStyle: TextStyle(fontWeight: FontWeight.w600),
            tabs: List.generate(folders.length, (i) {
              final key = folders[i].name;
              return Tab(text: key);
            }),
          ),
        ),
        body: DownloaderWrapper(
          child: TabBarView(
            children: List.generate(folders.length, (i) {
              final key = folders[i].id;
              return ListApkWidget(
                keyValue: key,
                key: ValueKey(i),
                folder: folders[i],
              );
            }),
          ),
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
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${state.fileName} \n${state.prograess * 100}%',
                        style: Theme.of(context).textTheme.bodyLarge,
                        overflow: TextOverflow.ellipsis,
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
