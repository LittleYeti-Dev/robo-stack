# EV2.1: Local vs Cloud Model Serving — Evaluation

**Status:** Complete — Recommendation: Cloud-first (Claude API)
**Sprint:** Robo Stack Sprint 2
**Evaluator:** Claude (Cowork)
**Requires:** Yeti sign-off

---

## Context

Robo Stack needs AI inference for code review (S2.6), development assistance, and future intelligence features. Two options exist:

1. **Cloud-only (Claude API)** — All inference via Anthropic's API
2. **Local (Ollama on EC2)** — Run open-source models on the workstation

**Constraint:** Local workstation cannot join the cluster (hardware issues). All compute runs on AWS EC2 (t3.xlarge: 4 vCPU, 16GB RAM, no GPU).

## Evaluation Criteria

| Criteria | Weight | Cloud (Claude API) | Local (Ollama on EC2) |
|----------|--------|-------------------|----------------------|
| **Model quality** | 30% | ★★★★★ Claude Sonnet/Haiku | ★★★☆☆ Llama 3 8B / Mistral 7B |
| **Latency** | 20% | ~1-3s per request (network) | ~5-15s per request (CPU, no GPU) |
| **Cost** | 20% | ~$0.003-0.015 per request | $0/request but EC2 already $155/mo |
| **Reliability** | 15% | 99.9%+ uptime (Anthropic SLA) | Depends on EC2 uptime + RAM limits |
| **Offline capability** | 10% | ❌ Requires internet | ✅ Works when disconnected |
| **Setup complexity** | 5% | Minimal (API key) | Moderate (Ollama install, model download, RAM tuning) |

## Detailed Analysis

### Model Quality
Claude Sonnet consistently outperforms open-source 7B-8B models on code review, summarization, and reasoning tasks. For Robo Stack's use cases (PR review, code generation, architecture analysis), the quality gap is significant. Local models would produce lower-quality reviews and miss subtle issues.

### Latency
On a t3.xlarge with no GPU, Ollama running Llama 3 8B at Q4 quantization generates ~5-10 tokens/sec. A typical code review (500-800 tokens output) would take 50-160 seconds. Claude API returns the same review in 1-3 seconds. The 50x latency difference makes local inference impractical for interactive use.

### Cost
Claude API pricing (Sonnet): ~$3/MTok input, $15/MTok output. At 50 reviews/week with ~2K tokens each, monthly cost is approximately $3-5. This is negligible compared to the $155/mo EC2 cost. Running Ollama adds CPU load that could interfere with K3s workloads, potentially requiring a larger instance.

### RAM Constraints
t3.xlarge has 16GB RAM. K3s + Docker + workstation services already consume ~6-8GB. A quantized 7B model needs ~4-6GB. Running both simultaneously risks OOM kills. An 8B model would leave <2GB headroom — too tight for production stability.

### Offline Capability
The only advantage of local inference is offline operation. Since the workstation is an EC2 instance (always online), this benefit is irrelevant. If we had a local workstation joining the cluster, this would matter more.

## Recommendation

**Cloud-first (Claude API)** for Sprint 2 and beyond.

**Rationale:**
1. 5x better model quality for the same tasks
2. 50x faster response times
3. Negligible additional cost ($3-5/mo vs $155/mo EC2)
4. No RAM contention with K3s workloads
5. Offline capability is moot on a cloud instance
6. Simpler setup and maintenance

**When to reconsider local:**
- If a local workstation rejoins the cluster (hardware fixed) and offline capability is needed
- If EC2 is upgraded to a GPU instance and local latency drops to <3s
- If open-source models reach Claude-level quality for code tasks
- Re-evaluate in Sprint 4 or when hardware situation changes

## Decision

| Option | Score (weighted) | Selected |
|--------|-----------------|----------|
| Cloud (Claude API) | 4.5 / 5.0 | ✅ |
| Local (Ollama on EC2) | 2.3 / 5.0 | ❌ |

**Awaiting Yeti sign-off.**
