# MofTools 共通VCC配布一覧

GitHub公開先は `moffox/mof-tools-vpm`、VCCへ登録するURLは `https://moffox.github.io/mof-tools-vpm/index.json` です。複数ツール・複数バージョンを一つの一覧で扱います。GitHubへの公開・Git操作は手作業です。

## 最初の設定

1. この `VpmListing` フォルダーを右クリックし、TortoiseGitでGitリポジトリを作成します。親のMofToolsフォルダーには作成しません。
2. GitHubで公開リポジトリ `mof-tools-vpm` を空で作成します。TortoiseGitでリモートを登録し、このフォルダーのファイルをCommit・Pushします。
3. GitHubのSettings → Pages → Build and deploymentで、Sourceを「Deploy from a branch」にし、使用中のブランチの `/docs` を選択します。独自の公開用Actionsは追加しません。
4. 配布ページは `https://moffox.github.io/mof-tools-vpm/` になります。最初の一覧は空で、未公開の版は表示しません。

## 本体のリリース後に一覧へ登録する

本体のZIP・package.jsonをGitHubのDraftへ添付し、Immutable releaseとして公開した後に実行します。Windows PowerShell 5.1またはPowerShell 7を使用してください。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .tools/Update-Listing.ps1 `
  -PackageManifest ../MeshJoin/.dist/v0.6.1/package.json `
  -PackageZip ../MeshJoin/.dist/v0.6.1/dev.moftools.mesh-join-0.6.1.zip
```

公開URLからZIPを取得して、手元のZIPとSHA-256が一致することを確認します。その後、`release-records/<パッケージID>/<バージョン>.json` と `docs/index.json` を作成します。ZIPやアバターをこのリポジトリへ置く必要はありません。

TortoiseGitで追加・変更されたJSONを確認してCommit・Pushします。Pagesの反映後、VCCで一覧の更新と導入を確認してください。同じ版は変更せず、修正は新しい版として追加します。古い版の記録とGitHub Releasesは残します。

今後ほかのツールを追加する場合も、その公開済みのpackage.jsonとZIPを同じスクリプトへ渡します。パッケージIDごとに別管理され、既存ツールの版は保持されます。配布一覧のURLやIDは変更しません。

一覧の名前などは `source.json`、案内ページは `docs/index.html` を編集します。登録済みの版から一覧だけを再生成するときは、パッケージ引数を付けずに上記のPowerShellコマンドを実行します。実行許可はそのプロセスだけに適用し、Windows全体の設定は変更しません。

`-SkipDownloadCheck` は公開前のローカル検証専用です。通常の公開作業では指定しません。ローカル生成・ImportはGitHubのリリースや設定を操作せず、GitのCommit・Pushも行いません。
