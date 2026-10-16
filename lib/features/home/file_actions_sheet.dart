import 'package:flutter/material.dart';
import '../../data/document_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_action_sheet.dart';

Future<String?> showFileActions(BuildContext context, ScanFile document) =>
    showAppActionSheet<String>(
      context: context,
      title: Text(document.filename, maxLines: 2,
          overflow: TextOverflow.ellipsis),
      closeLabel: 'Close file options',
      actions: (sheetContext) => [
        for (final item in [
          (Icons.edit_document, 'Open document actions'),
          (Icons.visibility_outlined, 'Preview'),
          (Icons.print_outlined, 'Print'),
          (Icons.share_outlined, 'Share'),
          (Icons.file_download_outlined, 'Export'),
        ])
          AppMenuAction(
            icon: item.$1,
            label: item.$2,
            subtitle: item.$2 == 'Open document actions'
                ? AppText(
                    document.extension == 'txt'
                        ? 'Create a PDF copy to Edit, Sign, OCR, Share, and Export. Your text file is kept.'
                        : 'Edit · Sign · OCR · Share · Export',
                    style: TextStyle(
                        color: AppPalette.of(sheetContext).secondary),
                  )
                : null,
            onTap: () => Navigator.pop(sheetContext, item.$2),
          ),
      ],
    );
