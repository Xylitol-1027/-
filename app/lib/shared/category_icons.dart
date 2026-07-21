import 'package:flutter/material.dart';

/// カテゴリで選べる線画アイコンの候補一覧。design.md 3.1節「アイコン候補一覧」に対応。
/// 絵文字・漢字は使わず、Material Iconsの線画(outlined)のみを使う。
class CategoryIconOption {
  const CategoryIconOption(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

const List<CategoryIconOption> kCategoryIconOptions = [
  CategoryIconOption('food', '食費の例', Icons.restaurant_outlined),
  CategoryIconOption('daily', '日用品の例', Icons.shopping_bag_outlined),
  CategoryIconOption('housing', '住居費の例', Icons.home_outlined),
  CategoryIconOption('comm', '通信費の例', Icons.smartphone_outlined),
  CategoryIconOption('transport', '交通費の例', Icons.directions_car_outlined),
  CategoryIconOption('fun', '娯楽費の例', Icons.auto_awesome_outlined),
  CategoryIconOption('social', '交際費の例', Icons.card_giftcard_outlined),
  CategoryIconOption('beauty', '香水瓶', Icons.spa_outlined),
  CategoryIconOption('medical', '医療費', Icons.add_box_outlined),
  CategoryIconOption('insurance', '保険', Icons.shield_outlined),
  CategoryIconOption('education', '教育・書籍', Icons.menu_book_outlined),
  CategoryIconOption('pet', 'ペット', Icons.pets_outlined),
  CategoryIconOption('savings', '貯金・積立', Icons.savings_outlined),
  CategoryIconOption('subscription', 'サブスク・会費', Icons.autorenew),
  CategoryIconOption('cafe', 'カフェ・飲み物', Icons.local_cafe_outlined),
  CategoryIconOption('travel', '旅行', Icons.flight_outlined),
  CategoryIconOption('fuel', 'ガソリン・車維持費', Icons.local_gas_station_outlined),
  CategoryIconOption('document', '税金・書類', Icons.description_outlined),
  CategoryIconOption('fitness', 'スポーツ・ジム', Icons.fitness_center_outlined),
  CategoryIconOption('repair', '修理・メンテナンス', Icons.build_outlined),
  CategoryIconOption('baby', '子育て・育児', Icons.child_care_outlined),
  CategoryIconOption('money', '現金・その他お金', Icons.payments_outlined),
  CategoryIconOption('tag', 'その他（汎用）', Icons.local_offer_outlined),
];

const String kDefaultCategoryIcon = 'tag';

IconData iconForId(String id) {
  for (final option in kCategoryIconOptions) {
    if (option.id == id) return option.icon;
  }
  return kCategoryIconOptions.last.icon;
}
