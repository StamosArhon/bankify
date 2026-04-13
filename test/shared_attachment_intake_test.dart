import 'dart:io';

import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/shared_attachment_intake.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'bankify_shared_attachment_intake_test',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('accepts local image and pdf files from trusted roots', () async {
    final File imageFile = File(
      '${tempDir.path}${Platform.pathSeparator}receipt.jpg',
    );
    final File pdfFile = File(
      '${tempDir.path}${Platform.pathSeparator}statement.pdf',
    );
    await imageFile.writeAsBytes(<int>[1, 2, 3, 4]);
    await pdfFile.writeAsBytes(<int>[5, 6, 7, 8]);

    final SharedAttachmentValidationResult result =
        await validateSharedAttachments(
          <SharedFile>[
            SharedFile(
              value: imageFile.path,
              type: SharedMediaType.IMAGE,
              mimeType: 'image/jpeg',
            ),
            SharedFile(
              value: pdfFile.path,
              type: SharedMediaType.FILE,
              mimeType: 'application/pdf',
            ),
          ],
          appOwnedRoots: <String>[tempDir.path],
        );

    expect(result.accepted, hasLength(2));
    expect(result.rejected, isEmpty);
    expect(result.accepted.first.isAppOwnedCopy, isTrue);
    expect(result.accepted.last.filename, 'statement.pdf');
  });

  test('rejects text payloads and remote URLs', () async {
    final SharedAttachmentValidationResult result =
        await validateSharedAttachments(
          <SharedFile>[
            SharedFile(
              value: 'Dinner with friends',
              type: SharedMediaType.TEXT,
              mimeType: 'text/plain',
            ),
            SharedFile(
              value: 'https://example.com/receipt.pdf',
              type: SharedMediaType.URL,
              mimeType: 'application/pdf',
            ),
          ],
          appOwnedRoots: <String>[tempDir.path],
        );

    expect(result.accepted, isEmpty);
    expect(result.rejected, hasLength(2));
    expect(
      result.rejected.map((RejectedSharedAttachment item) => item.reason),
      containsAll(<RejectedSharedAttachmentReason>[
        RejectedSharedAttachmentReason.unsupportedType,
        RejectedSharedAttachmentReason.invalidOrigin,
      ]),
    );
  });

  test('rejects oversized app-owned copies and deletes them', () async {
    final File hugeFile = File(
      '${tempDir.path}${Platform.pathSeparator}huge.pdf',
    );
    await hugeFile.writeAsBytes(List<int>.filled(8, 7));

    final SharedAttachmentValidationResult result =
        await validateSharedAttachments(
          <SharedFile>[
            SharedFile(
              value: hugeFile.path,
              type: SharedMediaType.FILE,
              mimeType: 'application/pdf',
            ),
          ],
          appOwnedRoots: <String>[tempDir.path],
          maxAttachmentBytes: 4,
        );

    expect(result.accepted, isEmpty);
    expect(
      result.rejected.single.reason,
      RejectedSharedAttachmentReason.tooLarge,
    );
    expect(await hugeFile.exists(), isFalse);
  });

  test('accepts only the first configured number of files', () async {
    final File firstFile = File(
      '${tempDir.path}${Platform.pathSeparator}1.jpg',
    );
    final File secondFile = File(
      '${tempDir.path}${Platform.pathSeparator}2.jpg',
    );
    await firstFile.writeAsBytes(<int>[1]);
    await secondFile.writeAsBytes(<int>[2]);

    final SharedAttachmentValidationResult result =
        await validateSharedAttachments(
          <SharedFile>[
            SharedFile(
              value: firstFile.path,
              type: SharedMediaType.IMAGE,
              mimeType: 'image/jpeg',
            ),
            SharedFile(
              value: secondFile.path,
              type: SharedMediaType.IMAGE,
              mimeType: 'image/jpeg',
            ),
          ],
          appOwnedRoots: <String>[tempDir.path],
          maxAttachmentCount: 1,
        );

    expect(result.accepted, hasLength(1));
    expect(result.accepted.single.filename, '1.jpg');
    expect(
      result.rejected.single.reason,
      RejectedSharedAttachmentReason.overLimit,
    );
    expect(await secondFile.exists(), isFalse);
  });

  test('normalizes file uris and rejects relative paths', () async {
    final File localFile = File(
      '${tempDir.path}${Platform.pathSeparator}statement.pdf',
    );
    await localFile.writeAsBytes(<int>[1, 2, 3]);

    expect(
      normalizeSharedAttachmentPath(localFile.uri.toString()),
      localFile.path,
    );
    expect(normalizeSharedAttachmentPath('statement.pdf'), isNull);
  });

  test('deletes only app-owned copies during cleanup', () async {
    final Directory externalDir = await Directory.systemTemp.createTemp(
      'bankify_shared_attachment_external',
    );
    final File ownedFile = File(
      '${tempDir.path}${Platform.pathSeparator}owned.pdf',
    );
    final File externalFile = File(
      '${externalDir.path}${Platform.pathSeparator}external.pdf',
    );
    await ownedFile.writeAsBytes(<int>[1, 2, 3]);
    await externalFile.writeAsBytes(<int>[4, 5, 6]);

    try {
      await deleteSharedAttachmentIfOwnedCopy(ownedFile.path, <String>[
        tempDir.path,
      ]);
      await deleteSharedAttachmentIfOwnedCopy(externalFile.path, <String>[
        tempDir.path,
      ]);

      expect(await ownedFile.exists(), isFalse);
      expect(await externalFile.exists(), isTrue);
    } finally {
      if (await externalDir.exists()) {
        await externalDir.delete(recursive: true);
      }
    }
  });
}
