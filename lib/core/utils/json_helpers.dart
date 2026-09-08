import 'dart:convert';
import 'dart:typed_data';

int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double? asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.'));
}

bool? asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final raw = '$value'.toLowerCase();
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  return null;
}

String? asString(dynamic value) {
  if (value == null) return null;
  final text = '$value';
  return text.isEmpty ? null : text;
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

dynamic pick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key];
  }
  return null;
}

String? extractMessage(dynamic data) {
  if (data == null) return null;
  if (data is List<int>) {
    try {
      final text = utf8.decode(data is Uint8List ? data : Uint8List.fromList(data));
      final trimmed = text.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return extractMessage(jsonDecode(trimmed));
      }
      if (trimmed.isNotEmpty && trimmed.length < 500) return trimmed;
    } catch (_) {}
    return null;
  }
  if (data is String && data.trim().isNotEmpty) return data;
  if (data is Map) {
    final map = asMap(data);
    return asString(pick(map, ['message', 'error', 'detail', 'title']));
  }
  return null;
}

String? parseContentDispositionFilename(String? header) {
  if (header == null || header.isEmpty) return null;
  final utf8Name = RegExp(
    r"filename\*\s*=\s*(?:UTF-8'')?([^;]+)",
    caseSensitive: false,
  ).firstMatch(header);
  if (utf8Name != null) {
    final raw = utf8Name.group(1)!.trim().replaceAll('"', '');
    try {
      return Uri.decodeFull(raw);
    } catch (_) {
      return raw;
    }
  }
  final asciiName = RegExp(
    r'filename\s*=\s*"([^"]+)"|filename\s*=\s*([^;]+)',
    caseSensitive: false,
  ).firstMatch(header);
  if (asciiName != null) {
    final name = (asciiName.group(1) ?? asciiName.group(2))?.trim();
    if (name != null && name.isNotEmpty) return name;
  }
  return null;
}

String sanitizeFilename(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  return cleaned.isEmpty ? 'download' : cleaned;
}

String prettyJson(Object? value) => const JsonEncoder.withIndent('  ').convert(value);
