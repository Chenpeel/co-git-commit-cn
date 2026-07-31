---
name: git-commit-cn
description: Use when the user asks to commit changes, 提交代码, draft a Chinese Commit Message, commit staged changes, or enforce Chinese Conventional Commits in a Git repository.
---

# Git 中文规范提交

## 核心原则

只提交经过审查的暂存内容。先验证质量并展示准确草案，收到用户对该草案的
明确确认后，再执行非交互式 `git commit`。

用户最初提出“直接提交”“不用再问”或给出指定消息，都不能代替草案生成后的
确认。不合规的指定消息必须先纠正并说明原因。

## 强制流程

### 1. 收集仓库事实

先读取适用的 `AGENTS.md`、项目文档和近期提交约定，再运行：

```bash
git rev-parse --show-toplevel
git status --short --branch
git diff --name-only --diff-filter=U
git diff --cached --name-status
git diff --cached --stat
git diff --cached --check
git diff --name-status
git diff --stat
git log -5 --pretty=format:'%h %s'
```

按需读取暂存差异以理解行为变化。只列出未跟踪文件名；不要读取或暂存
`.env`、密钥、凭据、生成物等可疑内容。发现冲突、敏感文件或空仓库状态时
停止并报告。

将 `git diff --cached --name-only` 与 `git diff --name-only` 视为路径集合并
比较交集。交集非空表示同一文件同时存在暂存和未暂存修改；此时工作树检查
不能证明暂存版本正确，必须在质量门禁前停止，请用户调整暂存边界或提供隔离
快照。不要自动 stash、丢弃或覆盖用户修改。

### 2. 保证原子提交

以暂存区为提交边界。确认暂存内容只包含一个逻辑变化，并能用一个 type 和
subject 准确描述。

- 暂存区已有内容：不要加入未暂存文件。
- 暂存区为空：按逻辑变化提出精确文件分组，等待确认后才运行
  `git add -- <path>...`。
- 存在多组无关变化：建议拆分并逐组处理，每次都重新审查和确认。
- 禁止默认运行 `git add .`、`git add -A` 或等价全量暂存命令。

### 3. 执行质量门禁

从仓库指令、README、构建文件和 CI 配置中发现适用的格式检查、静态检查、
测试与构建命令。优先使用只检查模式；必须格式化时仅处理目标文件，并重新
审查产生的修改。

为每条质量检查命令设置最长 60 秒，包括格式检查、静态检查、测试和构建。
任何检查失败都要停止默认提交流程，报告命令和关键错误。只有用户明确要求
跳过或接受风险后才能继续，并在最终确认摘要中列出所有失败或未运行的检查。

“之前通过”“看起来没问题”和时间紧迫都不能替代当前验证。

### 4. 生成 Commit Message

Header 必须使用：

```text
<type>(<scope>): <subject>
```

scope 无合适值时省略括号。type 只能从下列值中选择：

- `feat`：新增业务功能或产品特性
- `fix`：修复测试或线上 Bug
- `docs`：仅修改文档
- `style`：不影响逻辑的格式修改
- `refactor`：既非功能也非修复的代码重构
- `perf`：提升性能或响应速度
- `test`：仅新增或修改测试
- `build`：修改构建系统或外部依赖
- `ci`：修改 CI/CD 配置或脚本
- `chore`：不修改源代码和测试的日常事务或工具变动
- `revert`：撤销已有提交

subject 使用简体中文和明确动作，优先以“新增”“修复”“优化”“更新”“移除”
等动词开头；也可使用能清楚表达动作的上下文短语。尽量控制在 50 个字符
以内，结尾不加标点。超过 50 个字符时必须向用户展示校验警告。

复杂修改才添加 Body，并与 Header 空一行。Body 说明修改动机以及与旧逻辑的
差异。Footer 仅用于 `BREAKING CHANGE:` 或关闭 Issue，并与前一部分空一行。

```text
fix(ik): 修复越界坐标导致的求解崩溃

增加工作空间边界保护，越界时保持上一帧姿态并记录警告。

Closes #102
```

### 5. 校验并请求确认

用本 Skill 的脚本校验完整消息。可传入消息文件，或分别传入各部分：

```bash
"${CODEX_HOME:-$HOME/.codex}/skills/git-commit-cn/scripts/validate_commit_message.sh" \
  --header 'fix(ik): 修复越界坐标导致的求解崩溃' \
  --body '增加工作空间边界保护，越界时保持上一帧姿态并记录警告。' \
  --footer 'Closes #102'
```

校验通过后分别运行 `git rev-parse HEAD` 和 `git write-tree`，记录当前 HEAD OID
与 index tree OID。它们是本次草案对应的仓库与暂存内容指纹。

向用户展示：

1. 本次暂存文件与原子性判断
2. 已通过、失败或跳过的检查
3. 完整 Commit Message 草案

然后等待明确的“确认”“可以提交”或等价回复。必须在草案展示之后获得确认。

### 6. 提交并回报

确认后重新运行 `git rev-parse HEAD` 和 `git write-tree`，与草案阶段记录的两个
OID 严格比较，同时重新运行 `git status --short` 和 `git diff --cached --check`。
任一 OID 变化都表示仓库基线或暂存内容发生变化，必须废弃原草案并回到审查
步骤。不要用文件名、统计行数或文件大小代替内容指纹。

使用安全的参数引用执行非交互式 `git commit`。Header、Body 和 Footer 分别
使用 `-m` 传入。不要使用 `--no-verify`、`--amend` 或交互式编辑器；不要
自动 push。Hook 失败时停止并报告，不要绕过。

提交成功后运行：

```bash
git show --stat --oneline --summary HEAD
git status --short
```

回报提交哈希、标题、文件统计、检查状态和剩余工作区修改。

## 红线与常见借口

- “用户说不用再问”：仍需对最终草案确认。
- “用户已经写好消息”：仍需纠正 type、中文 subject、长度和标点。
- “全量暂存最快”：可能混入无关修改或凭据，只能精确暂存。
- “测试刚才通过”：只能采用当前暂存内容对应的本次结果。
- “Hook 挡住提交”：修复原因，不得添加 `--no-verify`。
- “几个修改顺手一起交”：不能用一个 Header 准确描述时必须拆分。

出现上述情况时，停下并回到对应步骤，不得以效率或用户压力绕过规则。
