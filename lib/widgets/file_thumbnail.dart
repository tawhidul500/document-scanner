import 'package:pdf_scanner/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../data/document_store.dart';

/// Reference artwork, including its original outline, badge and tile border.
/// Files are represented by type; no generic Material file icon is substituted.
class FileThumbnail extends StatelessWidget {
  const FileThumbnail({super.key, required this.extension});
  final String extension;
  static String artworkFor(String extension) {
    final type=extension.toLowerCase().replaceFirst(RegExp(r'^\.'),'');
    if (type == 'pdf') return 'pdf';
    if (['jpg','jpeg','png','webp','heic','heif','bmp','gif','tif','tiff'].contains(type)) return 'image';
    return 'text';
  }
  @override
  Widget build(BuildContext context) => Image.asset(themedAsset(context, 'assets/files/${artworkFor(extension)}.png'), width:46.085, height:46.085,
    fit:BoxFit.contain, filterQuality:FilterQuality.high, excludeFromSemantics:true);
}

class FolderThumbnail extends StatelessWidget {
  const FolderThumbnail({super.key, required this.kind});
  final ScanKind kind;
  @override
  Widget build(BuildContext context) => SizedBox(width:46.085,height:46.085,
    child: Center(child: Image.asset(themedAsset(context, 'assets/files/folder_${kind.name}.png'),
      width:46.085,height:35.52,fit:BoxFit.contain,
      filterQuality:FilterQuality.high,excludeFromSemantics:true)));
}

class FileMoreIcon extends StatelessWidget {
  const FileMoreIcon({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(themedAsset(context, 'assets/files/more.png'),
    width:4.08,height:17.76,excludeFromSemantics:true);
}
