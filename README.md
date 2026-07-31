# co-git-commit-cn

面向 Codex 的中文 Git 提交 Skill。它会审查暂存内容、执行项目质量检查、
生成规范的中文 Commit Message，并在你确认后完成提交。

Skill 调用名为 `$git-commit-cn`。完整执行规则见
[SKILL.md](./SKILL.md)。

## 核心能力

- 根据实际差异选择 `feat`、`fix`、`docs` 等 11 种提交类型
- 生成包含可选 scope 的中文 Conventional Commit
- 只提交经过审查的暂存内容，不默认执行 `git add -A`
- 检查一次提交是否只包含一个独立逻辑变化
- 自动发现并运行项目格式检查、静态检查、测试和构建命令
- 在提交前校验 Header、Body、Footer、中文动作和结尾标点
- 使用 HEAD OID 与 index tree OID 防止确认后内容被替换
- 禁止自动 push、amend、跳过 Hook 或覆盖用户修改

## 环境要求

- 支持 Skills 的 Codex 环境
- Git
- Bash 4 或更高版本
- UTF-8 locale，用于准确识别中文字符与 Unicode 标点

## 安装

将仓库克隆到 Codex Skills 目录，并保持目标目录名为
`git-commit-cn`：

```bash
git clone git@github.com:Chenpeel/co-git-commit-cn.git \
  "${CODEX_HOME:-$HOME/.codex}/skills/git-commit-cn"
```

在新的 Codex 会话中即可使用 `$git-commit-cn`。

更新已有安装：

```bash
git -C "${CODEX_HOME:-$HOME/.codex}/skills/git-commit-cn" pull --ff-only
```

## 快速开始

在需要提交的 Git 仓库中向 Codex 发出请求：

```text
使用 $git-commit-cn 检查当前改动，生成规范的中文提交信息，
并在我确认后提交。
```

Skill 会依次执行：

1. 读取仓库规则、状态、差异和近期提交
2. 审查暂存边界与提交原子性
3. 运行最长 60 秒的质量检查
4. 生成并校验中文 Commit Message
5. 展示文件、检查结果和完整草案
6. 等待你明确确认
7. 重新核对 HEAD 与暂存快照后执行提交

如果暂存区为空，Skill 只会提出精确的文件分组建议。获得确认后才会运行
`git add -- PATH...`。

## Commit Message 规范

每条消息必须包含 Header，可按需补充 Body 和 Footer：

```text
<type>(<scope>): <subject>

<body>

<footer>
```

scope 为选填字段。subject 应使用简体中文和明确动作，尽量不超过 50 个
字符，结尾不加标点。

### Type

| Type | 使用场景 |
| --- | --- |
| `feat` | 新增业务功能或产品特性 |
| `fix` | 修复测试或线上 Bug |
| `docs` | 仅修改文档 |
| `style` | 不影响逻辑的格式修改 |
| `refactor` | 既非功能也非修复的代码重构 |
| `perf` | 提升性能或响应速度 |
| `test` | 仅新增或修改测试 |
| `build` | 修改构建系统或外部依赖 |
| `ci` | 修改 CI/CD 配置或脚本 |
| `chore` | 不修改源代码和测试的日常事务或工具变动 |
| `revert` | 撤销已有提交 |

### 示例

只使用 Header：

```text
feat(api): 新增用户注册接口
```

包含 Body 和 Footer：

```text
fix(ik): 修复越界坐标导致的求解崩溃

增加工作空间边界保护，越界时保持上一帧姿态并记录警告。

Closes #102
```

Footer 只支持：

- `BREAKING CHANGE: 变更说明`
- `Closes #102`
- `Fixes #102, #105`
- `Resolves #102`

## 校验 Commit Message

[validate_commit_message.sh](./scripts/validate_commit_message.sh) 是纯 Bash
校验器，可独立校验
提交信息，不会执行 `git commit`。

从仓库根目录校验各组成部分：

```bash
./scripts/validate_commit_message.sh \
  --header 'fix(auth): 修复空令牌导致的登录崩溃' \
  --body '增加空令牌边界保护并补充回归测试。' \
  --footer 'Closes #102, #105'
```

预期输出：

```text
[OK] Commit Message 校验通过
```

也可以校验 UTF-8 消息文件：

```bash
./scripts/validate_commit_message.sh commit-message.txt
```

不合规消息会返回退出码 `1`：

```bash
./scripts/validate_commit_message.sh \
  --header 'feat(auth): Added login.'
```

```text
[ERROR] subject 必须包含中文描述
[ERROR] subject 结尾不能使用标点符号
```

查看全部参数：

```bash
./scripts/validate_commit_message.sh --help
```

## 安全边界

- 已有暂存内容时，不加入未暂存文件
- 同一文件同时存在暂存和未暂存修改时，停止质量检查
- 不读取或暂存 `.env`、密钥、凭据和可疑生成物
- 检查失败时默认停止；只有你明确接受风险后才能继续
- 草案展示后的确认不可由“直接提交”或“无需再问”预先替代
- 确认后暂存快照发生任何变化时，废弃草案并重新审查
- 不自动执行 `git push`、`git commit --amend` 或 `--no-verify`

## 项目结构

```text
git-commit-cn/
├── README.md
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    └── validate_commit_message.sh
```

- `SKILL.md`：Codex 使用的完整提交工作流
- `agents/openai.yaml`：Skill 列表中的名称、描述和默认提示词
- `scripts/validate_commit_message.sh`：纯 Bash Commit Message 校验器

## 常见问题

### Codex 没有发现 Skill

确认仓库安装目录为：

```text
${CODEX_HOME:-$HOME/.codex}/skills/git-commit-cn
```

然后启动一个新的 Codex 会话，并使用 `$git-commit-cn` 调用。

### 暂存区为空

Skill 会按逻辑变化建议文件分组。你确认具体路径后，它才会执行精确暂存。

### 同一文件同时有暂存和未暂存修改

Skill 会停止，因为工作树检查无法证明暂存版本正确。请调整该文件的暂存边界，
或在隔离的工作区中完成提交。

### 测试或构建失败

Skill 默认不会提交。它会报告失败命令和关键错误；如需继续，必须明确接受
风险，并再次确认最终 Commit Message。

### 校验器提示需要 UTF-8 locale

先检查当前字符集：

```bash
locale charmap
```

输出应为 `UTF-8`。请切换到系统已经安装的 UTF-8 locale 后再运行校验器。

## 贡献

欢迎通过 Issue 或 Pull Request 改进工作流、类型判断和校验规则。修改时请
保持 [SKILL.md](./SKILL.md) 与校验脚本行为一致，并为新增边界提供可复现示例。
