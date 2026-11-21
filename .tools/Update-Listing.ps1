param([string]$PackageManifest, [string]$PackageZip, [switch]$SkipDownloadCheck)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-JsonTable([string]$Text) {
    $object = $Text | ConvertFrom-Json
    $table = [ordered]@{}
    foreach ($property in $object.PSObject.Properties) { $table[$property.Name] = $property.Value }
    return $table
}
$listingRoot = Split-Path $PSScriptRoot -Parent
$encoding = [Text.UTF8Encoding]::new($false)
$source = Read-JsonTable (Get-Content -LiteralPath (Join-Path $listingRoot 'source.json') -Raw -Encoding UTF8)
if (!$source.name -or !$source.id -or !$source.url -or !$source.author.email) { throw '配布一覧の基本情報が不足しています。' }
if ($PackageManifest -or $PackageZip) {
    if (!$PackageManifest -or !$PackageZip) { throw 'PackageManifestとPackageZipを両方指定してください。' }
    $manifest = Read-JsonTable (Get-Content -LiteralPath $PackageManifest -Raw -Encoding UTF8)
    if ($manifest.name -notmatch '^[a-z0-9]+(?:[.-][a-z0-9]+)+$' -or
        $manifest.version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') { throw 'パッケージ名・バージョンが不正です。' }
    $url = [Uri]$manifest.url
    if ($url.Scheme -ne 'https' -or $url.Host -ne 'github.com' -or
        $url.AbsolutePath -notmatch '^/moffox/[^/]+/releases/download/[^/]+/[^/]+\.zip$') { throw 'moffoxのGitHub ReleasesのZIP URLを指定してください。' }
    $zip = [IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($PackageZip))
    try {
        $entry = $zip.GetEntry('package.json')
        if (!$entry) { throw 'ZIP直下にpackage.jsonがありません。' }
        $reader = [IO.StreamReader]::new($entry.Open())
        try { $embedded = Read-JsonTable ($reader.ReadToEnd()) } finally { $reader.Dispose() }
        if (($embedded | ConvertTo-Json -Depth 40 -Compress) -cne ($manifest | ConvertTo-Json -Depth 40 -Compress)) {
            throw '添付用package.jsonとZIP内のpackage.jsonが一致しません。'
        }
    } finally { $zip.Dispose() }
    $hash = (Get-FileHash -LiteralPath $PackageZip -Algorithm SHA256).Hash.ToLowerInvariant()
    if (!$SkipDownloadCheck) {
        # Verify the published bytes, not merely the existence of a URL. No files are uploaded.
        $download = [IO.Path]::GetTempFileName()
        try {
            Invoke-WebRequest -Uri $url -OutFile $download
            if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hash) {
                throw '公開ZIPと手元のZIPのハッシュが一致しません。'
            }
        } finally { Remove-Item -LiteralPath $download -Force }
    } else { Write-Warning '公開ZIPの取得確認を省略しました。ローカル検証専用です。' }
    $manifest['zipSHA256'] = $hash
    $recordDirectory = Join-Path $listingRoot "release-records/$($manifest.name)"
    $recordPath = Join-Path $recordDirectory "$($manifest.version).json"
    $recordJson = ($manifest | ConvertTo-Json -Depth 40) + "`n"
    if (Test-Path -LiteralPath $recordPath) {
        if ([IO.File]::ReadAllText($recordPath) -cne $recordJson) { throw '登録済みの同一バージョンは変更できません。新しいバージョンを登録してください。' }
    } else {
        New-Item -ItemType Directory -Path $recordDirectory -Force | Out-Null
        [IO.File]::WriteAllText($recordPath,$recordJson,$encoding)
    }
}
$packages = [ordered]@{}
$recordsRoot = Join-Path $listingRoot 'release-records'
if (Test-Path -LiteralPath $recordsRoot) {
    foreach ($file in (Get-ChildItem -LiteralPath $recordsRoot -File -Recurse -Filter '*.json' | Sort-Object FullName)) {
        $record = Read-JsonTable (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8)
        if (!$packages.Contains($record.name)) { $packages[$record.name] = @{ versions = [ordered]@{} } }
        if ($packages[$record.name].versions.Contains($record.version)) { throw 'バージョンが重複しています。' }
        $packages[$record.name].versions[$record.version] = $record
    }
}
$source['packages'] = $packages
$docs = Join-Path $listingRoot 'docs'
New-Item -ItemType Directory -Path $docs -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $docs 'index.json'), ($source | ConvertTo-Json -Depth 50) + "`n", $encoding)
Write-Host "配布一覧を生成しました。パッケージ数: $($packages.Count)"
Write-Host 'release-recordsとdocs/index.jsonをTortoiseGitで確認・Commit・Pushしてください。送信や公開は実行していません。'
