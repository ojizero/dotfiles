import * as path from "node:path";
import { pathToFileURL } from "node:url";
import type { ExtensionAPI, ToolDefinition } from "@earendil-works/pi-coding-agent";
import type { AgentDefinition, AgentStore } from "./agent.js";

export function namespacedToolName(agentId: string, toolId: string): string {
	return `${agentId}__${toolId}`;
}

function isToolDefinition(value: unknown): value is ToolDefinition {
	return (
		typeof value === "object" &&
		value !== null &&
		typeof (value as ToolDefinition).name === "string" &&
		typeof (value as ToolDefinition).execute === "function" &&
		typeof (value as ToolDefinition).parameters === "object"
	);
}

async function importToolFile(file: string): Promise<ToolDefinition | null> {
	const mod = (await import(pathToFileURL(file).href)) as { default?: unknown };
	return isToolDefinition(mod.default) ? mod.default : null;
}

export async function loadAgentTools(
	pi: ExtensionAPI,
	agent: AgentDefinition,
	store: AgentStore,
): Promise<{ registered: string[]; warnings: string[] }> {
	const cached = store.registeredTools.get(agent.id);
	if (cached) return { registered: [...cached], warnings: [] };

	const registered: string[] = [];
	const warnings: string[] = [];
	for (const file of agent.toolFiles) {
		const toolId = path.basename(file, path.extname(file));
		const name = namespacedToolName(agent.id, toolId);
		try {
			const tool = await importToolFile(file);
			if (!tool) {
				warnings.push(`tool '${toolId}' skipped: no valid ToolDefinition default export`);
				continue;
			}
			pi.registerTool({ ...tool, name });
			registered.push(name);
		} catch (err) {
			warnings.push(`tool '${toolId}' skipped: ${(err as Error).message}`);
		}
	}
	store.registeredTools.set(agent.id, registered);
	return { registered, warnings };
}

export function registerExtra(store: AgentStore, agentId: string, names: string[]): void {
	const existing = store.registeredTools.get(agentId) ?? [];
	store.registeredTools.set(agentId, [...existing, ...names]);
}

export function builtinToolNames(pi: ExtensionAPI): string[] {
	return pi
		.getAllTools()
		.filter((t) => t.sourceInfo.source === "builtin")
		.map((t) => t.name);
}

export function computeActiveTools(pi: ExtensionAPI, agent: AgentDefinition, store: AgentStore): string[] {
	const builtins = builtinToolNames(pi);
	const allowedBuiltins = agent.config.builtinTools;
	const selectedBuiltins = allowedBuiltins ? builtins.filter((name) => allowedBuiltins.includes(name)) : builtins;

	let agentTools = store.registeredTools.get(agent.id) ?? [];
	const allowedTools = agent.config.tools;
	if (allowedTools) {
		// Restrict the discovered tool files to the config.json allow-list (by tool id).
		// Names not derived from a tool file (e.g. subagent delegation tools) pass through.
		const toolFileNames = new Set(
			agent.toolFiles.map((file) => namespacedToolName(agent.id, path.basename(file, path.extname(file)))),
		);
		const allowedNames = new Set(allowedTools.map((id) => namespacedToolName(agent.id, id)));
		agentTools = agentTools.filter((name) => !toolFileNames.has(name) || allowedNames.has(name));
	}
	return [...new Set([...selectedBuiltins, ...agentTools])];
}
