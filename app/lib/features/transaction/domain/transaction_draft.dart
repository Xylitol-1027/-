import '../../../database/app_database.dart';

/// 新規取引フォームへの事前入力用データ(レシートOCR確認画面から渡す)。
/// DBの行ではなくフォーム初期値なので、idやcreatedAt等は持たない。
class TransactionDraft {
  const TransactionDraft({
    required this.date,
    required this.payee,
    required this.categoryId,
    required this.amount,
    required this.splitType,
    required this.payer,
    required this.necessity,
  });

  final DateTime date;
  final String payee;
  final int categoryId;
  final int amount;
  final SplitType splitType;
  final Payer payer;
  final Necessity necessity;
}
