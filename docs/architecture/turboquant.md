---
sidebar_position: 6
---

# TurboQuant

How LucidPal fits a long-context AI into your iPhone's RAM.

---

## The problem: KV cache eats memory

Every time the AI generates a response, it maintains a **KV cache** — a running scratchpad of everything said so far in the conversation. The longer the conversation, the bigger the cache. On a desktop with 64 GB of RAM this isn't a concern. On an iPhone with 4–8 GB, it absolutely is.

Without compression, a 4B model with a 32K-token context window would need several gigabytes of RAM for the KV cache alone — on top of the model weights. That doesn't leave enough headroom to actually run.

---

## What TurboQuant does

**TurboQuant** (Zandieh et al., ICLR 2026) is a KV cache compression algorithm published by Google. Instead of storing each key and value at full 32-bit float precision, it compresses them down to **4 bits per element** — roughly an 8× reduction — with negligible quality loss.

The technique works in two steps:

1. **Randomized Hadamard Transform** — a mathematically precise rotation that spreads the energy of each vector evenly across all its coordinates. After this step, every coordinate has a similar scale and distribution, which makes it possible to quantize them accurately.

2. **Lloyd-Max scalar quantization** — since the distribution after the rotation is known analytically (it's Gaussian), the algorithm computes the theoretically optimal set of quantization buckets. No calibration data, no fine-tuning, no dataset required — it works on any model out of the box.

The result is a KV cache that takes **~4.9× less memory** with effectively no measurable difference in output quality.

---

## The fork: TheTom/llama-cpp-turboquant

The official llama.cpp doesn't include TurboQuant yet (an upstream contribution PR is open). LucidPal is built against [TheTom's fork](https://github.com/TheTom/llama-cpp-turboquant), which implements TurboQuant with **Metal GPU kernels for Apple Silicon** — meaning the compression and decompression happen on the iPhone's GPU, not the CPU. This is what makes it fast enough to be practical on a mobile device.

The fork adds two new KV cache types:

| Type | Bits per element | Notes |
|------|-----------------|-------|
| `turbo3` | 3-bit | Maximum compression, slight quality tradeoff on models < 8B |
| `turbo4` | 4-bit | **Used by LucidPal** — near-lossless on all Qwen3.5 sizes |

LucidPal uses **turbo4** across all model sizes and all context window tiers.

---

## What this enables in practice

Without TurboQuant, the context windows would need to be much smaller to stay within iPhone RAM budgets. With it:

| Device RAM | Model | Context window |
|-----------|-------|---------------|
| 2–3 GB (iPhone 12, 13) | Qwen3.5 0.8B | 4K tokens |
| 3–5 GB (iPhone 13 non-Pro) | Qwen3.5 2B | 8K tokens |
| 5–7 GB (iPhone 13 Pro, 14, 15) | Qwen3.5 4B | 16K tokens |
| 7 GB+ (iPhone 15 Pro, 16, 17) | Qwen3.5 4B | 32K tokens |

A 32K-token context fits roughly 100 pages of text — enough to hold a very long conversation, your entire calendar month, and supporting detail all in a single session.

---

## Why not turbo3?

The 3-bit variant offers more compression but quality degrades noticeably on models smaller than 8B — exactly the size range LucidPal targets (0.8B–4B). Turbo4 hits the sweet spot: the compression gain is large enough to matter, and the accuracy impact is effectively unmeasurable at these model sizes.

---

## Sources

- [TurboQuant ICLR 2026 discussion — ggml-org/llama.cpp #20969](https://github.com/ggml-org/llama.cpp/discussions/20969)
- [TheTom/llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant)
- [Feature request upstream — #20977](https://github.com/ggml-org/llama.cpp/issues/20977)
