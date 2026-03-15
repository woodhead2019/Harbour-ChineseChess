# GitHub 发布指南

本指南说明如何将中国象棋项目发布到 GitHub。

## 发布前准备

### 1. 确保所有文件已提交
```bash
git status
git add .
git commit -m "准备发布版本 1.0.1"
```

### 2. 创建 Git 标签
```bash
git tag -a v1.0.1 -m "版本 1.0.1 - 首次正式发布"
git push origin v1.0.1
```

### 3. 编译所有版本
```bash
# Linux 版本
./build.sh gui linux

# Windows 版本
./build.sh gui windows

# 控制台版本（可选）
./build.sh console linux
./build.sh console windows
```

### 4. 打包发布文件
```bash
# 打包所有版本
./package.sh all

# 检查打包结果
ls -lh release/
```

## 发布文件说明

### Linux 版本
- **文件**：`cchess-1.0.1-linux-x86_64.tar.gz`
- **内容**：
  - `xq` - 可执行文件
  - `cchess.ini` - 配置文件
  - `skins/` - 皮肤资源
  - `sounds/` - 声音文件
  - `LICENSE` - 项目许可证
  - `README.md` - 项目说明
  - `VERSION` - 版本信息
- **不包含**：
  - AI 引擎文件（需用户自行下载）

### Windows 版本
- **文件**：`cchess-1.0.1-windows-x86_64.zip`
- **内容**：
  - `xq.exe` - GUI 可执行文件
  - `xq_con.exe` - 控制台可执行文件
  - `cchess.ini` - 配置文件
  - `skins/` - 皮肤资源
  - `sounds/` - 声音文件
  - `LICENSE` - 项目许可证
  - `README.md` - 项目说明
  - `VERSION` - 版本信息
- **不包含**：
  - AI 引擎文件（需用户自行下载）

### 源代码版本
- **文件**：`cchess-1.0.1-source.tar.gz`
- **内容**：
  - 所有源代码
  - 编译脚本
  - 文档

## 在 GitHub 创建 Release

### 1. 进入 GitHub Releases 页面
访问：`https://github.com/你的用户名/cchess/releases`

### 2. 创建新 Release
1. 点击 "Draft a new release"
2. 选择标签：`v1.0.1`
3. 输入标题：`中国象棋 GUI v1.0.1`
4. 编辑描述内容（使用 `RELEASE_NOTES.md` 模板）

### 3. 上传发布文件
上传以下文件：
- `cchess-1.0.1-linux-x86_64.tar.gz`
- `cchess-1.0.1-windows-x86_64.zip`
- `cchess-1.0.1-source.tar.gz`

### 4. 发布
点击 "Publish release"

## 发布检查清单

- [ ] 所有代码已提交到 Git
- [ ] 创建了 Git 标签
- [ ] Linux 版本编译成功
- [ ] Windows 版本编译成功
- [ ] 所有打包文件已生成
- [ ] 发布说明已准备好
- [ ] 许可证文件已包含
- [ ] README 文件已包含
- [ ] 版本信息已包含

## 发布后的工作

### 1. 测试下载
下载各平台版本并测试：
- Linux 版本：解压后运行 `./xq`
- Windows 版本：解压后运行 `xq.exe`

### 2. 更新文档
- 更新 README.md 中的版本号
- 更新 CHANGELOG.md（如果有）
- 更新下载链接

### 3. 通知用户
- 在项目主页发布公告
- 通过社交媒体通知
- 发送邮件通知订阅者

## 版本命名规范

### 主版本号
格式：`v主版本号.次版本号.修订号`

示例：
- `v1.0.0` - 首次正式发布
- `v1.0.1` - 小版本修复
- `v1.1.0` - 新功能
- `v2.0.0` - 重大更新

### 发布文件命名
格式：`cchess-{版本号}-{平台}-{架构}.tar.gz`

示例：
- `cchess-1.0.1-linux-x86_64.tar.gz`
- `cchess-1.0.1-windows-x86_64.zip`
- `cchess-1.0.1-source.tar.gz`

## 常见问题

### Q: 如何修复已发布的版本？
A: 创建新的补丁版本（如 v1.0.2），并更新 Release 说明。

### Q: 如何撤销已发布的 Release？
A: 在 GitHub Releases 页面可以删除 Release，但标签需要单独删除。

### Q: 如何添加新的平台支持？
A: 更新 `build.sh` 和 `package.sh` 脚本，添加新平台的编译和打包逻辑。

### Q: 如何更新许可证？
A: 更新所有 LICENSE 文件，创建新的 Release，并更新发布说明。

## 发布模板

使用 `RELEASE_NOTES.md` 作为发布说明模板，根据需要修改内容：

1. 替换 `{VERSION}` 为实际版本号
2. 替换 `{DATE}` 为发布日期
3. 替换 `{LINUX_SIZE}` 为 Linux 包大小
4. 替换 `{WINDOWS_SIZE}` 为 Windows 包大小
5. 替换 `{SOURCE_SIZE}` 为源代码包大小

## 自动化脚本

### 完整发布流程
```bash
#!/bin/bash

# 设置版本号
VERSION="1.0.1"

# 编译
./build.sh all

# 打包
./package.sh all

# 提交代码
git add .
git commit -m "发布版本 $VERSION"

# 创建标签
git tag -a v$VERSION -m "版本 $VERSION"
git push origin master
git push origin v$VERSION

echo "发布完成！请在 GitHub 创建 Release。"
```

## 相关文件

- `build.sh` - 编译脚本
- `package.sh` - 打包脚本
- `RELEASE_NOTES.md` - 发布说明模板
- `LICENSE` - 项目许可证
- `README.md` - 项目说明

## 支持

如有问题，请在 GitHub Issues 中反馈。

---

**祝你发布顺利！**