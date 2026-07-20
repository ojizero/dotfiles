// Aperture provider for the Pi coding agent.
//
// Registers the Tailscale Aperture LLM proxy (an OpenAI-compatible
// `ts-llm-proxy`) as a Pi model provider and auto-detects every model it
// serves from its `/v1/models` catalog. Auth is handled seamlessly by
// Tailscale at the network layer, so no API key configuration is required —
// the placeholder key below is only there to satisfy Pi's provider schema and
// is ignored by the proxy.
//
// Override the endpoint per-machine with $APERTURE_BASE_URL if needed.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PROVIDER_ID = "aperture";
const PROVIDER_NAME = "Aperture";
const BASE_URL = process.env.APERTURE_BASE_URL ?? "http://aperture.tn.ojizero.dev/v1";
// Tailscale gates the proxy; the key is a placeholder to satisfy Pi's schema.
const API_KEY = process.env.APERTURE_API_KEY ?? "tailscale";

// Aperture reports pricing in dollars-per-token; Pi wants dollars-per-1M-tokens.
const PER_MILLION = 1_000_000;

// No hard context/output metadata is exposed by the catalog, so fall back to
// generous OpenAI-compatible defaults.
const DEFAULT_CONTEXT_WINDOW = 262_144;
const DEFAULT_MAX_TOKENS = 16_384;

type AperturePricing = Record<string, string | undefined>;

interface ApertureModel {
  id: string;
  metadata?: { provider?: { name?: string } };
  pricing?: AperturePricing | null;
  context_window?: number;
  max_tokens?: number;
}

type PiModel = NonNullable<
  Parameters<ExtensionAPI["registerProvider"]>[1]["models"]
>[number];

const dollarsPerMillion = (raw: string | undefined): number =>
  raw ? Number(raw) * PER_MILLION : 0;

// Reasoning/vision aren't advertised by the catalog, so infer them from the id.
const isReasoning = (id: string): boolean => /thinking|reason|gpt-5|o[134]\b/i.test(id);
// Match true vision markers (GLM-5V, Qwen-VL, "vision", "omni") without
// tripping on version strings like DeepSeek-V4 (a "V" *followed* by a digit).
const hasVision = (id: string): boolean => /vision|omni|vl\b|\dv(?![\da-z])/i.test(id);

const toPiModel = (model: ApertureModel): PiModel => {
  const pricing = model.pricing ?? {};
  const providerName = model.metadata?.provider?.name;
  return {
    id: model.id,
    name: providerName ? `${model.id} (${providerName})` : model.id,
    reasoning: isReasoning(model.id),
    input: hasVision(model.id) ? ["text", "image"] : ["text"],
    cost: {
      input: dollarsPerMillion(pricing.input),
      output: dollarsPerMillion(pricing.output),
      cacheRead: dollarsPerMillion(pricing.input_cache_read),
      cacheWrite: dollarsPerMillion(pricing.input_cache_write),
    },
    contextWindow: model.context_window ?? DEFAULT_CONTEXT_WINDOW,
    maxTokens: model.max_tokens ?? DEFAULT_MAX_TOKENS,
  };
};

const fetchApertureModels = async (signal?: AbortSignal): Promise<PiModel[]> => {
  const response = await fetch(`${BASE_URL}/models`, { signal });
  if (!response.ok) {
    throw new Error(`Aperture /models returned ${response.status} ${response.statusText}`);
  }
  const body = (await response.json()) as { data?: ApertureModel[] };
  return (body.data ?? []).map(toPiModel);
};

export default async function (pi: ExtensionAPI) {
  // Seed the catalog at startup; tolerate being offline / off-Tailscale.
  let models: PiModel[] = [];
  try {
    models = await fetchApertureModels();
  } catch (error) {
    pi.on("session_start", (_event, ctx) => {
      ctx.ui.notify(`Aperture: could not load models (${String(error)})`, "warning");
    });
  }

  pi.registerProvider(PROVIDER_ID, {
    name: PROVIDER_NAME,
    baseUrl: BASE_URL,
    apiKey: API_KEY,
    api: "openai-completions",
    models,
    // Let Pi refresh the catalog on demand; fall back to the seeded list when
    // network access is disallowed (offline init).
    async refreshModels(ctx) {
      if (!ctx.allowNetwork) return models;
      models = await fetchApertureModels(ctx.signal);
      return models;
    },
  });

  // Manual re-detect without restarting Pi — useful when Aperture gains models.
  pi.registerCommand("aperture-refresh", {
    description: "Re-detect models served by Tailscale Aperture",
    async handler(_args, ctx) {
      try {
        models = await fetchApertureModels();
        pi.registerProvider(PROVIDER_ID, {
          name: PROVIDER_NAME,
          baseUrl: BASE_URL,
          apiKey: API_KEY,
          api: "openai-completions",
          models,
        });
        ctx.ui.notify(`Aperture: detected ${models.length} model(s)`, "info");
      } catch (error) {
        ctx.ui.notify(`Aperture: refresh failed (${String(error)})`, "error");
      }
    },
  });
}
