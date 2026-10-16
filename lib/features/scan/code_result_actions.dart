import 'package:mobile_scanner/mobile_scanner.dart';

/// Only a user-tapped Open action may launch a scanned web link. Other QR
/// payloads (including Wi-Fi, contacts and plain text) stay readable/copyable.
Uri? codeResultUri({required bool qrOnly, required String value}) {
  final text = value.trim();
  if (text.isEmpty) return null;
  if (!qrOnly) return Uri.https('www.google.com', '/search', {'q': text});
  final uri = Uri.tryParse(text);
  if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
    return null;
  }
  return uri;
}

String barcodeFormatLabel(BarcodeFormat? format) => switch (format) {
  BarcodeFormat.code128 => 'CODE 128',
  BarcodeFormat.code39 => 'CODE 39',
  BarcodeFormat.code93 => 'CODE 93',
  BarcodeFormat.codabar => 'CODABAR',
  BarcodeFormat.ean13 => 'EAN-13',
  BarcodeFormat.ean8 => 'EAN-8',
  BarcodeFormat.itf14 => 'ITF-14',
  BarcodeFormat.upcA => 'UPC-A',
  BarcodeFormat.upcE => 'UPC-E',
  BarcodeFormat.pdf417 => 'PDF417',
  BarcodeFormat.dataMatrix => 'DATA MATRIX',
  BarcodeFormat.aztec => 'AZTEC',
  BarcodeFormat.qrCode => 'QR CODE',
  _ => 'Barcode',
};

// Set the exact promoted app's store URL at build time. Never guess a package ID.
const qrGeneratorAppUrl = String.fromEnvironment('QR_GENERATOR_APP_URL',
  defaultValue: String.fromEnvironment('MORE_APPS_URL'));

Uri? generatorAppUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}
