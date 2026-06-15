import 'package:html/parser.dart' as html_parser;

class HtmlParser {
  /// Extracts CSRF token from HTML form pages (still needed for form-based endpoints).
  static String? extractCsrfToken(String html) {
    final doc = html_parser.parse(html);

    final meta = doc.querySelector('meta[name="csrf-token"]');
    if (meta != null) {
      final content = meta.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }

    final input = doc.querySelector('input[name="_token"]');
    if (input != null) {
      final value = input.attributes['value'];
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }
}