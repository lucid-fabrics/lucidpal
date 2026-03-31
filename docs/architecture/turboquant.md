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

The fork introduces new GGML quantization types:

| GGML type | Bits per element | Use case |
|-----------|-----------------|----------|
| `GGML_TYPE_TQ1_0` | 1-bit | Maximum compression — quality loss on models < 8B |
| `GGML_TYPE_TQ2_0` | 2-bit | Near-lossless on models ≥ 1B |
| `GGML_TYPE_TURBO4_0` | 4-bit | KV cache compression — active in LucidPal |

All types are compiled into LucidPal's `llama.xcframework` — the quantize, dequantize, and dot-product kernels, including Metal GPU kernels for TURBO2_0/TURBO3_0/TURBO4_0, are present in the binary.

---

## Current status: KV cache active

`GGML_TYPE_TURBO4_0` KV cache compression is **enabled** in LucidPal as of the `feature/turboquant-kv-cache` branch. Both `type_k` and `type_v` are set to `TURBO4_0` at model load in `LlamaActor.loadSingleModel`:

```swift
cp.type_k = GGML_TYPE_TURBO4_0
cp.type_v = GGML_TYPE_TURBO4_0
```

The dedicated Metal attention kernels for TURBO4_0 landed in TheTom's fork and are compiled into LucidPal's `llama.xcframework`. On every model load, LucidPal logs:

```
KV cache types: type_k=turbo4_0 type_v=turbo4_0
```

The active type is visible in **Settings → Advanced → KV Cache** (shows `turbo4_0`). Model weights continue to ship as `Q4_K_M` GGUF files — the TQ1/TQ2 weight-quantized formats remain available for future use.

---

## Context windows with TURBO4_0 KV cache compression

With `GGML_TYPE_TURBO4_0` KV cache compression active, context window sizes are significantly larger than what device RAM would otherwise allow. LucidPal uses context sizes tuned to leave enough headroom for the model weights:

| Device RAM | Model | Context window |
|-----------|-------|---------------|
| 2–3 GB (iPhone 12, 13) | Qwen3.5 0.8B | 4K tokens |
| 3–5 GB (iPhone 13 non-Pro) | Qwen3.5 2B | 8K tokens |
| 5–7 GB (iPhone 13 Pro, 14, 15) | Qwen3.5 4B | 16K tokens |
| 7 GB+ (iPhone 15 Pro, 16, 17) | Qwen3.5 4B | 32K tokens |

---

## Sources

- [TurboQuant ICLR 2026 discussion — ggml-org/llama.cpp #20969](https://github.com/ggml-org/llama.cpp/discussions/20969)
- [TheTom/llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant)
- [Upstream contribution tracking — turboquant_plus #27](https://github.com/TheTom/turboquant_plus/issues/27)
