import 'dart:io';

import 'package:chopper/chopper.dart' show Response;
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

class TransactionAttachmentUploadService {
  TransactionAttachmentUploadService({
    required this.api,
    required this.user,
    Logger? logger,
  }) : log = logger ?? Logger("Pages.Transaction.AttachmentUpload");

  final FireflyIii api;
  final AuthUser user;
  final Logger log;

  Future<void> uploadDraftAttachments({
    required List<AttachmentRead> attachments,
    required TransactionSingle transaction,
    required List<String?> transactionJournalIds,
  }) async {
    if (attachments.isEmpty ||
        transactionJournalIds.any((String? id) => id != null)) {
      return;
    }

    log.fine(() => "uploading ${attachments.length} attachments");
    final TransactionSplit? split =
        transaction.data.attributes.transactions
            .where((TransactionSplit item) => item.transactionJournalId != null)
            .firstOrNull;
    if (split?.transactionJournalId == null) {
      return;
    }

    final String transactionJournalId = split!.transactionJournalId!;
    log.finest(() => "uploading to txId $transactionJournalId");

    for (final AttachmentRead attachment in attachments) {
      log.finest(
        () =>
            "uploading attachment ${attachment.id}: ${attachment.attributes.filename}",
      );
      final Response<AttachmentSingle> respAttachment = await api
          .v1AttachmentsPost(
            body: AttachmentStore(
              filename: attachment.attributes.filename!,
              attachableType: AttachableType.transactionjournal,
              attachableId: transactionJournalId,
            ),
          );
      if (!respAttachment.isSuccessful || respAttachment.body == null) {
        log.warning(() => "error uploading attachment");
        continue;
      }

      final AttachmentRead newAttachment = respAttachment.body!.data;
      final File file = File(attachment.attributes.uploadUrl!);
      final http.StreamedRequest request = http.StreamedRequest(
        'POST',
        fireflyAttachmentUploadUri(user, newAttachment.id),
      );
      request.headers.addAll(user.headers());
      disallowRedirects(request);
      request.headers[HttpHeaders.contentTypeHeader] =
          ContentType.binary.mimeType;
      request.contentLength = await file.length();

      await request.sink.addStream(file.openRead());
      await request.sink.close();
      await user.httpClient.send(request);
      log.fine(() => "done uploading attachment");
    }
  }
}
