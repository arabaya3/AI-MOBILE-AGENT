import 'package:flutter/widgets.dart';

bool _isRtlStrong(int c) =>
    (c >= 0x0590 && c <= 0x08FF) ||
    (c >= 0xFB1D && c <= 0xFDFF) ||
    (c >= 0xFE70 && c <= 0xFEFF);

bool _isLtrStrong(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0x00C0 && c <= 0x024F) ||
    (c >= 0x0370 && c <= 0x052F) ||
    (c >= 0x3040 && c <= 0x9FFF);

/// Direction of the first strongly directional character, or [fallback] if none.
TextDirection detectTextDirection(
  String text, {
  TextDirection fallback = TextDirection.ltr,
}) {
  for (final rune in text.runes) {
    if (_isRtlStrong(rune)) return TextDirection.rtl;
    if (_isLtrStrong(rune)) return TextDirection.ltr;
  }
  return fallback;
}

/// Renders user or model content in its own direction, independent of the UI locale.
class BidiText extends StatelessWidget {
  const BidiText(this.text, {super.key, this.style, this.maxLines});

  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final direction = detectTextDirection(
      text,
      fallback: Directionality.of(context),
    );
    return Directionality(
      textDirection: direction,
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          style: style,
          maxLines: maxLines,
          textAlign: TextAlign.start,
        ),
      ),
    );
  }
}
