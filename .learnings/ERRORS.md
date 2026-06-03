# Errors

Command failures and integration errors.

---

## [ERR-20260603-001] powershell-syntax

**Logged**: 2026-06-03T09:30:00+08:00
**Priority**: medium
**Status**: pending
**Area**: infra

### Summary
PowerShell 中 `&&` 和 `if not exist` 语法不兼容

### Error
```
The token '&&' is not a valid statement separator in this version.
Missing '(' after 'if' in if statement.
```

### Context
- 在 PowerShell 中执行 `git add ... && git commit ...` 失败
- 在 PowerShell 中执行 `if not exist ".learnings" mkdir ".learnings"` 失败
- `&&` 是 bash/cmd 语法，PowerShell 需用 `;`
- `if not exist` 是 cmd 语法，PowerShell 需用 `cmd /c "if not exist ..."` 或 PowerShell 自身的 `Test-Path`

### Suggested Fix
- PowerShell 中多个命令用 `;` 分隔（不保证前一个成功才执行下一个）
- 需要条件执行时用 `cmd /c "command1 && command2"`
- 目录存在性检查用 `cmd /c "if not exist dir mkdir dir"` 或 PowerShell 的 `if (-not (Test-Path ...))`

### Metadata
- Reproducible: yes
- Related Files: N/A

---

## [ERR-20260603-002] git-path-case

**Logged**: 2026-06-03T09:30:00+08:00
**Priority**: low
**Status**: pending
**Area**: infra

### Summary
Git on Windows 对路径大小写敏感 —— scenes/ui/ vs scenes/UI/

### Error
`git add scenes/ui/main_menu.gd` 后文件未暂存，实际路径是 `scenes/UI/main_menu.gd`

### Context
- git status 显示 `scenes/UI/main_menu.gd`
- 但代码中使用的是小写 `scenes/ui/` 路径
- Windows 文件系统大小写不敏感，但 Git 索引可能保留原始大小写
- 需要用 `git status` 确认实际路径后再操作

### Suggested Fix
始终用 `git status` 查看准确路径后再 `git add`，不要凭代码中的 import 路径猜测。

### Metadata
- Reproducible: yes
- Related Files: N/A

---
