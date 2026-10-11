import 'package:flutter/material.dart';

import '../conversation/malay_text.dart';

class TappableMalayText extends StatelessWidget {
  const TappableMalayText({
    super.key,
    required this.text,
    required this.style,
    required this.onWordTap,
  });

  final String text;
  final TextStyle style;
  final void Function(String word) onWordTap;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          for (final part in splitMalayText(text))
            if (part.isWord)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () => onWordTap(part.text),
                  child: Text(
                    part.text,
                    style: style.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: style.color?.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              )
            else
              TextSpan(text: part.text, style: style),
        ],
      ),
    );
  }
}
