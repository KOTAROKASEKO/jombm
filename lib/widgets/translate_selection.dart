import 'dart:async';

import 'package:flutter/material.dart';

import '../conversation/sentence_lookup.dart';

final _lookup = SentenceLookup();

Widget translateSelectionMenu(
  BuildContext context,
  EditableTextState editableTextState,
) {
  final items = editableTextState.contextMenuButtonItems;
  final value = editableTextState.textEditingValue;
  final selection = value.selection;
  if (selection.isValid && !selection.isCollapsed) {
    final selected = value.text
        .substring(selection.start, selection.end)
        .trim();
    if (selected.isNotEmpty) {
      items.insert(
        0,
        ContextMenuButtonItem(
          label: '翻訳',
          onPressed: () {
            ContextMenuController.removeAny();
            unawaited(
              _replaceSelectionWithMalay(
                context: context,
                controller: editableTextState.widget.controller,
                selected: selected,
                selection: selection,
              ),
            );
          },
        ),
      );
    }
  }

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: items,
  );
}

Future<void> _replaceSelectionWithMalay({
  required BuildContext context,
  required TextEditingController controller,
  required String selected,
  required TextSelection selection,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('翻訳しています…')));

  try {
    final result = await _lookup.toMalay(selected);
    if (!context.mounted) return;
    final malay = result.translation.trim();
    if (malay.isEmpty) {
      _showMessage(context, '翻訳できませんでした');
      return;
    }

    final text = controller.text;
    var start = selection.start;
    var end = selection.end;
    final rangeMatches =
        start >= 0 &&
        end <= text.length &&
        start <= end &&
        text.substring(start, end).trim() == selected;
    if (!rangeMatches) {
      final index = text.indexOf(selected);
      if (index < 0) {
        _showMessage(context, malay);
        return;
      }
      start = index;
      end = index + selected.length;
    }

    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, malay),
      selection: TextSelection.collapsed(offset: start + malay.length),
    );
    messenger?.hideCurrentSnackBar();
  } catch (_) {
    if (!context.mounted) return;
    _showMessage(context, '翻訳できませんでした');
  }
}

void _showMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
