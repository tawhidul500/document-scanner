import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/document_store.dart';
import '../document/document_camera.dart';
import 'code_scanner.dart';

/// A route with one active camera owner. Each child releases its controller
/// before requesting a mode change, and results retain the selected file kind.
class ScannerSession extends StatefulWidget {
  const ScannerSession({super.key, required this.directory,
    required this.initialKind, required this.onKindChanged});
  final Directory directory;
  final ScanKind initialKind;
  final ValueChanged<ScanKind> onKindChanged;
  @override
  State<ScannerSession> createState() => _ScannerSessionState();
}
class _ScannerSessionState extends State<ScannerSession> {
  late ScanKind kind = widget.initialKind;
  void change(ScanKind next) {
    widget.onKindChanged(next);
    setState(() => kind=next);
  }
  @override
  Widget build(BuildContext context) => kind == ScanKind.document || kind == ScanKind.idCard
    ? DocumentCamera(key: ValueKey(kind), directory: widget.directory,
        idCard: kind == ScanKind.idCard, onModeChanged: change)
    : CodeScanner(key: ValueKey(kind), qrOnly: kind == ScanKind.qr, onModeChanged: change);
}
