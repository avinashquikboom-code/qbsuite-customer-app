import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Utility for downloading a remote generated media asset and sharing it
/// via the native OS share sheet.
///
/// Supports IMAGE and VIDEO assets. Always downloads to a temp file first
/// because the native share APIs require a local file path, not a remote URL.
/// Temp files are deleted after the share sheet is dismissed.
class MediaShareUtil {
  MediaShareUtil._();

  /// Guess file extension from [url] or fall back based on [mediaType] hint.
  static String _guessExtension(String url, String? mediaType) {
    final path = Uri.tryParse(url)?.path ?? '';
    if (path.contains('.')) {
      final ext = path.split('.').last.split('?').first.toLowerCase();
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }
    if (mediaType != null) {
      final mt = mediaType.toLowerCase();
      if (mt.contains('mp4')) return 'mp4';
      if (mt.contains('mov')) return 'mov';
      if (mt.contains('webm')) return 'webm';
      if (mt.contains('svg')) return 'svg';
      if (mt.contains('png')) return 'png';
      if (mt.contains('gif')) return 'gif';
      if (mt.contains('webp')) return 'webp';
      if (mt.contains('jpeg') || mt.contains('jpg')) return 'jpg';
    }
    return 'jpg';
  }

  static String _mimeType(String ext) {
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'svg':
        return 'image/svg+xml';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Download [mediaUrl] to a temp file and invoke the native OS share sheet.
  ///
  /// [caption] is included as share text where supported.
  /// [onProgress] is called with a value 0.0–1.0 during download.
  ///
  /// Returns true if the share sheet opened successfully.
  static Future<bool> shareMedia({
    required BuildContext context,
    required String mediaUrl,
    String? caption,
    String? mediaType,
    void Function(double progress)? onProgress,
  }) async {
    File? tempFile;
    try {
      final ext = _guessExtension(mediaUrl, mediaType);
      final tempDir = await getTemporaryDirectory();
      final fileName = 'qb_share_${DateTime.now().millisecondsSinceEpoch}.$ext';
      tempFile = File('${tempDir.path}/$fileName');

      final dio = Dio();
      await dio.download(
        mediaUrl,
        tempFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          headers: {'Accept': '*/*'},
        ),
      );

      if (!await tempFile.exists()) {
        throw Exception('Downloaded file not found');
      }

      final xFile = XFile(tempFile.path, mimeType: _mimeType(ext));
      final shareText = (caption ?? '').trim();

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: shareText.isNotEmpty ? shareText : null,
        ),
      );

      debugPrint('[MEDIA_SHARE] status=${result.status}');
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('[MEDIA_SHARE_ERROR] $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not share: ${_friendlyError(e)}',
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  static String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'Check your internet connection and try again.';
    }
    if (msg.contains('404') || msg.contains('Not Found')) {
      return 'Media file not found on server.';
    }
    if (msg.contains('timeout') || msg.contains('Timeout')) {
      return 'Download timed out. Please try again.';
    }
    return 'An unexpected error occurred.';
  }
}
