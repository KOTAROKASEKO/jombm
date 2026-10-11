import 'package:flutter/material.dart';

import '../characters/chat_character.dart';

Future<ChatCharacter?> showCharacterPicker({
  required BuildContext context,
  required ChatCharacter selected,
}) {
  return showModalBottomSheet<ChatCharacter>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('誰と話す？', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('性格が違うので、話し方も変わります。'),
            const SizedBox(height: 16),
            for (final character in CharacterCatalog.all)
              ListTile(
                selected: character.id == selected.id,
                leading: CircleAvatar(
                  backgroundColor: Color(character.colorValue),
                  child: Text(
                    character.initial,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text('${character.nameJa}（${character.name}）'),
                subtitle: Text('${character.roleJa} / ${character.bioJa}'),
                onTap: () => Navigator.of(context).pop(character),
              ),
          ],
        ),
      );
    },
  );
}
