import 'package:build_distribution_app/entity/folder_entity.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:build_distribution_app/main.dart';
import 'package:build_distribution_app/apk_widget.dart';

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
  List<drive.File> files = <drive.File>[];
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

    setState(() {
      files = fileList.files ?? <drive.File>[];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizedBox.expand(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Заголовок с кнопкой обновления
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 2,
            title: const Text(
              'Доступные APK',
              style: TextStyle(fontWeight: FontWeight.w600),
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
                  file: files[i],
                  packageName: widget.folder.package,
                );
              }, childCount: files.length),
            ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
