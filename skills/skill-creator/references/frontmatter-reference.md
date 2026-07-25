# Skill Frontmatter Reference

Complete guide to optional frontmatter fields in SKILL.md files for Claude Code.

## Overview

Skills support both the [Agent Skills open standard](https://agentskills.io) and Claude Code-specific extensions. This reference covers all available fields.

## Required Fields

### `name`

**Required.** The skill name. Must match the parent directory name.

**Constraints:**
- 1-64 characters
- Lowercase letters, numbers, and hyphens only
- Must not start or end with hyphen
- No consecutive hyphens

**Example:**
```yaml
name: test-fixer
```

### `description`

**Required.** What the skill does and when to use it. This is the **primary triggering mechanism** - Claude uses this to decide when to load the skill automatically.

**Best practices:**
- Include what the skill does AND when to use it
- Add specific trigger keywords/phrases
- Include all "when to use" information here (not in the body - body only loads after trigger)

**Example:**
```yaml
description: Diagnose and fix test failures across any framework (Playwright, Vitest, Jest, Testing Library, etc.). Use when tests fail, are flaky, throw errors, or behave unpredictably. Auto-triggers on keywords like "test failing", "test broken", "flaky test", "intermittent failure".
```

## Optional Fields - Invocation Control

### `disable-model-invocation`

**Optional.** Set to `true` to prevent Claude from automatically loading this skill. You can still invoke it manually with `/skill-name`.

**When to use:**
- Skills with side effects (deploy, commit, send-message)
- Workflows where timing matters (you want control over when it runs)
- Actions that shouldn't be automated

**Default:** `false`

**Example:**
```yaml
name: deploy
description: Deploy the application to production
disable-model-invocation: true
```

With this set, Claude cannot invoke the skill - only you can trigger it with `/deploy`.

### `user-invocable`

**Optional.** Set to `false` to hide the skill from the `/` menu. Claude can still load it automatically.

**When to use:**
- Background knowledge that isn't actionable as a command
- Context that should be available but not directly invokable
- Reference material that informs other work

**Default:** `true`

**Example:**
```yaml
name: legacy-system-context
description: Explains how the legacy billing system works
user-invocable: false
```

Users won't see `/legacy-system-context` in menus, but Claude can load it when relevant.

### Invocation Matrix

| Frontmatter | You can invoke | Claude can invoke | When loaded |
|-------------|----------------|-------------------|-------------|
| (default) | Yes | Yes | Description always in context, full skill when invoked |
| `disable-model-invocation: true` | Yes | No | Description NOT in context, loads when you invoke |
| `user-invocable: false` | No | Yes | Description always in context, loads when Claude invokes |

## Optional Fields - Execution Control

### `context`

**Optional.** Set to `"fork"` to run the skill in an isolated subagent context.

**When to use:**
- The entire skill is a single isolated task
- You want clean separation from main conversation history
- The skill contains explicit instructions (not just guidelines)

**Important:** The skill content becomes the prompt for the subagent. Don't use `context: fork` for skills that just provide guidelines without actionable instructions.

**Example:**
```yaml
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
model: opus
```

When invoked, this runs in a fresh context with no conversation history.

### `agent`

**Optional.** When `context: fork` is set, specifies which subagent type to use.

**Available agents:**
- `"Explore"` - Read-only codebase exploration (Glob, Grep, Read tools)
- `"Plan"` - Planning and design (read tools + planning-focused prompt)
- `"general-purpose"` - Full tool access (default if omitted)
- Custom agent names from `.claude/agents/`

**Example:**
```yaml
context: fork
agent: Explore  # Read-only research mode
```

### `model`

**Optional.** Specifies which model to use for this skill.

**Available models:**
- `"opus"` - Deepest reasoning, highest cost (use for complex analysis)
- `"sonnet"` - Balanced performance and cost (default)
- `"haiku"` - Fastest, most cost-effective (use for simple, straightforward tasks)

**When to specify:**
- `opus`: Complex analysis, bug detection, architectural decisions
- `haiku`: Quick formatting, simple transformations, template filling

**Example:**
```yaml
context: fork
agent: Explore
model: opus  # Use Opus for deep analysis
```

### `allowed-tools`

**Optional.** Space-delimited list of tools Claude can use without asking permission when this skill is active.

**When to use:**
- Create read-only modes
- Grant specific tool access for the skill's purpose
- Reduce permission prompts for known-safe operations

**Example:**
```yaml
name: safe-reader
description: Read files without making changes
allowed-tools: Read Grep Glob
```

While this skill is active, Claude can use Read, Grep, and Glob without permission prompts.

## Optional Fields - Other

### `argument-hint`

**Optional.** Hint shown during autocomplete to indicate expected arguments.

**Example:**
```yaml
name: fix-issue
description: Fix a GitHub issue
argument-hint: [issue-number]
```

When typing `/fix-issue`, the user sees `[issue-number]` as a hint.

### `hooks`

**Optional.** Hooks scoped to this skill's lifecycle. See [Claude Code hooks documentation](https://code.claude.com/docs/hooks) for configuration format.

## Pattern: context: fork vs Task Tool

Two ways to delegate to subagents:

### Use `context: fork` when:

- The **entire skill** is one isolated task
- No other steps need to happen in the main context
- You want complete separation from conversation history

**Example:**
```yaml
name: codebase-explorer
description: Generate a comprehensive codebase map
context: fork
agent: Explore
model: sonnet
---

Analyze the codebase and create a structured report:
1. Find all major modules
2. Map dependencies
3. Identify architecture patterns
4. Document findings
```

### Use Task tool pattern when:

- The skill has **multiple steps** and only some need subagents
- You want to stay in the main context but delegate specific analysis
- The skill orchestrates multiple different operations

**Example:**
```yaml
name: test-fixer
description: Diagnose and fix test failures
---

## Step 1: Fast Triage
[inline analysis in main context]

## Step 2: Deep Root Cause Analysis

Use the **Task tool** to spawn an Explore agent:

Task tool with:
- subagent_type: "Explore"
- model: "opus"
- description: "Analyze if test caught real bug"
- prompt: [specific analysis prompt]

## Step 3: Apply Fix
[back in main context with agent's findings]
```

## String Substitutions

Skills support dynamic string substitution:

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking |
| `$ARGUMENTS[N]` or `$N` | Specific argument by index (0-based) |
| `${CLAUDE_SESSION_ID}` | Current session ID |

**Example:**
```yaml
name: fix-issue
description: Fix a GitHub issue
---

Fix GitHub issue $ARGUMENTS by:
1. Reading the issue description
2. Implementing the fix
3. Writing tests
```

When you run `/fix-issue 123`, Claude receives "Fix GitHub issue 123 by:..."

## Dynamic Context Injection

Use `!`command`` to run shell commands before skill content is sent to Claude:

```yaml
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
---

## Pull request context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

## Your task
Summarize this pull request...
```

The commands execute first, their output replaces the placeholders, then Claude receives the fully-rendered prompt.

## Complete Example

Putting it all together:

```yaml
---
name: bug-analyzer
description: Deep analysis of bug reports using codebase exploration and sequential thinking. Use when investigating complex bugs, mysterious failures, or when root cause is unclear.
context: fork
agent: Explore
model: opus
allowed-tools: Read Grep Glob Bash(git *)
---

# Bug Analysis

Analyze the bug report and determine root cause:

**Bug report:**
$ARGUMENTS

**Recent changes affecting this area:**
!`git log --oneline -10 -- $1`

**Analysis steps:**

1. **Understand the symptom**
   - What is the reported behavior?
   - What should happen instead?

2. **Find relevant code**
   - Use Grep to find related functions
   - Use Glob to identify affected files
   - Read implementation code

3. **Trace execution path**
   - Map the code flow
   - Identify where behavior diverges

4. **Determine root cause**
   - Is this a logic bug?
   - A missing edge case?
   - An integration issue?

5. **Recommend fix**
   - What code needs to change?
   - Are there similar bugs elsewhere?
   - What tests should we add?

Use Sequential Thinking to work through this systematically.
```

This skill:
- Runs in isolated context with Explore agent and Opus model
- Has read-only access + git commands
- Uses `$ARGUMENTS` for bug report
- Injects recent git history dynamically
- Provides structured analysis framework

## References

- [Agent Skills Specification](https://agentskills.io)
- [Claude Code Skills Documentation](https://code.claude.com/docs/skills)
- [Claude Code Subagents Documentation](https://code.claude.com/docs/sub-agents)
