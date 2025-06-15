import 'package:googleapis/drive/v3.dart' as drive;

class BuildItem {
  final drive.File apkFile;
  final drive.File? txtFile;

  BuildItem({required this.apkFile, required this.txtFile});
}
