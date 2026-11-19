# SOURCE.md - Data Source and Schema

Fundamentals of Information Technology 2026-2027.
Pair: Eyal Rabby, Lia Golding.

**Project question.** The same open AI model is sold by many providers through two marketplaces, OpenRouter and Hugging Face. Is the cheapest provider also the least reliable? Does the same provider charge different prices on the two marketplaces, and how do those prices compare with the provider's own list price? At which hours does availability drop?

**How we addressed the staff's comments on the proposal.**

* *Does the data change?* Two snapshots taken about 2 minutes apart on 19 November 2026 (11:34 and 11:37 UTC) already differed: 8 of 279 OpenRouter availability values, 2 prices and 2 status codes changed. Across our four daily manual samples (15-19 November), 18, 14 and 23 model prices changed in the OpenRouter catalog between consecutive samples. One provider (PrimeIntellect) raised its input price for `openai/gpt-oss-120b` from USD 0.02 to USD 0.35 per million tokens between 7 and 19 November.
* *Units:* OpenRouter prices are USD per single token; Hugging Face and models.dev prices are USD per million tokens. All prices in `dataset.csv` are converted to USD per million tokens (see the translation table).
* *Enrichment ("why"):* we added two daily sources. models.dev gives each provider's own list price, so we can see whether a marketplace charges more than the provider itself. InferCPI gives the spot rental price of an H100 GPU, as a signal of global demand for compute.

---

## 1. The sources

| Name | Address | Format | Key or user name | Licence | Sampling frequency |
|---|---|---|---|---|---|
| OpenRouter, providers of one model | `https://openrouter.ai/api/v1/models/<model id>/endpoints` (one request per tracked model) | JSON | No | No open-data licence; OpenRouter Terms of Service. Documented public API; `robots.txt` allows `/api/`. | Every hour |
| Hugging Face router, all models and providers | `https://router.huggingface.co/v1/models` | JSON | No | No open-data licence; Hugging Face Terms of Service. `robots.txt` allows all. | Every hour |
| models.dev, each provider's own list price | `https://models.dev/api.json` | JSON | No | Open-source project, MIT licence | Once a day |
| InferCPI, AI and GPU price indices | `https://infercpi.com/v1/latest.json` | JSON | No | Index values CC BY 4.0, credit "InferCPI, infercpi.com" | Once a day (the file itself updates daily) |

We track 10 open models that both marketplaces sell, chosen on 19 November 2026 as the ones with the most providers on Hugging Face: `deepseek/deepseek-v4.1-flash-1017`, `z-ai/glm-5.3`, `z-ai/glm-5.3-flash`, `openai/gpt-oss-120b`, `qwen/qwen3.8-27b`, `moonshotai/kimi-k3.1-pro`, `moonshotai/kimi-k3`, `google/gemma-4-26b-a4b-it`, `openai/gpt-oss-20b`, `meta-llama/llama-3.3-70b-instruct`. The list is in `config/models.txt`.

## 2. What we collect

Every hour, `bin/collect.sh` downloads, for each of the 10 models, the list of providers that sell it on OpenRouter (price, compression level, status and the share of successful requests in the last 30 minutes and last day), and the Hugging Face list of all models with their providers (price, status, time to first token and speed). Once a day it also downloads models.dev (every provider's own list price) and InferCPI (GPU rental prices). Each hourly round is saved as one compressed file, `raw/YYYY-mm-dd/HHMM.json.gz`, in UTC. A source that fails is saved as `null` and named in the file's `errors` list; we never fill a gap with guessed values.

## 3. The schema of `dataset.csv`

One row per sample time, source, model and provider offer. A provider can have more than one offer for the same model (for example two compression levels), told apart by `variant`.

| Column | Content | Unit / type |
|---|---|---|
| `sample_utc` | Time of the round the row came from | ISO 8601, UTC |
| `source` | `openrouter`, `huggingface` or `modelsdev` | text |
| `model` | The model, in OpenRouter's naming | text, lower case |
| `provider` | The company serving the model, in one common spelling for all sources | text, lower case, letters and digits only |
| `variant` | OpenRouter's name for this specific offer (empty for the other sources) | text |
| `quantization` | Compression level of the model at this provider (`fp4`, `fp8`, `bf16`, `unknown`; OpenRouter only) | text |
| `input_usd_per_m` | Price of input (the text we send) | USD per 1,000,000 tokens |
| `output_usd_per_m` | Price of output (the text the model writes) | USD per 1,000,000 tokens |
| `cache_read_usd_per_m` | Price of input the provider already has cached | USD per 1,000,000 tokens |
| `context_length` | Longest request the offer accepts | tokens |
| `status` | The source's own status code (OpenRouter: `0` normal, negative values degraded; Hugging Face: `live` / `staging`) | text |
| `uptime_30m_pct` | Share of successful requests in the last 30 minutes (OpenRouter only) | percent, 0-100 |
| `uptime_1d_pct` | Same, over the last day (OpenRouter only) | percent, 0-100 |
| `latency_ms` | Time until the first token arrives (Hugging Face only) | milliseconds |
| `throughput_tps` | Generation speed (Hugging Face only) | tokens per second |
| `gpu_h100_spot_usd_hr` | Latest InferCPI median spot price of an H100 SXM GPU at sample time | USD per GPU-hour |

A missing value is left empty; it is never estimated.

## 4. Why these columns, and what we leave out

We keep what the research question needs: the price on each side (input, output and cache price), the quality of service (status, uptime, latency, speed), the keys that let us match the same offer across sources (`model`, `provider`, `variant`) and one compute-demand signal (GPU spot price). `context_length` and `quantization` stay because two offers with different limits or compression are not the same product, so a fair price comparison has to account for them.

We leave out fields that are fixed or irrelevant to price and reliability: model descriptions, lists of supported request parameters, supported voices and image features, tool-calling flags, `max_completion_tokens`, release dates, and all InferCPI series other than the H100 spot price. OpenRouter's `latency_last_30m` and `throughput_last_30m` are empty (`null`) in public responses, so we take latency and speed from Hugging Face only. The raw files keep everything, so a dropped field can be added later by changing `normalise.sh`.

## 5. Translation from source fields to schema columns

| Column | OpenRouter (`data.endpoints[]`) | Hugging Face (`data[].providers[]`) | models.dev (`<provider>.models.<id>`) |
|---|---|---|---|
| `model` | the requested model id | `data[].id`, lower case, mapped to OpenRouter's id | `canonical_model_id`, mapped to OpenRouter's id |
| `provider` | first part of `tag` (e.g. `near-ai/fp4` → `nearai`) | `provider` | the top-level provider key |
| `variant` | `tag` | - | - |
| `quantization` | `quantization` | - | - |
| `input_usd_per_m` | `pricing.prompt` × 1,000,000 | `pricing.input` | `cost.input` |
| `output_usd_per_m` | `pricing.completion` × 1,000,000 | `pricing.output` | `cost.output` |
| `cache_read_usd_per_m` | `pricing.input_cache_read` × 1,000,000 | - | `cost.cache_read` |
| `context_length` | `context_length` | `context_length` | `limit.context` |
| `status` | `status` | `status` | - |
| `uptime_30m_pct` | `uptime_last_30m` | - | - |
| `uptime_1d_pct` | `uptime_last_1d` | - | - |
| `latency_ms` | - | `first_token_latency_ms` | - |
| `throughput_tps` | - | `throughput` | - |
| `gpu_h100_spot_usd_hr` | from InferCPI: `latest["gpu_spot/h100_sxm_median_usd_hr"].value` | (same) | (same) |
| `sample_utc` | the round file's `collected_utc` | (same) | (same) |

Spelling differences that need a mapping:

* Providers: all names are lower-cased and stripped of spaces and hyphens (`Near AI`, `near-ai` → `nearai`). A short alias list covers the rest, for example `fireworks-ai` → `fireworks`, `google-vertex` → `google`, `mancer` → `mancer2`.
* Models: models.dev names some model families differently from OpenRouter, for example `zhipuai/glm-5.3` → `z-ai/glm-5.3`, `alibaba/qwen3.8-27b` → `qwen/qwen3.8-27b`, `meta/llama-3.3-70b-instruct` → `meta-llama/llama-3.3-70b-instruct`.

## 6. Expected size after one semester

Measured on 19 November 2026 for the 10 tracked models:

| Item | Measured size per round or day (gzip) | 10 weeks |
|---|---|---|
| Hourly round: OpenRouter (10 requests) + Hugging Face | 22,027 B + 19,406 B = about 41 KB | 1,680 rounds, about 70 MB |
| Daily: models.dev + InferCPI | 700,928 B + 7,371 B = about 708 KB | 70 days, about 50 MB |
| Manual samples of 15-19 November (uncompressed, already in `raw/`) | - | 31.9 MB |
| **Total `raw/`** | | **about 150 MB** |

`dataset.csv`: each hourly round gives about 490 rows (279 OpenRouter offers and 211 Hugging Face offers today), and each day adds about 700 models.dev rows. That is about 870,000 rows over 10 weeks. At about 115 bytes per row this is about **100 MB**.

Together, about 250 MB, under the 500 MB limit. Both marketplaces are growing (the Hugging Face list was 77 KB on 7 November and 227 KB on 19 November uncompressed), so we will check the real size every week and reduce the number of tracked models if needed.

## 7. The manual samples of 15-19 November

Four samples, one per day, in `raw/2026-11-15` to `raw/2026-11-19`. Each sample is four files: the OpenRouter model catalog (`_or`), the Hugging Face trending list (`_hf`), models.dev (`_modelsdev`) and InferCPI (`_gpu`). They were taken before we settled on the per-provider OpenRouter and Hugging Face addresses above, so they do not contain availability data, and their file names use Israel time (UTC+2) rather than UTC (see README, "What broke"). `raw/` is append-only, so we keep them as they are; `normalise.sh` reads only the hourly `HHMM.json.gz` files. All the numbers we quote about these samples come from `tools/check_samples.sh`.

## Limits

* Availability is measured by OpenRouter from its own traffic; Hugging Face reports latency and speed instead. Reliability is therefore measured differently on each side, and only prices can be compared directly.
* OpenRouter's terms of service prohibit scripts that scrape or copy service information. We use only its documented public API endpoints at one request per model per hour.
* Two offers of the "same" model can differ in compression (`fp4` vs `bf16`), so price comparisons are made within the same `quantization` where possible.
