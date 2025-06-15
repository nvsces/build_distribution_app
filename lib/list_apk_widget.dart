import 'package:build_distribution_app/apk_version_provider.dart';
import 'package:build_distribution_app/entity/build_item.dart';
import 'package:build_distribution_app/entity/folder_entity.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:build_distribution_app/main.dart';
import 'package:build_distribution_app/apk_widget.dart';

const apkMimeType = "application/vnd.android.package-archive";
const textMimeType = "text/plain";

class ListApkWidget extends StatefulWidget {
  final String keyValue;
  final FolderEntity folder;
  const ListApkWidget({
    super.key,
    required this.keyValue,
    required this.folder,
  });

  @override
  State<ListApkWidget> createState() => _ListApkWidgetState();
}

class _ListApkWidgetState extends State<ListApkWidget>
    with AutomaticKeepAliveClientMixin {
  List<BuildItem> files = <BuildItem>[];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    listFilesInFolder();
  }

  Future<void> listFilesInFolder() async {
    setState(() => isLoading = true);
    final driveApi = drive.DriveApi(client);

    final fileList = await driveApi.files.list(
      q: "'${widget.folder.id}' in parents and trashed = false",
      $fields: 'files(id, name, mimeType)',
    );

    final allFiles = fileList.files ?? <drive.File>[];

    // Разделим на apk и txt файлы
    final apkFiles = <String, drive.File>{};
    final txtFiles = <String, drive.File>{};

    for (final file in allFiles) {
      final name = file.name ?? '';
      if (file.mimeType == apkMimeType && name.endsWith('.apk')) {
        final baseName = name.replaceAll(RegExp(r'\.apk$'), '');
        apkFiles[baseName] = file;
      } else if (file.mimeType == textMimeType && name.endsWith('.txt')) {
        final baseName = name.replaceAll(RegExp(r'\.txt$'), '');
        txtFiles[baseName] = file;
      }
    }

    final List<BuildItem> buildItems = [];

    for (final entry in apkFiles.entries) {
      final apkFile = entry.value;
      final txtFile = txtFiles[entry.key];

      buildItems.add(BuildItem(apkFile: apkFile, txtFile: txtFile));
    }

    setState(() {
      files = buildItems;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ApkVersionProvider(
      package: widget.folder.package,
      child: SizedBox.expand(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 2,
              title: const Text(
                'Доступные APK',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Обновить список',
                  onPressed: listFilesInFolder,
                ),
              ],
            ),

            CupertinoSliverRefreshControl(onRefresh: listFilesInFolder),

            if (isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (files.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Нет доступных файлов')),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final key = ValueKey('$i=${widget.folder.package}');
                  return ApkWidget(
                    key: key,
                    item: files[i],
                    packageName: widget.folder.package,
                  );
                }, childCount: files.length),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
