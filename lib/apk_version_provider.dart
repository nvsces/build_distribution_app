import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

class ApkVersionProvider extends StatefulWidget {
  final Widget child;
  final String package;

  const ApkVersionProvider({
    super.key,
    required this.child,
    required this.package,
  });

  static _ApkVersionProviderState of(BuildContext context) {
    final _InheritedApkVersion? inherited = context
        .dependOnInheritedWidgetOfExactType<_InheritedApkVersion>();
    assert(inherited != null, 'No AppVersionProvider found in context');
    return inherited!.data;
  }

  @override
  State<ApkVersionProvider> createState() => _ApkVersionProviderState();
}

class _ApkVersionProviderState extends State<ApkVersionProvider> {
  String _version = '';
  String _buildNumber = '';

  bool _isInstalled = false;

  String get version => _version;
  String get buildNumber => _buildNumber;

  bool get isInstalled => _isInstalled;

  @override
  void initState() {
    super.initState();
    update();
  }

  Future<void> update() async {
    final info = await InstalledApps.getAppInfo(
      widget.package,
      BuiltWith.flutter,
    );

    setState(() {
      _isInstalled = info != null;
      _version = info?.versionName ?? '';
      _buildNumber = '${info?.versionCode ?? ''}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedApkVersion(data: this, child: widget.child);
  }
}

class _InheritedApkVersion extends InheritedWidget {
  final _ApkVersionProviderState data;

  const _InheritedApkVersion({required this.data, required super.child});

  @override
  bool updateShouldNotify(_InheritedApkVersion oldWidget) {
    return true;
  }
}
