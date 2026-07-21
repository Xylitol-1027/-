import 'package:flutter_test/flutter_test.dart';
import 'package:kakeibo/features/receipt_scan/domain/receipt_parser.dart';

void main() {
  group('parseReceipt', () {
    test('コンビニのレシート(合計のみ)を正しく解析する', () {
      final blocks = [
        const OcrTextBlock(text: 'セブンイレブン 渋谷店', top: 10),
        const OcrTextBlock(text: '2026年07月20日 18:23', top: 40),
        const OcrTextBlock(text: 'おにぎり 150', top: 80),
        const OcrTextBlock(text: 'お茶 120', top: 100),
        const OcrTextBlock(text: '合計 ¥580', top: 140),
      ];
      final result = parseReceipt(blocks);
      expect(result.date, DateTime(2026, 7, 20));
      expect(result.payee, 'セブンイレブン 渋谷店');
      expect(result.amount, 580);
    });

    test('スーパーのレシート(小計→お会計)は税込の大きい方を採用する', () {
      final blocks = [
        const OcrTextBlock(text: '西友 経堂店', top: 5),
        const OcrTextBlock(text: '2026-07-18', top: 30),
        const OcrTextBlock(text: '食パン 198', top: 60),
        const OcrTextBlock(text: '牛乳 258', top: 80),
        const OcrTextBlock(text: '小計 ¥3,000', top: 100),
        const OcrTextBlock(text: 'お会計 ¥3,240', top: 120),
      ];
      final result = parseReceipt(blocks);
      expect(result.date, DateTime(2026, 7, 18));
      expect(result.payee, '西友 経堂店');
      expect(result.amount, 3240);
    });

    test('飲食店のレシート(キーワードなし)は最大金額を候補とする', () {
      final blocks = [
        const OcrTextBlock(text: '焼肉つるや', top: 8),
        const OcrTextBlock(text: '2026/07/10', top: 35),
        const OcrTextBlock(text: 'カルビ 2500', top: 70),
        const OcrTextBlock(text: 'ビール 500', top: 90),
        const OcrTextBlock(text: 'お品書き No.12', top: 120),
        const OcrTextBlock(text: '¥8,400', top: 150),
      ];
      final result = parseReceipt(blocks);
      expect(result.date, DateTime(2026, 7, 10));
      expect(result.payee, '焼肉つるや');
      // キーワード一致なし -> レシート内最大金額(8400)を候補にする
      // ("No.12"の12は候補にならない: 2桁以上でも文脈上有効だが、8400の方が大きいため採用されない)
      expect(result.amount, 8400);
    });

    test('日付が見つからない場合はnullを返す', () {
      final blocks = [
        const OcrTextBlock(text: 'スターバックス', top: 5),
        const OcrTextBlock(text: '合計 ¥580', top: 50),
      ];
      final result = parseReceipt(blocks);
      expect(result.date, isNull);
      expect(result.payee, 'スターバックス');
      expect(result.amount, 580);
    });

    test('テキストブロックが空の場合はすべてnullを返す', () {
      final result = parseReceipt(const []);
      expect(result.date, isNull);
      expect(result.payee, isNull);
      expect(result.amount, isNull);
    });

    test('日付の行に含まれる数値(年など)は金額候補として扱わない', () {
      final blocks = [
        const OcrTextBlock(text: 'カフェ ド ロン', top: 5),
        const OcrTextBlock(text: '2026/07/21', top: 20),
        const OcrTextBlock(text: '¥580', top: 40),
      ];
      final result = parseReceipt(blocks);
      expect(result.date, DateTime(2026, 7, 21));
      // 2026(日付由来)ではなく580が金額候補になる
      expect(result.amount, 580);
    });

    test('支払先はY座標が最小(レシート最上部)のブロックを採用する', () {
      final blocks = [
        const OcrTextBlock(text: '但し書き', top: 200),
        const OcrTextBlock(text: 'ドコモショップ', top: 2),
        const OcrTextBlock(text: '2026/07/12', top: 20),
      ];
      final result = parseReceipt(blocks);
      expect(result.payee, 'ドコモショップ');
    });
  });
}
