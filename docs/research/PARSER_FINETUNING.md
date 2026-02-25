# Fine-tuning the expense parser

Use this when you want the model’s **weights** to reflect your log (real inputs and correct outputs) instead of relying only on few-shot examples in the prompt.

## What you have

- **Log:** `tool/parser_runs.log` — successful runs have `INPUT:` and `RAW_JSON:`; failed runs have `ERROR:`.
- **System prompt:** `tool/parser_cli.dart` → `_buildSystemPrompt()`. The same instructions (schema, scenario, rules) should be used as the system message when building training examples.
- **Export script:** `tool/export_parser_training_data.dart` turns the log into a JSONL dataset.

## 1. Export training data

```bash
dart tool/export_parser_training_data.dart
```

- **Input:** `tool/parser_runs.log`
- **Output:** `tool/parser_training_data.jsonl`
- **Format:** One JSON object per line: `{"input": "<user message>", "output": "<single JSON object>"}`
- Only runs **without** `ERROR:` are included. Duplicate `input` values are deduped (last occurrence kept).

The more good runs you have in the log, the better. Aim for at least a few hundred; add hand-corrected rows to the log (same block format with `INPUT:` and `RAW_JSON:`) if you want to fix past mistakes.

## 2. Training format for the model

Each training example should look like a single turn of the expense-parser task:

- **System:** The full system prompt from `_buildSystemPrompt()` (same member list / current user handling can be simplified for training, e.g. fixed “Rishi, Prasi, Alex, Sam, Jordan” and current user “Rishi”).
- **User:** The `input` from the JSONL line.
- **Assistant:** The `output` from the JSONL line (only the JSON, no extra text).

So you need to combine:

1. `parser_training_data.jsonl` (input/output pairs)
2. A fixed system prompt (copy from `parser_cli.dart` or export it to e.g. `tool/parser_system_prompt.txt`)

into the format your fine-tuning framework expects (e.g. one message list per example).

## 3. Recommended stack

- **Model:** Llama 3.2 3B or Llama 3.1 8B (good balance of size vs quality). You can also try Llama 3.3 70B if you have the GPU memory; Groq uses 70B for the current API.
- **Framework:** [Unsloth](https://github.com/unslothai/unsloth) (fast, low memory, supports LoRA/QLoRA).
- **Hardware:** 1 GPU with ≥16GB VRAM for 8B (e.g. 3060 12GB can do 3B or 8B with QLoRA).

## 4. Steps to run training (Unsloth)

1. **Install Unsloth** (see [unslothai/unsloth](https://github.com/unslothai/unsloth)), create a Python env.
2. **Convert JSONL to Unsloth format.** Unsloth expects a dataset where each item has `messages`: `[{"role": "system", "content": "..."}, {"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]`. Write a small Python (or Dart) script that:
   - Reads `parser_training_data.jsonl`
   - Reads the system prompt (from a file or hardcoded)
   - Outputs a new JSONL or JSON where each example is the full `messages` list.
3. **Run Unsloth training** (e.g. their 4-bit QLoRA example). Point the dataset to your converted file. Use a short max length (e.g. 1024) since inputs and outputs are short.
4. **Save the adapter** (LoRA weights). Unsloth can save to Hugging Face or disk.
5. **Inference:** Merge adapter with base model and run locally (Ollama, vLLM, or Transformers), or use Unsloth’s inference helpers.

## 5. Using the fine-tuned model in Expenso

- **Option A (local):** Run the model locally (Ollama, vLLM, etc.) and change the app/CLI to call your local endpoint instead of Groq. No API key; data stays on device.
- **Option B (hosted):** If a provider supports “bring your own adapter” or fine-tuned Llama in the future, you could upload the adapter and keep using an API.

## 6. Maintenance

- **Re-export after more runs:** Run `dart tool/export_parser_training_data.dart` again and re-run training to incorporate new log data.
- **Curating the log:** For bad parses you fixed manually, add a block to `parser_runs.log` with the correct `INPUT:` and `RAW_JSON:` (and no `ERROR:`), then re-export so the next fine-tune sees the corrected pair.
