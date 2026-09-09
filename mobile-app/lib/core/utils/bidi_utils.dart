import 'package:flutter/material.dart';

/// Detects whether the text should be rendered with RTL or LTR text direction.
///
/// Persian and Arabic characters fall into Unicode ranges:
/// - 0x0600 - 0x06FF (Arabic)
/// - 0x0750 - 0x077F (Arabic Supplement)
/// - 0x08A0 - 0x08FF (Arabic Extended-A)
/// - 0xFB50 - 0xFDFF (Arabic Presentation Forms-A)
/// - 0xFE70 - 0xFEFF (Arabic Presentation Forms-B)
///
/// If any Persian/Arabic strong directional characters are present, returns
/// [TextDirection.rtl]. Otherwise, defaults to [TextDirection.ltr] so that
/// Latin/English sentences with trailing punctuation (e.g. "We are from Canada.")
/// correctly position periods, exclamation marks, and question marks at the end (right side).
TextDirection detectTextDirection(String? text) {
  if (text == null || text.trim().isEmpty) {
    return TextDirection.ltr;
  }

  final isRtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]')
      .hasMatch(text);

  return isRtl ? TextDirection.rtl : TextDirection.ltr;
}
