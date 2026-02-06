
## サンプルデータで試す

リポジトリにはサンプルデータベースが含まれています：
```bash
# サンプルDBをコピーして使用
cp bowling_sample.db bowling.db

# アプリケーション起動
bundle exec rackup -p 4567
```

サンプルには完了済みのゲームとプレイ中のゲームが含まれており、すぐに動作を確認できます。

## 新規データベースで開始

サンプルを使わず、空のデータベースから始める場合：
```bash
# 既存のbowling.dbがあれば削除
rm -f bowling.db

# アプリケーション起動（自動的に新規DBが作成されます）
bundle exec rackup -p 4567
```
