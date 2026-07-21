# 家計簿アプリ 詳細設計書

作成日: 2026-07-21
関連文書: [requirements.md](./requirements.md)（要件定義書）

## 1. アーキテクチャ概要

| 項目 | 採用技術 |
|---|---|
| フレームワーク | Flutter（Dart） |
| 状態管理 | Riverpod |
| ローカルDB | Drift（SQLite） |
| ルーティング | go_router |
| カメラ | `camera` パッケージ |
| OCR | Google ML Kit（`google_mlkit_text_recognition`、オンデバイス） |
| グラフ描画 | `fl_chart` |
| フォルダ構成 | feature-first |

### 1.1 レイヤー構成（機能フォルダ内の共通パターン）

各機能フォルダは以下の3層で構成する。

```
lib/features/<feature>/
├── data/          # Driftテーブル定義、Repositoryクラス（DBアクセス）
├── domain/        # ビジネスロジック（精算計算、OCRパーサー等）
├── presentation/  # 画面(Widget)、Riverpodプロバイダ
```

## 2. プロジェクトフォルダ構成

```
lib/
├── main.dart
├── router/
│   └── app_router.dart          # go_routerのルート定義
├── database/
│   └── app_database.dart        # Drift DB定義（全テーブルをまとめる）
├── features/
│   ├── transaction/              # 取引一覧・追加・編集
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── receipt_scan/              # レシート撮影・OCR・確認
│   │   ├── data/
│   │   ├── domain/                # OCRパーサーロジック
│   │   └── presentation/
│   ├── settlement/                # 精算（折半/立替の負債計算）
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── summary/                   # サマリー・グラフ（月次/年次切替）
│   │   ├── data/
│   │   └── presentation/
│   └── category/                  # カテゴリ管理
│       ├── data/
│       └── presentation/
└── shared/
    ├── widgets/                   # 共通UIコンポーネント
    └── theme/
```

## 3. データベース設計

Drift（SQLite）で以下の4テーブルを定義する。

### 3.1 `categories` テーブル

| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | |
| name | TEXT | NOT NULL | カテゴリ名 |
| default_necessity | TEXT | NOT NULL | `necessary`（必要）/ `wasteful`（浪費） |
| sort_order | INTEGER | NOT NULL | 表示順 |
| created_at | DATETIME | NOT NULL | |

初期データ（アプリ初回起動時に投入、ユーザーは追加・編集・削除可能）:

| name | default_necessity |
|---|---|
| 食費 | necessary |
| 日用品 | necessary |
| 住居費 | necessary |
| 通信費 | necessary |
| 交通費 | necessary |
| 娯楽費 | wasteful |
| 交際費 | wasteful |
| 美容 | wasteful |

### 3.2 `transactions` テーブル

| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | |
| date | DATE | NOT NULL | 取引日 |
| payee | TEXT | NOT NULL | 支払先（自由入力＋履歴オートコンプリート） |
| category_id | INTEGER | NOT NULL, FK → categories.id | |
| amount | INTEGER | NOT NULL | 金額（円） |
| split_type | TEXT | NOT NULL | `none`（空白）/ `split`（折半）/ `advance`（立替） |
| payer | TEXT | NOT NULL | `self` / `partner`。空白の場合も含め常に入力する。表示名は`app_settings`テーブルの値を参照する（3.5節） |
| necessity | TEXT | NOT NULL | `necessary` / `wasteful`。登録時にカテゴリのデフォルト値をコピーし、個別に上書き可能 |
| settlement_id | INTEGER | NULL, FK → settlements.id | 精算済みならその精算IDが入る。未精算はNULL |
| created_at | DATETIME | NOT NULL | |
| updated_at | DATETIME | NOT NULL | |

- 削除は物理削除（確認ダイアログ表示後、テーブルから直接DELETE。ソフトデリートは行わない）
- レシート画像はこのテーブルに保持しない（OCR確認・登録完了後に画像は破棄する。3.4節参照）

### 3.3 `settlements` テーブル

| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | |
| settled_at | DATETIME | NOT NULL | 精算実行日時 |
| net_amount | INTEGER | NOT NULL | 精算時点の負債額（絶対値） |
| debtor | TEXT | NOT NULL | 精算時点で負債があった側。`self` / `partner` |
| created_at | DATETIME | NOT NULL | |

### 3.4 レシート画像の扱い

レシート画像は端末の一時ディレクトリにのみ保存し、OCR確認画面で「登録」が完了した時点で削除する。DBにも画像パス・画像本体も保持しない。これにより、Android Auto Backup for Apps の容量上限（25MB/アプリ）に対する懸念も解消される（4章参照）。

### 3.5 `app_settings` テーブル（表示名などのアプリ設定）

自分・同棲相手の表示名など、アプリ全体で使う設定値を保持する単一行テーブル。

| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | INTEGER | PRIMARY KEY | 常に`1`固定（単一行のみ） |
| self_name | TEXT | NOT NULL, DEFAULT `自分` | 「自分」の表示名 |
| partner_name | TEXT | NOT NULL, DEFAULT `相手` | 「同棲相手」の表示名 |

- 設定画面でこの2つの値を編集できる（7.2節）。
- `transactions.payer` は内部的に `self` / `partner` の固定値で保持し、画面表示のときだけこのテーブルの`self_name` / `partner_name`に置き換える。名前を変更しても過去データの`payer`値（`self`/`partner`）は変わらないため、精算ロジック（5章）への影響はない。

## 4. バックアップ設計

- **方式**: Android Auto Backup for Apps（OSレベルの自動バックアップ）のみを採用する。アプリ内にログインUI・Google Sign-In等は実装しない。
- **設定**: `AndroidManifest.xml` に `android:allowBackup="true"` と `android:fullBackupContent` を設定し、DriftのSQLiteファイルをバックアップ対象に含める。
- **除外対象**: レシート画像の一時ファイル（そもそも3.4節の方針により登録完了後は残らないため、除外設定は保険的な位置づけ）。
- **復元**: 同一アプリの再インストール時にOSが自動復元する。ユーザーが任意のタイミングで手動リストアする機能は持たない。

## 5. 精算ロジック（ドメインロジック）

### 5.1 負債の計算

未精算（`settlement_id IS NULL`）かつ `split_type != 'none'` の取引を対象に、以下の式で自分(`self`)から見た収支を積算する。

```
signed_amount(transaction):
  base = (split_type == 'split') ? round(amount / 2) : amount   // splitは1/2、advanceは1/1、四捨五入
  return payer == 'self' ? +base : -base   // 自分が払った分は相手への債権(+)、相手が払った分は自分の債務(-)

balance = Σ signed_amount(t) for all unsettled t

balance > 0  → 相手が自分に balance 円を支払うべき
balance < 0  → 自分が相手に |balance| 円を支払うべき
balance == 0 → 精算不要
```

`split_type = 'none'`（空白）の取引にも`payer`は記録されるが、この集計対象（`split_type != 'none'`）には含まれないため、負債計算には一切影響しない。空白の`payer`はあくまで「どちらの支出か」を記録するための情報である。

### 5.2 精算実行

「精算する」ボタン押下時:
1. 現在の `balance` と `debtor`（負債がある側）を計算する
2. `settlements` テーブルに `net_amount = |balance|`, `debtor` でレコードを作成する
3. 計算対象に含まれていた全取引（`settlement_id IS NULL AND split_type != 'none'`）に、作成した精算IDを一括で設定する

この方式により、精算後に過去日付の取引を追加登録しても、その取引の `settlement_id` はNULLのままなので次回精算時に正しく未精算分として扱われる。

## 6. レシートOCR処理フロー

```
[カメラ画面]
  camera パッケージでプレビュー表示 + ガイド枠オーバーレイ
       ↓ 撮影
[画像]
  google_mlkit_text_recognition に画像を渡す
       ↓
[OCR結果: テキスト + バウンディングボックスのリスト]
       ↓
[パーサー（domain層、自作ロジック）]
  - 日付候補: 正規表現 (`\d{4}[/年]\d{1,2}[/月]\d{1,2}`等) にマッチする文字列を抽出
  - 支払先候補: Y座標が最小のテキストブロックを採用
  - 金額候補: 「合計」「お会計」「小計」等のキーワード近傍の数値、または最大の金額を採用
  - 各項目、最有力候補を1件ずつ返す（複数候補のスコアリングは行わない）
       ↓
[確認画面]
  取引追加フォームに候補値を自動入力した状態で表示
  ユーザーが確認・修正して保存
       ↓
  画像を破棄し、テキストデータのみtransactionsテーブルへ保存
```

## 7. 画面構成

### 7.1 ナビゲーション構造

ボトムナビゲーション4タブ + 各タブ共通のFAB。

```
BottomNavigationBar
├── ① 取引一覧（ホーム）  route: /transactions
├── ② 精算                route: /settlement
├── ③ サマリー（月次/年次切替） route: /summary
└── ④ 設定                route: /settings
         └── カテゴリ管理  route: /settings/categories

FAB（① 取引一覧タブに表示）
├── 「レシートで登録」 → /transactions/scan
└── 「手入力で登録」   → /transactions/new
```

### 7.2 画面一覧と概要

| 画面 | ルート | 概要 |
|---|---|---|
| 取引一覧 | `/transactions` | 日付降順で取引をリスト表示。タップで編集画面へ。長押しまたはスワイプで削除（確認ダイアログ表示） |
| 取引追加・編集 | `/transactions/new`, `/transactions/:id/edit` | 日付・支払先(オートコンプリート付)・カテゴリ・金額・折半/立替/空白・支払者(常時表示、フラグに関わらず選択可)・必要/浪費(カテゴリ選択時にデフォルト自動反映、上書き可) を入力するフォーム |
| レシート撮影 | `/transactions/scan` | カメラプレビュー＋ガイド枠。撮影後、自動でOCR・パーサー処理を実行し、結果を取引追加フォームに自動入力した状態で表示（画面遷移としては取引追加画面の事前入力版） |
| 精算 | `/settlement` | 現在の負債状況（「相手 → 自分 ¥XXXX」等、名前は`app_settings`の表示名を使用）を表示。対象となっている未精算取引の一覧も表示。「精算する」ボタンで精算実行（確認ダイアログあり）。過去の精算履歴一覧も表示 |
| サマリー | `/summary` | 画面上部で「月次/年次」を切り替えるセグメントコントロールと期間送り(前後の月・年へ移動)を用意。選択期間のカテゴリ別支出割合をドーナツ円グラフ(fl_chart)＋凡例で表示し、「必要/浪費」の合計金額・比率も表示する |
| 設定 | `/settings` | 自分・同棲相手の表示名を編集する項目、カテゴリ管理画面への導線、バックアップ状態の説明表示、アプリ情報 |
| カテゴリ管理 | `/settings/categories` | カテゴリの一覧・追加・編集（名称・デフォルト必要度）・削除 |

## 8. テスト方針

| 対象 | テスト種別 | 内容 |
|---|---|---|
| OCRパーサー（domain層） | ユニットテスト | 複数パターンのレシートOCRテキスト（コンビニ・スーパー・飲食店等を想定したダミーテキスト+バウンディングボックス）を入力し、日付・支払先・金額の抽出結果を検証 |
| 精算ロジック（domain層） | ユニットテスト | 折半(1/2)・立替(1/1)・空白(計上なし)それぞれの負債計算、四捨五入、精算実行後のsettlement_id付与とbalanceリセットを検証 |
| Driftのクエリ（data層） | ユニットテスト | 未精算取引の抽出、精算後の再計算、カテゴリのデフォルト必要度反映などのクエリを検証 |
| UI（Widgetテスト） | 対象外 | 個人開発のため、手動確認で担保する |

## 9. 主要パッケージ一覧

| パッケージ | 用途 |
|---|---|
| `flutter_riverpod` | 状態管理 |
| `drift` / `sqlite3_flutter_libs` | ローカルDB |
| `go_router` | ルーティング |
| `camera` | レシート撮影 |
| `google_mlkit_text_recognition` | OCR |
| `fl_chart` | サマリー画面のドーナツ円グラフ描画 |

## 10. スコープ外（次フェーズ以降）

要件定義書9章に準じ、以下は本設計の対象外とする。

- ログイン機能・クラウド同期・共有機能
- カテゴリ別予算上限・超過アラート
- レシート明細行単位でのOCR解析・自動分割
- レシート画像の保存・後からの閲覧
- Google Drive APIを用いた手動バックアップ・複数候補選択OCR UI（設計検討はしたが不採用。詳細は本文中の該当節を参照）
