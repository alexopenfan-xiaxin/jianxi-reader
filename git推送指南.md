# Git 推送项目到 GitHub 仓库

## 前置条件

- 已安装 Git（Flutter 自带：`flutter/bin/mingit/cmd/git.exe`）
- 已创建 GitHub 仓库
- 有 GitHub Personal Access Token

## 步骤

### 1. 初始化本地仓库

```bash
cd 项目目录
git init
```

### 2. 添加远程仓库

```bash
git remote add origin https://github.com/用户名/仓库名.git
```

### 3. 如果远程仓库已有文件（如 README.md、.gitignore）

```bash
# 拉取远程文件并 rebase
git pull origin main --rebase
```

如果提示 untracked files 冲突，先备份再拉取：

```bash
# 备份本地冲突文件
Copy-Item ".gitignore" ".gitignore.local"
Copy-Item "README.md" "README.md.local"

# 删除冲突文件后拉取
Remove-Item ".gitignore", "README.md"
git pull origin main --rebase

# 完成后删除备份
Remove-Item ".gitignore.local", "README.md.local"
```

### 4. 配置 .gitignore

确保以下内容在 `.gitignore` 中：

```
# Flutter 构建缓存
.dart_tool/
.build/
.flutter-plugins*
.metadata
.packages
.pub-cache/

# Windows 临时文件
windows/flutter/ephemeral/
```

### 5. 添加文件并提交

```bash
git add -A
git commit -m "初始提交"
```

如果未配置 Git 用户信息：

```bash
git config user.email "your@email.com"
git config user.name "你的用户名"
```

### 6. 推送

```bash
# 使用 Personal Access Token 认证
git remote set-url origin https://用户名:你的token@github.com/用户名/仓库名.git
git push -u origin main

# 推送后立即移除 token（安全）
git remote set-url origin https://github.com/用户名/仓库名.git
```

### 7. 创建版本标签

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 8. 创建 GitHub Release（通过 API）

创建 Release 时，如果版本日志包含中文，需要确保 UTF-8 编码正确：

```bash
# 1. 将 JSON 写入文件（UTF-8 编码）
$utf8 = [System.Text.UTF8Encoding]::new($false)
$bytes = $utf8.GetBytes('{"tag_name":"v1.0.0","name":"v1.0.0","body":"APP 的第一个版本"}')
[System.IO.File]::WriteAllBytes("$env:TEMP\release.json", $bytes)

# 2. 创建 Release（用 curl 的 --data-binary 发送原样字节）
curl.exe -s -X POST "https://api.github.com/repos/用户名/仓库名/releases" ^
  -H "Authorization: Bearer 你的token" ^
  -H "Accept: application/vnd.github+json" ^
  -H "Content-Type: application/json; charset=utf-8" ^
  --data-binary "@$env:TEMP\release.json"

# 3. 上传 APK
$apk = [System.IO.File]::ReadAllBytes("build\app\outputs\flutter-apk\app-arm64-v8a-release.apk")
Invoke-RestMethod -Uri "https://uploads.github.com/repos/用户名/仓库名/releases/$releaseId/assets?name=app-arm64-v8a-release.apk" `
    -Method Post -Headers @{ Authorization = "Bearer 你的token" } -Body $apk -ContentType "application/vnd.android.package-archive"
```

**注意**：PowerShell 的 `Invoke-RestMethod` + `ConvertTo-Json` 会破坏中文字符编码。必须使用 `curl.exe --data-binary` + 手动编码的 UTF-8 JSON 文件来发送中文内容。

## 注意事项

- **Token 安全**：推送后立即从 remote URL 中移除 token，避免 token 泄露到 `.git/config`
- **构建产物**：`.dart_tool/`、`build/`、`.flutter-plugins*`、`.metadata` 等不要提交
- **CRLF 警告**：Windows 上 `git add` 时出现 `LF will be replaced by CRLF` 是正常提示，不影响提交
- **SSL 问题**：如果推送超时或 SSL 报错，检查网络代理设置
