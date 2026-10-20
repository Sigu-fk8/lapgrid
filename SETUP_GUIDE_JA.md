# LAPGRID 公開・クラウド化ガイド

## いまの状態
- `index.html`: ブラウザ内保存で動く試作品。複数端末同期・ログイン・共有はまだありません。
- `supabase/migrations/001_initial_schema.sql`: 初期DB構造。
- `supabase/migrations/002_harden_moderation.sql`: 通常ユーザーが自分の記録を承認済みにできないようにする追加SQL。
- Next.js/Supabaseの本番アプリはまだ未接続です。このHTMLだけを公開してもクラウド版にはなりません。

## クラウド版に必要なアカウント
1. Supabase: データベースとログイン認証
2. Vercel: Webアプリのホスティング
3. GitHub: ソース管理（Vercel連携に推奨）

これらはユーザー本人のアカウントで作成してください。パスワードや秘密鍵をチャットに貼らないでください。

## Supabaseの準備
1. Supabaseで新しいプロジェクトを作成し、DBパスワードを安全な場所に保管する。
2. SQL Editorで `001_initial_schema.sql` を実行する。
3. 続けて `002_harden_moderation.sql` を実行する。
4. Project URLとPublishable key（またはAnon key）を控える。`service_role` / secret keyはブラウザや公開リポジトリに絶対に置かない。
5. Authenticationのメール認証を設定する。公開後はSite URLとRedirect URLsを実際の公開ドメインに合わせる。

## 公開までの残作業
- Next.js + TypeScriptの実アプリを用意し、Supabase Authを接続する。
- 走行記録とガレージの作成・閲覧・編集・削除をクラウドに接続する。
- ランキングは `visibility='public' AND moderation_status='approved'` の記録だけを対象にする。
- 管理者承認は信頼できるサーバー側処理で行う。サービスロールキーをクライアントに含めない。
- テスト用の別アカウントで、他人の非公開記録にアクセスできないことを確認する。
- 気象API連携、画像/GPSアップロード、利用規約、プライバシー、通報機能は公開前に追加する。

## 公開後の重要事項
- 初期ランキングのサンプル記録は架空データとして明示し、本物の公式ランキングに混ぜない。
- 自己申告、GPSログ添付、公式リザルト添付、運営承認済みは別々に表示する。
- ラップタイムは整数ミリ秒で比較する。
- 公開URLができたら、Supabase AuthのURL設定も必ず更新する。
