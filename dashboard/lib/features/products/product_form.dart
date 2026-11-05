import 'dart:typed_data';

/// Client-side checks that mirror the server rules, so mistakes are caught
/// before uploading. The server still validates everything.
class ProductRules {
  static const maxImageBytes = 2 * 1024 * 1024; // server limit: 2048 KB
  static const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  static String? name(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Enter a name';
    if (t.length > 255) return 'At most 255 characters';
    return null;
  }

  static String? description(String? v) => (v ?? '').length > 5000 ? 'At most 5000 characters' : null;

  /// 0.01 to 99,999,999.99 with at most 2 decimals. Kept as text: never a double.
  static String? price(String? v) {
    final t = (v ?? '').trim();
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(t)) return 'Use a number like 25.50';
    if (double.parse(t) < 0.01) return 'Must be at least 0.01';
    return null;
  }

  static String? quantity(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a whole number';
    if (n < 0 || n > 1000000) return 'Between 0 and 1,000,000';
    return null;
  }

  static String? image(String? filename, int? size) {
    if (filename == null || size == null) return 'Choose an image';
    final ext = filename.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) return 'Only JPG, PNG or WebP images';
    if (size > maxImageBytes) return 'The image must be 2 MB or smaller';
    if (size == 0) return 'The file is empty';
    return null;
  }
}

class PickedImage {
  const PickedImage(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}
