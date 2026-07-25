# How to Actually Use Langfuse — A Practical Guide

This guide covers the full Langfuse workflow: what it's for, what each feature does, and how they connect. Written for this project (family-meal-planner) where Langfuse is newly set up.

---

## The Mental Model

Langfuse has four capabilities that build on each other:

```
Traces → understand what happened
Prompts → control what the AI does (no deploys needed)
Datasets + Experiments → prove a change is better before shipping
Evaluations → score outputs systematically
```

You can use any one of these independently, but they're most powerful when connected.

---

## 1. Traces — What's Actually Happening

Every AI interaction is logged as a **trace** — a tree of nested spans/generations/tool calls.

**What you see in the UI:**

- The waterfall timeline (each tool call, generation, span as a bar)
- Input/output at every step
- Latency per step — immediately shows you where time is actually spent
- Token usage and cost per generation
- Tags, metadata, user ID, session ID for filtering

**What we're already doing well:**

- `generateDraftMealPlan` is fully traced with all tool calls visible
- Tags like `feature:meal-planning`, `phase-2:initial-generation` make filtering easy
- The Langfuse prompt link is set up (`metadata: { langfusePrompt: { name, version } }`)

**What traces are good for:**

- Debugging unexpected AI behaviour by reading exact inputs/outputs
- Spotting failures (e.g. `getRecipeDetails` returning "not found")
- Understanding actual tool call patterns vs. what you expected
- Identifying which step is slow before optimising anything

**Where to look:**
`cloud.langfuse.com` → **Traces** → filter by tag `feature:meal-planning`

---

## 2. Prompt Management — The Main Event

This is where Langfuse really earns its place. **Prompts live in Langfuse, not in code.** You edit them in the UI, promote to production, and the running app picks up the change on the next request — no deploy required.

### How versions and labels work

Every prompt save creates a new **version** (immutable, numbered). **Labels** are pointers to versions:

| Label                   | Meaning                                                   |
| ----------------------- | --------------------------------------------------------- |
| `latest`                | Auto-updated to the newest version — use in dev           |
| `production`            | The version the live app fetches — you move this manually |
| Custom (e.g. `staging`) | Use for A/B tests or canary deploys                       |

The app fetches by label, not by version number:

```typescript
const prompt = await langfuse.prompt.get("meal-plan-generator", {
  label: "production", // always gets the promoted version
});
```

### The prompt iteration workflow

1. **Edit in the UI** — Langfuse has a full editor with variable highlighting (`{{variable}}` syntax)
2. **Test in the Playground** (see below) — run the new version against real inputs without deploying
3. **Run an Experiment** against a Dataset (see below) — compare v_new vs v_old scores side by side
4. **Promote** — move the `production` label to the new version
5. **Rollback** — if something goes wrong, move `production` back to the previous version. Instant.

### What lives in Langfuse prompts (for this project)

Per `docs/adr/009-langfuse-ai-architecture.md`:

- All prompt text with `{{variable}}` Mustache syntax
- Model config (temperature, max_tokens etc.) in `prompt.config`
- Tool usage instructions (when/how to call each tool)
- The `{{recipe_categories}}` table of contents variable (new in ADR 012)

**What stays in code:** tool Zod schemas + execute handlers (`lib/ai/tools/`), prompt fetching logic (`lib/ai/langfuse/`).

---

## 3. The Playground — Quick Iteration Without Code

The Playground lets you run a prompt version against a custom input and see the output immediately — no code, no deploy.

**Use it to:**

- Test a prompt edit before saving a new version
- Try "what if I added this instruction" quickly
- Reproduce a failing trace by pasting in the exact input from that trace
- Compare two prompt versions against the same input manually

**The key workflow for prompt tuning:**

1. Open a trace that showed bad behaviour (e.g. the AI read 11 recipes for 7 slots)
2. Click **"Open in Playground"** — it pre-populates with the exact inputs from that trace
3. Edit the system prompt directly in the Playground
4. Run it — see if the behaviour improves
5. If yes, save as a new version and run an Experiment to confirm at scale

---

## 4. Datasets — Your Test Suite for Prompt Changes

A **Dataset** is a collection of `{input, expected_output}` pairs. You run a prompt version against the whole dataset and get scored results — equivalent to a test suite but for AI behaviour.

### Building a dataset

Two approaches:

**a) From real traces** — in the Traces view, find a trace with good/bad output, click "Add to Dataset". The input is pre-populated from the trace. Add the expected output manually. This is the fastest way to build a golden set from production behaviour.

**b) Manually** — create items via the API or UI. Good for synthetic test cases covering edge cases you haven't seen in production yet.

### Running an Experiment

Once you have a dataset:

1. Go to **Prompt Management** → select your prompt → **Experiments**
2. Choose the dataset, choose two prompt versions to compare (e.g. v3 vs v4)
3. Langfuse runs each dataset item through each version and collects outputs
4. Scores appear side by side — you can see exactly which inputs regressed

**For this project, a useful dataset would include:**

- A "varied cuisine, 7 slots" input (like our test runs)
- A "family with allergies" input
- A "mostly packed lunches" input
- A "request for specific anchor meal" input

Each with an expected output capturing what "good" looks like (recipe pool IDs used, no hallucinated recipes, correct slot assignments).

---

## 5. Evaluations — Scoring Outputs Automatically

Evaluations attach scores to traces/generations. Three methods:

### a) LLM-as-a-Judge (automated)

Configure an evaluator in the Langfuse UI that uses an LLM to score outputs against criteria. Runs automatically on new traces.

Example criteria for meal planning:

- "Did the AI use `existing_recipe_id` for at least 50% of slots?" → 0/1
- "Does the output contain any recipe names not present in the recipe pool browse results?" → hallucination check
- "Are dietary restrictions respected?" → 0/1

### b) Human annotation queues

Route a sample of traces to an annotation queue. You (or a team member) review each trace and add a score + comment. Useful for catching things LLM-as-a-judge misses, and for building ground truth for the judge itself.

### c) Programmatic scores via API

Post scores from code after a generation completes. E.g. after `generateDraftMealPlan` runs, check whether `existing_recipe_id` is set on each slot and post a score.

```bash
curl -X POST https://cloud.langfuse.com/api/public/scores \
  -u "pk-lf-...":"sk-lf-..." \
  -H "Content-Type: application/json" \
  -d '{
    "traceId": "...",
    "name": "recipe_pool_usage_rate",
    "value": 0.85,
    "dataType": "NUMERIC",
    "comment": "6/7 slots used existing_recipe_id"
  }'
```

---

## The Full Loop — How It All Connects

```
Production trace shows problem
         ↓
Open trace in Langfuse → understand what happened
         ↓
Add that trace's input to a Dataset (as a test case)
         ↓
Edit prompt in Prompt Management UI
         ↓
Test in Playground with that exact input
         ↓
Run Experiment: new prompt version vs. old, on full Dataset
         ↓
LLM-as-a-Judge scores both versions automatically
         ↓
New version wins? → Promote `production` label → done, no deploy
         ↓
Monitor new traces for regressions
```

---

## What to Do Next (for this project)

### Immediate (now)

**1. Build a meal planning dataset**
Take the two traces from this morning's QA session and add them to a dataset in the UI. For each, manually write the expected output (what a good meal plan for that input looks like). This gives you a baseline to test prompt changes against.

**2. Tune the `meal-plan-generator` prompt**
The traces show the AI over-reads recipes (11 calls for 7 slots). Edit the prompt in Langfuse UI to add something like:

> "For each meal slot, identify the 1-2 most promising recipes from browse results, then call getRecipeDetails on those only. Do not read every candidate — be selective."

Run this in the Playground against this morning's trace inputs. If it reduces getRecipeDetails calls without degrading quality, save as a new version and experiment against the dataset.

**3. Set up a recipe pool usage rate score**
Post a programmatic score after each `generateDraftMealPlan` call: what % of slots have `existing_recipe_id` set (vs. AI-hallucinated recipe names). This is the core metric for whether ADR 012 is working.

### Soon

**4. LLM-as-a-Judge evaluator**
Configure an evaluator that checks: "Did this meal plan use recipes that actually exist in the pool?" — cross-referencing the browse tool outputs against the final meal plan.

**5. A/B test prompt versions**
Use the `prod-a` / `prod-b` label pattern to run two prompt versions in parallel in production, with automatic score comparison.

---

## Key URLs (this project)

- Project: `cloud.langfuse.com/project/cmk3n9i4o0016ad07c3shic27`
- Traces: `.../traces` → filter tag `feature:meal-planning`
- Prompts: `.../prompts` → `meal-plan-generator`
- Datasets: `.../datasets` (empty — create your first one)
- Experiments: `.../experiments`
