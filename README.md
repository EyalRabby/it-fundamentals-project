# it-fundamentals-project

Eyal Rabby, Lia Golding

https://github.com/EyalRabby/it-fundamentals-project

## 1. What we collect and why

Open AI models are sold by many providers at once, through marketplaces such as OpenRouter and Hugging Face. We record, every hour, the price and the quality of service of each provider for 10 open models on both marketplaces, plus each provider's own list price (models.dev) and the GPU rental price (InferCPI) once a day. The marketplaces show only the current state: availability over the last 30 minutes is overwritten constantly and prices have no public history, so this record exists only if we keep it. Details: `SOURCE.md`.

## 2. Schema

One row per sample time, source, model and provider offer. Column names, content and units: `SOURCE.md`, section 3.

## 3. How to run

From the project root:

```
bin/collect.sh      # one round -> raw/YYYY-mm-dd/HHMM.json.gz (UTC)
```

Hourly cron entry (to be set up in week 4):

```
5 * * * * cd /path/to/project && bin/collect.sh >> collect.log 2>&1
```

Requires `curl`, `jq` and `gzip`.

## 4. Findings

To be written from `data/findings.json` once `analyse.sh` exists.

## 5. What broke and how we handled it

**Manual samples named in local time (15-19 November 2026).** The four manual samples in `raw/2026-11-15` ... `raw/2026-11-19` are named by Israel time (UTC+2) instead of UTC, and each sample is split into four files (`HHMM_or.json`, `HHMM_hf.json`, `HHMM_modelsdev.json`, `HHMM_gpu.json`) instead of one file per collection. *How we saw it:* the day-4 file is named `1137` but its commit time is 11:40 +02:00. *Cause:* the files were saved by hand with the local clock. *Fix:* `raw/` is append-only, so we did not rename them; `bin/collect.sh` writes one file per round named in UTC, and `normalise.sh` will read only those files. *Why this fix:* renaming files in `raw/` is not allowed, and the manual samples were exploratory.

**Manual samples used different addresses.** The manual samples saved the OpenRouter model catalog and the Hugging Face trending list, not the per-provider addresses approved in our proposal, so they contain no availability data. `bin/collect.sh` collects the approved addresses.

## 6. What we would do differently

To be completed at the end of the semester.
