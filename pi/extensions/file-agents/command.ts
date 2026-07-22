import type { AutocompleteItem } from "@mariozechner/pi-tui";
import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import { loadAgent, type AgentDefinition, type AgentStore } from "./agent.js";
import { activate } from "./activate.js";
import { discoverAgentDirs } from "./discovery.js";

const NONE = "— none —";

function resolveAgents(cwd: string): { valid: AgentDefinition[]; warnings: string[] } {
	const valid: AgentDefinition[] = [];
	const warnings: string[] = [];
	for (const ref of discoverAgentDirs(cwd)) {
		const result = loadAgent(ref);
		if (result.ok) valid.push(result.value);
		else warnings.push(result.warning);
	}
	return { valid, warnings };
}

function completionId(agent: AgentDefinition, agents: AgentDefinition[]): string {
	const duplicate = agents.filter((a) => a.id === agent.id).length > 1;
	return duplicate ? `${agent.id}@${agent.scope}` : agent.id;
}

function findAgent(agents: AgentDefinition[], query: string): AgentDefinition | "ambiguous" | null {
	const at = query.lastIndexOf("@");
	const scope = at >= 0 ? query.slice(at + 1) : undefined;
	const id = at >= 0 ? query.slice(0, at) : query;

	const scoped = scope ? agents.filter((a) => a.scope === scope) : agents;
	const exact = scoped.filter((a) => a.id === id);
	const matches = exact.length > 0 ? exact : scoped.filter((a) => a.id.toLowerCase() === id.toLowerCase());
	if (matches.length === 0) return null;
	if (matches.length > 1) return "ambiguous";
	return matches[0];
}

export function registerAgentsCommand(pi: ExtensionAPI, store: AgentStore): void {
	pi.registerCommand("agents", {
		description: "Activate a file-based agent (or 'none' to deactivate)",
		getArgumentCompletions: (prefix): AutocompleteItem[] => {
			const { valid } = resolveAgents(process.cwd());
			const items: AutocompleteItem[] = valid.map((agent) => ({
				value: completionId(agent, valid),
				label: `${agent.id} (${agent.scope})`,
				description: agent.config.description,
			}));
			items.push({ value: "none", label: "none", description: "Deactivate the active agent" });
			return items.filter((item) => item.value.startsWith(prefix));
		},
		handler: async (args, ctx) => {
			const query = args.trim();
			const { valid, warnings } = resolveAgents(ctx.cwd);
			if (ctx.hasUI) for (const warning of [...new Set(warnings)]) ctx.ui.notify(warning, "error");

			if (query === "none") {
				await activate(pi, ctx, null, store);
				return;
			}

			if (query) {
				await activateByQuery(pi, ctx, valid, query, store);
				return;
			}

			if (!ctx.hasUI) {
				ctx.ui.notify("/agents requires an argument in non-interactive mode", "error");
				return;
			}
			await selectAgent(pi, ctx, valid, store);
		},
	});
}

async function activateByQuery(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	agents: AgentDefinition[],
	query: string,
	store: AgentStore,
): Promise<void> {
	const match = findAgent(agents, query);
	if (match === null) {
		if (ctx.hasUI) ctx.ui.notify(`No agent matching '${query}'`, "error");
		return;
	}
	if (match === "ambiguous") {
		if (ctx.hasUI) ctx.ui.notify(`'${query}' is ambiguous; use '<id>@global' or '<id>@project'`, "error");
		return;
	}
	await activate(pi, ctx, match, store);
}

async function selectAgent(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	agents: AgentDefinition[],
	store: AgentStore,
): Promise<void> {
	const options = new Map<string, AgentDefinition | null>();
	const labels: string[] = [];
	for (const agent of agents) {
		const active = store.active?.id === agent.id && store.active?.scope === agent.scope;
		const label = `${active ? "●" : "○"} ${agent.id} (${agent.scope})`;
		labels.push(label);
		options.set(label, agent);
	}
	labels.push(NONE);
	options.set(NONE, null);

	const choice = await ctx.ui.select("Activate agent", labels);
	if (choice === undefined) return;
	await activate(pi, ctx, options.get(choice) ?? null, store);
}
