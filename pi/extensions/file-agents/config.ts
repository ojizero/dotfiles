import * as fs from "node:fs";
import * as path from "node:path";
import type { AgentConfig, LoadResult } from "./agent.js";

const ID_PATTERN = /^[a-z0-9][a-z0-9_-]*$/i;
const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh"];

function asStringArray(value: unknown): string[] | undefined {
	if (value === undefined) return undefined;
	if (!Array.isArray(value)) return undefined;
	return value.filter((v): v is string => typeof v === "string");
}

export function loadConfig(dir: string): LoadResult<AgentConfig> {
	const file = path.join(dir, "config.json");
	let raw: string;
	try {
		raw = fs.readFileSync(file, "utf-8");
	} catch {
		return { ok: false, warning: `missing config.json in ${dir}` };
	}

	let parsed: Record<string, unknown>;
	try {
		parsed = JSON.parse(raw);
	} catch (err) {
		return { ok: false, warning: `invalid config.json in ${dir}: ${(err as Error).message}` };
	}
	if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
		return { ok: false, warning: `config.json in ${dir} must be a JSON object` };
	}

	const id = typeof parsed.id === "string" && parsed.id.length > 0 ? parsed.id : path.basename(dir);
	if (!ID_PATTERN.test(id)) {
		return { ok: false, warning: `invalid agent id '${id}' in ${dir} (allowed: [a-z0-9_-])` };
	}

	const thinkingLevel = parsed.thinkingLevel;
	if (thinkingLevel !== undefined && !THINKING_LEVELS.includes(thinkingLevel as string)) {
		return { ok: false, warning: `invalid thinkingLevel '${thinkingLevel}' in ${dir}` };
	}

	return {
		ok: true,
		value: {
			id,
			name: typeof parsed.name === "string" ? parsed.name : undefined,
			description: typeof parsed.description === "string" ? parsed.description : undefined,
			model: typeof parsed.model === "string" ? parsed.model : undefined,
			instructions: typeof parsed.instructions === "string" ? parsed.instructions : undefined,
			thinkingLevel: thinkingLevel as AgentConfig["thinkingLevel"],
			tools: asStringArray(parsed.tools),
			builtinTools: asStringArray(parsed.builtinTools),
		},
	};
}
