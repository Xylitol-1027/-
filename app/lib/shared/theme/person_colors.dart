import 'package:flutter/material.dart';

/// 「自分」「相手」の色として選べる固定スウォッチ。design.md 3.5節参照。
/// ライト/ダークモードそれぞれで見やすい色調を持つ。
class PersonColorSwatch {
  const PersonColorSwatch(this.light, this.dark);

  final Color light;
  final Color dark;
}

const List<PersonColorSwatch> kPersonColorSwatches = [
  PersonColorSwatch(Color(0xFF2A78D6), Color(0xFF3987E5)),
  PersonColorSwatch(Color(0xFFEB6834), Color(0xFFD95926)),
  PersonColorSwatch(Color(0xFF1BAF7A), Color(0xFF199E70)),
  PersonColorSwatch(Color(0xFF4A3AA7), Color(0xFF9085E9)),
  PersonColorSwatch(Color(0xFFE34948), Color(0xFFE66767)),
  PersonColorSwatch(Color(0xFFE87BA4), Color(0xFFD55181)),
];

Color personColorFor(int index, Brightness brightness) {
  final swatch = kPersonColorSwatches[index % kPersonColorSwatches.length];
  return brightness == Brightness.dark ? swatch.dark : swatch.light;
}
