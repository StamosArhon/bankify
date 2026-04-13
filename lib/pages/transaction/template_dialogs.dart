import 'package:flutter/material.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/pages/transaction/editor_state_store.dart';

Future<String?> showTransactionTemplateNameDialog(
  BuildContext context, {
  String? initialName,
}) async {
  final TextEditingController controller = TextEditingController(
    text: initialName ?? '',
  );
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        icon: const Icon(Icons.bookmark_add_outlined),
        title: Text(S.of(context).transactionTemplateSaveAction),
        clipBehavior: Clip.hardEdge,
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: S.of(context).transactionTemplateNameLabel,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              final String name = controller.text.trim();
              Navigator.of(context).pop(name.isEmpty ? null : name);
            },
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

Future<StoredTransactionEditorTemplate?> showTransactionTemplatePickerDialog(
  BuildContext context, {
  required List<StoredTransactionEditorTemplate> templates,
}) {
  return showDialog<StoredTransactionEditorTemplate>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        icon: const Icon(Icons.bookmarks_outlined),
        title: Text(S.of(context).transactionTemplateDialogTitle),
        clipBehavior: Clip.hardEdge,
        content: SizedBox(
          width: 420,
          child:
              templates.isEmpty
                  ? Text(S.of(context).transactionTemplateEmpty)
                  : ListView.separated(
                    shrinkWrap: true,
                    itemCount: templates.length,
                    itemBuilder: (BuildContext context, int index) {
                      final StoredTransactionEditorTemplate template =
                          templates[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(template.name),
                        subtitle: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatCompactDate(template.updatedAt),
                        ),
                        onTap: () => Navigator.of(context).pop(template),
                      );
                    },
                    separatorBuilder:
                        (BuildContext context, int index) => const Divider(),
                  ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      );
    },
  );
}
