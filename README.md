# WSL環境セットアップ

任意のディストリビューションを指定のディレクトリにインストールし、環境に合わせた初期化を行うツール。

## 動作環境

- Windows 11 23H2 以上
- Ruby 3.1 以上 (Ruby Installerでインストール済み)

タスクはRakefileで書かれているため、Rubyが必要です。

## 実行方法

1. Rubyをインストールしておく。
2. rake を実行する。

## Rake

- (default) ... createを実行する。
- create ... WSLシステムをインストールし、カレントディレクトリにLinuxを置く。
- update ... アップデートする。
- destory ... Linuxを削除する。
