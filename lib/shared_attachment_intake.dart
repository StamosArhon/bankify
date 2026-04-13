import 'dart:io';

import 'package:flutter_sharing_intent/model/sharing_file.dart';

const int maxInboundSharedAttachmentBytes = 25 * 1024 * 1024;
const int maxInboundSharedAttachmentCount = 10;

class SharedAttachmentCandidate {
  const SharedAttachmentCandidate({
    required this.path,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.isAppOwnedCopy,
  });

  final String path;
  final String filename;
  final String mimeType;
  final int size;
  final bool isAppOwnedCopy;
}

enum RejectedSharedAttachmentReason {
  emptyValue,
  unsupportedType,
  invalidOrigin,
  missingFile,
  duplicatePath,
  tooLarge,
  overLimit,
}

class RejectedSharedAttachment {
  const RejectedSharedAttachment({
    required this.displayName,
    required this.reason,
    this.mimeType,
    this.size,
  });

  final String displayName;
  final RejectedSharedAttachmentReason reason;
  final String? mimeType;
  final int? size;
}

class SharedAttachmentValidationResult {
  const SharedAttachmentValidationResult({
    required this.accepted,
    required this.rejected,
  });

  final List<SharedAttachmentCandidate> accepted;
  final List<RejectedSharedAttachment> rejected;

  bool get hasAccepted => accepted.isNotEmpty;
  bool get hasRejected => rejected.isNotEmpty;
  bool get hasAny => hasAccepted || hasRejected;
}

Future<SharedAttachmentValidationResult> validateSharedAttachments(
  List<SharedFile> files, {
  required Iterable<String> appOwnedRoots,
  int maxAttachmentCount = maxInboundSharedAttachmentCount,
  int maxAttachmentBytes = maxInboundSharedAttachmentBytes,
}) async {
  final List<String> ownedRoots = appOwnedRoots.map(_normalizePath).toList();
  final List<SharedAttachmentCandidate> accepted =
      <SharedAttachmentCandidate>[];
  final List<RejectedSharedAttachment> rejected = <RejectedSharedAttachment>[];
  final Set<String> acceptedPaths = <String>{};

  for (final SharedFile file in files) {
    final String rawValue = file.value?.trim() ?? '';
    if (rawValue.isEmpty) {
      rejected.add(
        const RejectedSharedAttachment(
          displayName: 'Shared item',
          reason: RejectedSharedAttachmentReason.emptyValue,
        ),
      );
      continue;
    }

    final String? normalizedPath = normalizeSharedAttachmentPath(rawValue);
    final String displayName = sharedAttachmentDisplayName(
      normalizedPath ?? rawValue,
    );
    final String? mimeType = inferSharedAttachmentMimeType(
      file,
      normalizedPath,
    );

    if (!isSupportedSharedAttachmentType(file, mimeType)) {
      rejected.add(
        RejectedSharedAttachment(
          displayName: displayName,
          reason: RejectedSharedAttachmentReason.unsupportedType,
          mimeType: mimeType,
        ),
      );
      if (normalizedPath != null) {
        await deleteSharedAttachmentIfOwnedCopy(normalizedPath, ownedRoots);
      }
      continue;
    }

    if (normalizedPath == null ||
        !isTrustedSharedAttachmentPath(normalizedPath, ownedRoots)) {
      rejected.add(
        RejectedSharedAttachment(
          displayName: displayName,
          reason: RejectedSharedAttachmentReason.invalidOrigin,
          mimeType: mimeType,
        ),
      );
      if (normalizedPath != null) {
        await deleteSharedAttachmentIfOwnedCopy(normalizedPath, ownedRoots);
      }
      continue;
    }

    final File sharedFile = File(normalizedPath);
    if (!await sharedFile.exists()) {
      rejected.add(
        RejectedSharedAttachment(
          displayName: displayName,
          reason: RejectedSharedAttachmentReason.missingFile,
          mimeType: mimeType,
        ),
      );
      await deleteSharedAttachmentIfOwnedCopy(normalizedPath, ownedRoots);
      continue;
    }

    final FileStat stat = await sharedFile.stat();
    if (stat.type != FileSystemEntityType.file) {
      rejected.add(
        RejectedSharedAttachment(
          displayName: displayName,
          reason: RejectedSharedAttachmentReason.invalidOrigin,
          mimeType: mimeType,
        ),
      );
      await deleteSharedAttachmentIfOwnedCopy(normalizedPath, ownedRoots);
      continue;
    }

    if (!acceptedPaths.add(normalizedPath)) {
      rejected.add(
        RejectedSharedAttachment(
          displayName: displayName,
          reason: RejectedSharedAttachmentReason.duplicatePath,
          mimeType: mimeType,
          size: stat.size,
        ),
      );
      continue;
    }

    if (stat.size > maxAttachmentBytes) {
      rejected.add(
        RejectedSharedAttachment(
          displayName: displayName,
          reason: RejectedSharedAttachmentReason.tooLarge,
          mimeType: mimeType,
          size: stat.size,
        ),
      );
      await deleteSharedAttachmentIfOwnedCopy(normalizedPath, ownedRoots);
      continue;
    }

    if (accepted.length >= maxAttachmentCount) {
      rejected.add(
        RejectedSharedAttachment(
          displayName: displayName,
          reason: RejectedSharedAttachmentReason.overLimit,
          mimeType: mimeType,
          size: stat.size,
        ),
      );
      await deleteSharedAttachmentIfOwnedCopy(normalizedPath, ownedRoots);
      continue;
    }

    accepted.add(
      SharedAttachmentCandidate(
        path: normalizedPath,
        filename: sharedAttachmentDisplayName(normalizedPath),
        mimeType: mimeType ?? 'application/octet-stream',
        size: stat.size,
        isAppOwnedCopy: isOwnedSharedAttachmentPath(normalizedPath, ownedRoots),
      ),
    );
  }

  return SharedAttachmentValidationResult(
    accepted: accepted,
    rejected: rejected,
  );
}

String? normalizeSharedAttachmentPath(String value) {
  if (_looksLikeAbsoluteFilePath(value)) {
    return value;
  }

  final Uri? uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  if (uri.scheme != 'file') {
    return null;
  }
  return uri.toFilePath(windows: Platform.isWindows);
}

String sharedAttachmentDisplayName(String value) {
  if (value.isEmpty) {
    return 'Shared item';
  }
  final String normalized = value.replaceAll('\\', '/');
  final List<String> segments = normalized.split('/');
  return segments.lastWhere(
    (String segment) => segment.isNotEmpty,
    orElse: () {
      return value;
    },
  );
}

String? inferSharedAttachmentMimeType(SharedFile file, String? normalizedPath) {
  final String? rawMimeType = file.mimeType?.trim().toLowerCase();
  if (rawMimeType?.isNotEmpty ?? false) {
    return rawMimeType;
  }
  if (normalizedPath == null) {
    return null;
  }

  final String lowerPath = normalizedPath.toLowerCase();
  if (lowerPath.endsWith('.pdf')) {
    return 'application/pdf';
  }
  if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lowerPath.endsWith('.png')) {
    return 'image/png';
  }
  if (lowerPath.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lowerPath.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lowerPath.endsWith('.bmp')) {
    return 'image/bmp';
  }
  if (lowerPath.endsWith('.heic')) {
    return 'image/heic';
  }
  if (lowerPath.endsWith('.heif')) {
    return 'image/heif';
  }
  if (lowerPath.endsWith('.tif') || lowerPath.endsWith('.tiff')) {
    return 'image/tiff';
  }
  return null;
}

bool isSupportedSharedAttachmentType(SharedFile file, String? mimeType) {
  switch (file.type) {
    case SharedMediaType.TEXT:
    case SharedMediaType.VIDEO:
      return false;
    case SharedMediaType.URL:
    case SharedMediaType.WEB_SEARCH:
    case SharedMediaType.IMAGE:
    case SharedMediaType.FILE:
    case SharedMediaType.OTHER:
      break;
  }

  if (mimeType == null || mimeType.isEmpty) {
    return false;
  }
  return mimeType == 'application/pdf' || mimeType.startsWith('image/');
}

bool isTrustedSharedAttachmentPath(
  String path,
  Iterable<String> appOwnedRoots,
) {
  if (!_looksLikeAbsoluteFilePath(path) || path.startsWith(r'\\')) {
    return false;
  }

  if (isOwnedSharedAttachmentPath(path, appOwnedRoots)) {
    return true;
  }

  if (Platform.isAndroid) {
    final String normalizedPath = _normalizePath(path);
    return normalizedPath.startsWith('/storage/') ||
        normalizedPath.startsWith('/sdcard/') ||
        normalizedPath.startsWith('/mnt/');
  }

  return true;
}

bool isOwnedSharedAttachmentPath(String path, Iterable<String> appOwnedRoots) {
  final String normalizedPath = _normalizePath(path);
  for (String root in appOwnedRoots) {
    root = _normalizePath(root);
    final String withTrailingSlash = root.endsWith('/') ? root : '$root/';
    if (normalizedPath == root ||
        normalizedPath.startsWith(withTrailingSlash)) {
      return true;
    }
  }
  return false;
}

Future<void> deleteSharedAttachmentIfOwnedCopy(
  String path,
  Iterable<String> appOwnedRoots,
) async {
  if (!isOwnedSharedAttachmentPath(path, appOwnedRoots)) {
    return;
  }

  final File file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

String _normalizePath(String path) {
  final String absolute = File(path).absolute.path.replaceAll('\\', '/');
  return Platform.isWindows ? absolute.toLowerCase() : absolute;
}

bool _looksLikeAbsoluteFilePath(String value) {
  return value.startsWith('/') ||
      RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value) ||
      value.startsWith('\\\\');
}
