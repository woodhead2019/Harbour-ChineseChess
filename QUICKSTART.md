# 快速开始指南

## 发布流程概览

### 1. 编译
```bash
# 编译所有版本
./build.sh all
```

### 2. 打包
```bash
# 打包所有版本
./package.sh all
```

### 3. 发布
```bash
# 提交代码
git add .
git commit -m "发布版本 1.0.1"

# 创建标签
git tag -a v1.0.1 -m "版本 1.0.1"
git push origin v1.0.1
```

### 4. 在 GitHub 创建 Release
- 访问 `https://github.com/你的用户名/cchess/releases`
- 创建新 Release
- 上传打包文件
- 使用 `RELEASE_NOTES.md` 作为发布说明

## 发布文件

### Linux 版本
- **文件**：`release/cchess-1.0.1-linux-x86_64.tar.gz`
- **大小**：约 2MB
- **包含**：可执行文件、资源、文档
- **不包含**：AI 引擎文件（需用户自行下载）

### Windows 版本
- **文件**：`release/cchess-1.0.1-windows-x86_64.zip`
- **大小**：约 2MB
- **包含**：可执行文件、资源、文档
- **不包含**：AI 引擎文件（需用户自行下载）

### 源代码
- **文件**：`release/cchess-1.0.1-source.tar.gz`
- **包含**：所有源代码和编译脚本

## 快速命令

```bash
# 查看打包帮助
./package.sh help

# 只打包 Linux
./package.sh linux

# 只打包 Windows
./package.sh windows

# 打包所有
./package.sh all

# 清理发布目录
./package.sh clean
```

## 许可证

- **主项目**：Public Domain (CC0 1.0 Universal)
- **ElephantEye 引擎**：LGPL v2.1（含重要例外）
- **完全兼容**：无任何许可证冲突

## 详细文档

- `GITHUB_RELEASE_GUIDE.md` - 完整的 GitHub 发布指南
- `RELEASE_NOTES.md` - 发布说明模板
- `README.md` - 项目说明
- `LICENSE` - 项目许可证

## 测试发布包

### Linux
```bash
cd release/cchess-1.0.1-linux-x86_64
./xq
```

### Windows
```bash
cd cchess-1.0.1-windows-x86_64
xq.exe
```

## 注意事项

1. 确保 `xq` 和 `xq.exe` 已编译
2. 确保 `engines/` 目录包含引擎文件
3. 确保 `skins/` 和 `sounds/` 目录包含资源文件
4. 确保 `LICENSE` 和 `README.md` 已更新

## 问题排查

### 找不到可执行文件
```bash
# 重新编译
./build.sh all
```

### 引擎文件缺失
```bash
# 检查 engines 目录
ls -la engines/eleeye/
ls -la engines/pikafish/
```

### 打包失败
```bash
# 清理后重新打包
./package.sh clean
./package.sh all
```

## 下一步

1. 测试所有打包文件
2. 更新 `RELEASE_NOTES.md` 中的版本信息
3. 在 GitHub 创建 Release
4. 通知用户

---

**祝你发布成功！**