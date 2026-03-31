---
sidebar_position: 6
---

# TurboQuant

Why LucidPal uses a custom llama.cpp fork and what TurboQuant brings.

---

## Background

**TurboQuant** (Zandieh et al., ICLR 2026) is a quantization algorithm published by Google. It compresses neural network tensors — both model weights and the KV cache used during inference — down to 1–2 bits per element using a two-step pipeline:

1. **Randomized Hadamard Transform** — spreads energy uniformly across all coordinates, making the distribution analytically predictable.
2. **Lloyd-Max scalar quantization** — computes the theoretically optimal quantization buckets for that distribution. No calibration data or fine-tuning required.

---

## The fork: TheTom/llama-cpp-turboquant

The official llama.cpp doesn't include TurboQuant yet (an upstream PR is open). LucidPal is built against [TheTom's fork](https://github.com/TheTom/llama-cpp-turboquant), which implements TurboQuant with **Metal GPU kernels for Apple Silicon**.

The fork introduces two new GGML quantization types:

| GGML type | Bits per element | Use case |
|-----------|-----------------|----------|
| `GGML_TYPE_TQ1_0` | 1-bit | Maximum compression — quality loss on models < 8B |
| `GGML_TYPE_TQ2_0` | 2-bit | Near-lossless on models ≥ 1B |

Both types are compiled into LucidPal's `llama.xcframework` — the quantize, dequantize, and dot-product kernels are present in the binary.

---

## Current status: weight quantization only

The TQ types are currently used for **model weight quantization** (i.e. loading a GGUF model file that was quantized with TQ1 or TQ2). LucidPal currently ships with `Q4_K_M` model files, not TQ-quantized files.

**KV cache compression** (setting `type_k`/`type_v` to a TQ type at runtime) requires dedicated Metal attention kernels for those types. These kernels are marked `[EXPERIMENTAL]` in the llama.cpp API and, as of this build, are not available for the iOS Metal backend — attempting to enable them causes a crash at model load.

---

## Context windows without KV cache compression

Without KV cache compression, context window sizes are constrained by device RAM. LucidPal uses context sizes tuned to leave enough headroom for the model weights:

| Device RAM | Model | Context window |
|-----------|-------|---------------|
| 2–3 GB (iPhone 12, 13) | Qwen3.5 0.8B | 4K tokens |
| 3–5 GB (iPhone 13 non-Pro) | Qwen3.5 2B | 8K tokens |
| 5–7 GB (iPhone 13 Pro, 14, 15) | Qwen3.5 4B | 16K tokens |
| 7 GB+ (iPhone 15 Pro, 16, 17) | Qwen3.5 4B | 32K tokens |

---

## What to watch

Once the TurboQuant Metal KV cache kernels land in TheTom's fork (tracked in [turboquant_plus #27](https://github.com/TheTom/turboquant_plus/issues/27)), LucidPal can activate them with two lines in `LlamaActor.swift`:

```swift
cp.type_k = GGML_TYPE_TQ2_0
cp.type_v = GGML_TYPE_TQ2_0
```

That would deliver ~4–5× KV cache memory reduction, enabling significantly larger context windows within the same RAM budget.

---

## Sources

- [TurboQuant ICLR 2026 discussion — ggml-org/llama.cpp #20969](https://github.com/ggml-org/llama.cpp/discussions/20969)
- [TheTom/llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant)
- [Upstream contribution tracking — turboquant_plus #27](https://github.com/TheTom/turboquant_plus/issues/27)
