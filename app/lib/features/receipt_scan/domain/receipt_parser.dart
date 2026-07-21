/// OCR(Google ML Kit)が返す1つのテキストブロック相当の簡易モデル。
/// design.md 6章「OCR結果: テキスト + バウンディングボックスのリスト」に対応。
class OcrTextBlock {
  const OcrTextBlock({required this.text, required this.top, this.left = 0});

  final String text;

  /// バウンディングボックスの上端のY座標。値が小さいほどレシート上部にある。
  final double top;
  final double left;
}

/// パーサーが返す最有力候補。各項目1件ずつ、複数候補のスコアリングは行わない。
/// design.md 6章参照。
class ReceiptParseResult {
  const ReceiptParseResult({this.date, this.payee, this.amount});

  final DateTime? date;
  final String? payee;
  final int? amount;
}

final _dateRegex = RegExp(
  r'(\d{4})[/\-年](\d{1,2})[/\-月](\d{1,2})',
);

final _amountKeywordRegex = RegExp(
  r'(?:合計|お会計|小計|ご利用金額)\s*[:：]?\s*¥?\s*([\d,]+)',
);

final _anyNumberRegex = RegExp(r'¥?\s*([\d,]{2,})\s*円?');

/// 日付候補: `YYYY/MM/DD` `YYYY年MM月DD日` 等の正規表現パターンに一致する
/// 文字列を抽出する。design.md 6章参照。
DateTime? _extractDate(List<OcrTextBlock> blocks) {
  for (final block in blocks) {
    final match = _dateRegex.firstMatch(block.text);
    if (match == null) continue;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) continue;
    return DateTime(year, month, day);
  }
  return null;
}

/// 支払先候補: レシート上部(バウンディングボックスのY座標が最小の範囲)に
/// ある文字列を候補とする。design.md 6章参照。
String? _extractPayee(List<OcrTextBlock> blocks) {
  if (blocks.isEmpty) return null;
  final sorted = [...blocks]..sort((a, b) => a.top.compareTo(b.top));
  return sorted.first.text.trim();
}

/// 金額候補: 「合計」「お会計」「小計」等のキーワード近傍の数値、または
/// レシート内最大金額を候補とする。design.md 6章参照。
///
/// キーワードに一致する行が複数ある場合(「小計」→「合計」等)は、その中の
/// 最大額を採用する。値引き前の小計より、税込の合計・お会計の方が通常大きい
/// ため、単純な最大値判定で最終的な支払金額に寄せられる。
int? _extractAmount(List<OcrTextBlock> blocks) {
  int? keywordAmount;
  for (final block in blocks) {
    final match = _amountKeywordRegex.firstMatch(block.text);
    if (match == null) continue;
    final amount = int.tryParse(match.group(1)!.replaceAll(',', ''));
    if (amount == null) continue;
    if (keywordAmount == null || amount > keywordAmount) {
      keywordAmount = amount;
    }
  }
  if (keywordAmount != null) return keywordAmount;

  int? maxAmount;
  for (final block in blocks) {
    // 日付として認識される行の数値(年など)は金額候補から除外する
    if (_dateRegex.hasMatch(block.text)) continue;
    for (final match in _anyNumberRegex.allMatches(block.text)) {
      final amount = int.tryParse(match.group(1)!.replaceAll(',', ''));
      if (amount == null) continue;
      if (maxAmount == null || amount > maxAmount) {
        maxAmount = amount;
      }
    }
  }
  return maxAmount;
}

/// OCR結果(テキストブロック群)から、日付・支払先・金額の最有力候補を判定する。
/// design.md 6章「パーサー(domain層、自作ロジック)」に対応。
ReceiptParseResult parseReceipt(List<OcrTextBlock> blocks) {
  return ReceiptParseResult(
    date: _extractDate(blocks),
    payee: _extractPayee(blocks),
    amount: _extractAmount(blocks),
  );
}
