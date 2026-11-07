# SOURCE.md - Data Source Proposals

Fundamentals of Information Technology 2026-2027, Exercise 1, question 9(b).
Pair: Eyal Rabby, Lia Golding.

## Ranking

1. **Idea 1 - AI model providers across marketplaces** (preferred)
2. Idea 2 - Ben Gurion airport delays vs. local weather

---

## Idea 1: Comparing Pricing and Availability of AI Model Providers Across Marketplaces

Since open-source artificial intelligence models are hosted and served by numerous companies and providers, different vendors offer access to the exact same model at varying price points and reliability levels. We propose collecting data from two marketplace platforms (OpenRouter and Hugging Face) that present real-time input/output pricing and live availability for the providers of these models. We will track about 10 popular open models.

### Research Question

Is the cheapest provider for a given AI model also the least reliable (lower availability or more failures)? Is there a price difference for the exact same provider across the two marketplaces, and at which hours do availability drops happen?

### Data Sources

* **Source 1: Provider pricing and live availability from OpenRouter (one request per selected model; the model name is part of the URL):**

  <https://openrouter.ai/api/v1/models/openai/gpt-oss-120b/endpoints>

  Content: JSON, one object per provider endpoint. Fields we use: `provider_name`, `quantization` (for example `fp4`, `bf16`), `pricing.prompt` and `pricing.completion` (USD per token), `context_length`, `status`, `uptime_last_30m` (percent of successful requests in the last 30 minutes).

* **Source 2: Model and provider directory from Hugging Face (one request returns all models):**

  <https://router.huggingface.co/v1/models>

  Content: JSON list of models. For each model, a `providers` list with `provider`, `status` (for example `live`), `pricing.input` and `pricing.output` (USD per million tokens), `context_length`, `first_token_latency_ms` and `throughput` (tokens per second).

### Update Frequency

`uptime_last_30m` is recalculated continuously over a rolling 30-minute window. Prices change only when a provider changes them, and providers are added or removed over time. We will sample once per hour.

### Key or Password

None. Both sources are public APIs that need no API key, password or account.

### Why Does the Data Get Lost?

The 30-minute availability percentage is calculated over a rolling window and is continuously overwritten. Provider prices on both marketplaces change without a public historical archive. Without continuous collection, this history is permanently lost.

### Data Size and Frequency

Measured on 7 November 2026: the OpenRouter response for `gpt-oss-120b` (26 endpoints) is 26,867 bytes, or 2,179 bytes compressed with gzip. The full Hugging Face list is 76,938 bytes, or 7,676 bytes compressed. `gpt-oss-120b` is one of the models with the most providers, so 10 models should take at most about 270 KB from OpenRouter, plus 77 KB from Hugging Face: up to about 350 KB per hourly round. Hourly sampling for about 10 weeks is 1,680 rounds, which could reach about 580 MB uncompressed, over the 500 MB limit. We will therefore store each raw file compressed with gzip: at most about 30 KB per round, under 50 MB for the semester. `normalise.sh` will read the compressed files.

### Sample Data Retrieved

Source 1, OpenRouter, the first two endpoints of `gpt-oss-120b`, with the fields we use (retrieved 2026-11-07 17:18 UTC):

```
{"provider_name":"PrimeIntellect","quantization":"fp4","pricing":{"prompt":"0.00000002","completion":"0.000000074"},"context_length":131072,"status":0,"uptime_last_30m":100}
{"provider_name":"Near AI","quantization":"fp4","pricing":{"prompt":"0.00000003","completion":"0.00000015"},"context_length":131072,"status":0,"uptime_last_30m":100}
```

Command: `curl -s "https://openrouter.ai/api/v1/models/openai/gpt-oss-120b/endpoints" | jq -c '.data.endpoints[:2][] | {provider_name, quantization, pricing: {prompt: .pricing.prompt, completion: .pricing.completion}, context_length, status, uptime_last_30m}'`

Source 2, Hugging Face, the first two providers of the same model (retrieved 2026-11-07 17:19 UTC):

```
{"provider":"groq","status":"live","context_length":131072,"pricing":{"input":0.15,"output":0.75},"is_free":false,"supports_tools":true,"supports_structured_output":false,"first_token_latency_ms":270.8,"throughput":430.711969029627,"is_model_author":false}
{"provider":"novita","status":"live","context_length":131072,"pricing":{"input":0.05,"output":0.25},"is_free":false,"supports_tools":true,"supports_structured_output":true,"first_token_latency_ms":490,"throughput":167.35061561806134,"is_model_author":false}
```

Command: `curl -s "https://router.huggingface.co/v1/models" | jq -c '.data[] | select(.id == "openai/gpt-oss-120b") | .providers[:2][]'`

What the same retrieval showed: OpenRouter listed 26 endpoints from 22 providers for `gpt-oss-120b`, with input prices from USD 0.02 to USD 0.35 per million tokens. Google's endpoint had 3% availability over the last 30 minutes and Amazon Bedrock's 81%, while most others had 100%. Groq's output price was USD 0.60 per million tokens on OpenRouter (`"completion":"0.0000006"` per token) and USD 0.75 on Hugging Face.

---

## Idea 2: Ben Gurion Airport Delays vs. Local Weather

We propose collecting flight delay data from Ben Gurion Airport (TLV) and cross-referencing it with local weather conditions to determine whether weather significantly impacts flight delays, or if the correlation between the two is weak.

### Research Question

Do departure and arrival delays at Ben Gurion Airport depend on weather conditions (wind speed, temperature, or precipitation), and at which hours? How long before departure does the estimated time start to differ from the scheduled time?

### Data Sources

* **Ben Gurion flight board from data.gov.il (scheduled time `CHSTOL`, updated time `CHPTOL`, airline, destination, status):**

  <https://data.gov.il/api/3/action/datastore_search?resource_id=e83f763b-b7d7-479e-b172-ae981ddc6de5&limit=5000>

  (Without `limit`, the API returns only the first 100 records.)

* **Current weather around TLV airport from Open-Meteo:**

  <https://api.open-meteo.com/v1/forecast?latitude=32.018&longitude=34.888&current=temperature_2m,wind_speed_10m,precipitation>

### Update Frequency

The flight board is refreshed repeatedly until a flight leaves, and each refresh overwrites the previous estimate (the exact refresh interval will be measured in the first week). The weather `current` values come from 15-minute model data. We will sample both every 2 hours.

### Key or Password

None. Open-Meteo is free for non-commercial use.

### Why Does the Data Get Lost?

The live flight board only reflects the current state of active flights and overwrites past entries upon completion. The history we collect will be the only existing record of these transient delay updates.

### Data Size and Frequency

A full query of the flight board returned 689,293 bytes (1,888 records). At 12 pulls per day for 10 weeks this would be about 580 MB, over the 500 MB limit, so we will request only the 7 fields we use (about 260 KB per pull), about 220 MB for the semester. The weather response is 412 bytes.

### Sample Data Retrieved

Flight board, first record (5 November 2026, 21:17 UTC; Hebrew-language fields omitted):

```
{"_id": 1, "CHOPER": "AF", "CHFLTN": "8425", "CHOPERD": "AIR FRANCE", "CHSTOL": "2026-11-04T23:55:00", "CHPTOL": "2026-11-04T23:16:00", "CHAORD": "A", "CHLOC1": "AMS", "CHLOC1D": "AMSTERDAM", "CHLOC1T": "AMSTERDAM", "CHLOCCT": "NETHERLANDS", "CHTERM": 3, "CHCINT": "", "CHCKZN": "", "CHRMINE": "LANDED"}
```

Weather (same time):

```
{"latitude":31.983053,"longitude":34.856426,"generationtime_ms":0.08320808410644531,"utc_offset_seconds":0,"timezone":"GMT","timezone_abbreviation":"GMT","elevation":35.0,"current_units":{"time":"iso8601","interval":"seconds","temperature_2m":"°C","wind_speed_10m":"km/h","precipitation":"mm"},"current":{"time":"2026-11-05T21:15","interval":900,"temperature_2m":19.2,"wind_speed_10m":2.2,"precipitation":0.00}}
```
