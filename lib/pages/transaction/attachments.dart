import 'dart:convert';
import 'dart:io';

import 'package:chopper/chopper.dart' show HttpMethod, Response;
import 'package:file_picker/file_picker.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:provider/provider.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/widgets/materialiconbutton.dart';

class AttachmentDialog extends StatefulWidget {
  const AttachmentDialog({
    super.key,
    required this.attachments,
    required this.transactionId,
  });

  final List<AttachmentRead> attachments;
  final String? transactionId;

  @override
  State<AttachmentDialog> createState() => _AttachmentDialogState();
}

class _AttachmentDialogState extends State<AttachmentDialog>
    with SingleTickerProviderStateMixin {
  final Logger log = Logger("Pages.Transaction.AttachmentDialog");

  final Map<int, double> _dlProgress = <int, double>{};

  String _safeAttachmentFilename(String? filename) {
    String safeName = (filename ?? "").trim().replaceAll("\\", "/");
    if (safeName.contains("/")) {
      safeName = safeName.split("/").last;
    }
    safeName = safeName.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), "");
    safeName = safeName.replaceAll(RegExp(r"[^A-Za-z0-9._ -]"), "_");
    safeName = safeName.replaceAll(RegExp(r"\s+"), " ").trim();
    if (safeName.isEmpty || safeName == "." || safeName == "..") {
      safeName = "attachment";
    }
    if (safeName.length > 80) {
      final int dotIndex = safeName.lastIndexOf(".");
      if (dotIndex > 0 && safeName.length - dotIndex <= 10) {
        final String extension = safeName.substring(dotIndex);
        final int baseLength = 80 - extension.length;
        safeName = "${safeName.substring(0, baseLength)}$extension";
      } else {
        safeName = safeName.substring(0, 80);
      }
    }
    return safeName;
  }

  File _attachmentDownloadFile(Directory tmpPath, AttachmentRead attachment) {
    final String safeName = _safeAttachmentFilename(
      attachment.attributes.filename,
    );
    final String fileName = "bankify-${attachment.id}-$safeName";
    return File.fromUri(tmpPath.uri.resolve(fileName));
  }

  Future<void> downloadAttachment(
    BuildContext context,
    AttachmentRead attachment,
    int i,
  ) async {
    final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
    final AuthUser? user = context.read<FireflyService>().user;
    final S l10n = S.of(context);
    late int total;
    int received = 0;

    if (user == null) {
      log.severe("downloadAttachment: user was null");
      throw Exception(l10n.errorAPIUnavailable);
    }

    final Uri downloadUri = fireflyAttachmentDownloadUri(user, attachment.id);

    final http.Request request = http.Request(HttpMethod.Get, downloadUri);
    request.headers.addAll(user.headers());
    disallowRedirects(request);
    final http.StreamedResponse resp = await user.httpClient.send(request);
    if (resp.statusCode != 200) {
      log.warning("got invalid status code ${resp.statusCode}");
      msg.showSnackBar(
        SnackBar(
          content: Text(l10n.transactionDialogAttachmentsErrorDownload),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    total = resp.contentLength ?? 0;
    if (total == 0) {
      total = attachment.attributes.size ?? 0;
    }
    final Directory tmpPath = await getTemporaryDirectory();
    final File outputFile = _attachmentDownloadFile(tmpPath, attachment);
    final IOSink fileSink = outputFile.openWrite();

    try {
      await for (final List<int> value in resp.stream) {
        fileSink.add(value);
        received += value.length;
        final double progress = total > 0 ? received / total : 0;
        setState(() {
          _dlProgress[i] = progress;
          log.finest(
            () =>
                "received ${value.length} bytes (total $received of $total), ${progress * 100}%",
          );
        });
      }
      await fileSink.flush();
      await fileSink.close();
      setState(() {
        _dlProgress.remove(i);
      });
      final OpenResult file = await OpenFile.open(outputFile.path);
      if (file.type != ResultType.done) {
        log.severe("error opening file", file.message);
        msg.showSnackBar(
          SnackBar(
            content: Text(
              l10n.transactionDialogAttachmentsErrorOpen(file.message),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, s) {
      log.severe("download error", e, s);
      await fileSink.close();
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      setState(() {
        _dlProgress.remove(i);
      });
      msg.showSnackBar(
        SnackBar(
          content: Text(l10n.transactionDialogAttachmentsErrorDownload),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> deleteAttachment(
    BuildContext context,
    AttachmentRead attachment,
    int i,
  ) async {
    final FireflyIii api = context.read<FireflyService>().api;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => const AttachmentDeletionConfirmDialog(),
    );
    if (ok == null || !ok) {
      return;
    }

    await api.v1AttachmentsIdDelete(id: attachment.id);
    setState(() {
      widget.attachments.removeAt(i);
    });
  }

  Future<void> uploadAttachment(BuildContext context, PlatformFile file) async {
    final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
    final FireflyIii api = context.read<FireflyService>().api;
    final AuthUser? user = context.read<FireflyService>().user;
    final S l10n = S.of(context);

    if (user == null) {
      log.severe("uploadAttachment: user was null");
      throw Exception(l10n.errorAPIUnavailable);
    }

    final Response<AttachmentSingle> respAttachment = await api
        .v1AttachmentsPost(
          body: AttachmentStore(
            filename: file.name,
            attachableType: AttachableType.transactionjournal,
            attachableId: widget.transactionId!,
          ),
        );
    if (!respAttachment.isSuccessful || respAttachment.body == null) {
      late String error;
      try {
        final ValidationErrorResponse valError =
            ValidationErrorResponse.fromJson(
              json.decode(respAttachment.error.toString()),
            );
        error = valError.message ?? l10n.errorUnknown;
      } catch (_) {
        error = l10n.errorUnknown;
      }
      msg.showSnackBar(
        SnackBar(
          content: Text(l10n.transactionDialogAttachmentsErrorUpload(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    AttachmentRead newAttachment = respAttachment.body!.data;
    final int newAttachmentIndex =
        widget.attachments.length; // Will be added later, no -1 needed.
    final int total = file.size;
    newAttachment = newAttachment.copyWith(
      attributes: newAttachment.attributes.copyWith(size: total),
    );
    int sent = 0;

    setState(() {
      widget.attachments.add(newAttachment);
      _dlProgress[newAttachmentIndex] = -0.0001;
    });

    final http.StreamedRequest request = http.StreamedRequest(
      HttpMethod.Post,
      fireflyAttachmentUploadUri(user, newAttachment.id),
    );
    request.headers.addAll(user.headers());
    disallowRedirects(request);
    request.headers[HttpHeaders.contentTypeHeader] =
        ContentType.binary.mimeType;
    log.fine(() => "AttachmentUpload: Starting Upload $newAttachmentIndex");
    request.contentLength = total;

    File(file.path!).openRead().listen(
      (List<int> data) {
        setState(() {
          sent += data.length;
          _dlProgress[newAttachmentIndex] = sent / total * -1;
          log.finest(
            () =>
                "sent ${data.length} bytes (total $sent of $total), ${sent / total * 100}%",
          );
        });
        request.sink.add(data);
      },
      onDone: () {
        request.sink.close();
      },
    );

    final http.StreamedResponse resp = await user.httpClient.send(request);
    log.fine(() => "AttachmentUpload: Done with Upload $newAttachmentIndex");
    setState(() {
      _dlProgress.remove(newAttachmentIndex);
    });
    if (resp.statusCode == HttpStatus.ok ||
        resp.statusCode == HttpStatus.created ||
        resp.statusCode == HttpStatus.noContent) {
      return;
    }
    late String error;
    try {
      final String respString = await resp.stream.bytesToString();
      final ValidationErrorResponse valError = ValidationErrorResponse.fromJson(
        json.decode(respString),
      );
      error = valError.message ?? l10n.errorUnknown;
    } catch (_) {
      error = l10n.errorUnknown;
    }
    msg.showSnackBar(
      SnackBar(
        content: Text(l10n.transactionDialogAttachmentsErrorUpload(error)),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await api.v1AttachmentsIdDelete(id: newAttachment.id);
    setState(() {
      widget.attachments.removeAt(newAttachmentIndex);
    });
  }

  Future<void> fakeDownloadAttachment(
    BuildContext context,
    AttachmentRead attachment,
  ) async {
    final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
    final S l10n = S.of(context);

    final OpenResult file = await OpenFile.open(
      attachment.attributes.uploadUrl,
    );
    if (file.type != ResultType.done) {
      log.severe("error opening file", file.message);
      msg.showSnackBar(
        SnackBar(
          content: Text(
            l10n.transactionDialogAttachmentsErrorOpen(file.message),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> fakeDeleteAttachment(BuildContext context, int i) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => const AttachmentDeletionConfirmDialog(),
    );
    if (ok == null || !ok) {
      return;
    }
    setState(() {
      widget.attachments.removeAt(i);
    });
  }

  Future<void> fakeUploadAttachment(
    BuildContext context,
    PlatformFile file,
  ) async {
    final AttachmentRead newAttachment = AttachmentRead(
      type: "attachments",
      id: widget.attachments.length.toString(),
      attributes: AttachmentProperties(
        attachableType: AttachableType.transactionjournal,
        attachableId: "FAKE",
        filename: file.name,
        uploadUrl: file.path,
        size: file.size,
      ),
      links: const ObjectLink(),
    );
    setState(() {
      widget.attachments.add(newAttachment);
    });
  }

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build(transactionId: ${widget.transactionId})");
    final List<Widget> childs = <Widget>[];
    for (int i = 0; i < widget.attachments.length; i++) {
      final AttachmentRead attachment = widget.attachments[i];
      String subtitle = "";
      final DateTime? modDate =
          attachment.attributes.updatedAt ?? attachment.attributes.createdAt;
      if (modDate != null) {
        subtitle = DateFormat.yMd().add_Hms().format(modDate.toLocal());
      }

      if (attachment.attributes.size != null) {
        subtitle = "$subtitle (${filesize(attachment.attributes.size)})";
      }
      childs.add(
        ListTile(
          enabled:
              (_dlProgress[i] != null && _dlProgress[i]! < 0) ? false : true,
          leading: MaterialIconButton(
            icon:
                (_dlProgress[i] != null && _dlProgress[i]! < 0)
                    ? Icons.upload
                    : Icons.download,
            onPressed:
                _dlProgress[i] != null
                    ? null
                    : widget.transactionId == null
                    ? () => fakeDownloadAttachment(context, attachment)
                    : () => downloadAttachment(context, attachment, i),
          ),
          title: Text(
            attachment.attributes.title ?? attachment.attributes.filename!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: false,
          trailing: MaterialIconButton(
            icon: Icons.delete,
            onPressed:
                (_dlProgress[i] != null && _dlProgress[i]! < 0)
                    ? null
                    : widget.transactionId == null
                    ? () => fakeDeleteAttachment(context, i)
                    : () => deleteAttachment(context, attachment, i),
          ),
        ),
      );
      final DividerThemeData divTheme = DividerTheme.of(context);
      childs.add(
        SizedBox(
          height: divTheme.space ?? 16,
          child: Center(
            child:
                _dlProgress[i] == null
                    ? const Divider(height: 0)
                    : LinearProgressIndicator(
                      value: _dlProgress[i]!.abs(),
                      //minHeight: divTheme.thickness ?? 4,
                      //backgroundColor: divTheme.color ?? theme.colorScheme.outlineVariant,
                    ),
          ),
        ),
      );
    }
    childs.add(
      OverflowBar(
        alignment: MainAxisAlignment.end,
        spacing: 12,
        overflowSpacing: 12,
        children: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
          FilledButton(
            onPressed: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? imageFile = await picker.pickImage(
                source: ImageSource.camera,
              );

              if (imageFile == null) {
                log.finest(() => "no image returned");
                return;
              }

              log.finer(() => "Image selected for upload");
              final PlatformFile file = PlatformFile(
                path: imageFile.path,
                name: imageFile.name,
                size: await imageFile.length(),
              );
              if (context.mounted) {
                if (widget.transactionId == null) {
                  await fakeUploadAttachment(context, file);
                } else {
                  await uploadAttachment(context, file);
                }
              }
            },
            child: const Icon(Icons.camera_alt),
          ),
          FilledButton(
            onPressed: () async {
              final FilePickerResult? file =
                  await FilePicker.platform.pickFiles();
              if (file == null || file.files.first.path == null) {
                return;
              }
              if (context.mounted) {
                if (widget.transactionId == null) {
                  await fakeUploadAttachment(context, file.files.first);
                } else {
                  await uploadAttachment(context, file.files.first);
                }
              }
            },
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
    return SimpleDialog(
      title: Text(S.of(context).transactionDialogAttachmentsTitle),
      clipBehavior: Clip.hardEdge,
      children: childs,
    );
  }
}

class AttachmentDeletionConfirmDialog extends StatelessWidget {
  const AttachmentDeletionConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.delete),
      title: Text(S.of(context).transactionDialogAttachmentsDelete),
      clipBehavior: Clip.hardEdge,
      actions: <Widget>[
        TextButton(
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
          child: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
      ],
      content: Text(S.of(context).transactionDialogAttachmentsDeleteConfirm),
    );
  }
}
