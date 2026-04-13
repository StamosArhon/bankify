import 'package:path_provider/path_provider.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/shared_attachment_intake.dart';

Future<List<String>> resolveManagedSharedAttachmentRoots() async {
  final List<String> roots = <String>[
    (await getTemporaryDirectory()).path,
    (await getApplicationSupportDirectory()).path,
  ];

  try {
    roots.add((await getApplicationDocumentsDirectory()).path);
  } on MissingPlatformDirectoryException {
    // Best-effort optional directory.
  }

  return roots;
}

AttachmentRead sharedAttachmentToDraft(
  SharedAttachmentCandidate candidate,
  int index,
) {
  return AttachmentRead(
    type: "attachments",
    id: index.toString(),
    attributes: AttachmentProperties(
      attachableType: AttachableType.transactionjournal,
      attachableId: "FAKE",
      filename: candidate.filename,
      uploadUrl: candidate.path,
      size: candidate.size,
    ),
    links: const ObjectLink(),
  );
}

Future<void> cleanupManagedSharedAttachments(
  Iterable<String> paths,
  Iterable<String> managedRoots,
) async {
  for (final String path in paths) {
    await deleteSharedAttachmentIfOwnedCopy(path, managedRoots);
  }
}
