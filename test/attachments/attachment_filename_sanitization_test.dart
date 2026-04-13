import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/pages/transaction/attachments.dart';

AttachmentRead _attachment(String id, String? filename) {
  return AttachmentRead(
    type: 'attachments',
    id: id,
    attributes: AttachmentProperties(filename: filename),
    links: const ObjectLink(self: 'https://example.com'),
  );
}

void main() {
  group('attachment filename sanitization', () {
    test('strips path separators, control characters, and unsafe symbols', () {
      expect(
        sanitizeAttachmentFilename(
          r'..\receipts/evil?.pdf'
          '\x00',
        ),
        'evil_.pdf',
      );
    });

    test('falls back to a safe default for empty or reserved names', () {
      expect(sanitizeAttachmentFilename(null), 'attachment');
      expect(sanitizeAttachmentFilename('.'), 'attachment');
      expect(sanitizeAttachmentFilename('..'), 'attachment');
      expect(sanitizeAttachmentFilename('   '), 'attachment');
    });

    test('truncates long names while keeping a short extension', () {
      final String sanitized = sanitizeAttachmentFilename(
        '${'a' * 120}.receipt.pdf',
      );

      expect(sanitized.length, lessThanOrEqualTo(80));
      expect(sanitized, endsWith('.pdf'));
    });

    test(
      'builds stable temp download file names inside the target directory',
      () {
        final AttachmentRead attachment = _attachment(
          '42',
          r'..\Quarterly Reports\Q1 budget?.pdf',
        );
        final Directory tempDir = Directory.systemTemp;

        expect(
          attachmentDownloadFileName(attachment),
          'bankify-42-Q1 budget_.pdf',
        );
        expect(
          attachmentDownloadFile(tempDir, attachment).path,
          '${tempDir.path}${Platform.pathSeparator}bankify-42-Q1 budget_.pdf',
        );
      },
    );
  });
}
