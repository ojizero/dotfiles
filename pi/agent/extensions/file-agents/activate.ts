import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AgentDefinition, AgentStore } from "./agent.js";
import { clearRender, renderActive } from "./render.js";
import { persistActive } from "./state.js";
import { loadSubagentTools } from "./subagents.js";
import { builtinToolNames, computeActiveTools, loadAgentTools } from "./tools.js";

function notifyWarnings(ctx: ExtensionContext, warnings: string[]): void {
	if (!ctx.hasUI || warnings.length === 0) return;
	for (const warning of [...new Set(warnings)]) {
		ctx.ui.notify(warning, "warning");
	}
}

async function applyModel(pi: ExtensionAPI, ctx: ExtensionContext, model: string): Promise<void> {
	const slash = model.indexOf("/");
	if (slash < 0) {
		if (ctx.hasUI) ctx.ui.notify(`model '${model}' must be in 'provider/model-id' form; keeping current model`, "warning");
		return;
	}
	const provider = model.slice(0, slash);
	const modelId = model.slice(slash + 1);
	const resolved = ctx.modelRegistry.find(provider, modelId);
	if (!resolved) {
		if (ctx.hasUI) ctx.ui.notify(`model '${model}' not found; keeping current model`, "warning");
		return;
	}
	const ok = await pi.setModel(resolved);
	if (!ok && ctx.hasUI) ctx.ui.notify(`no API key for '${model}'; keeping current model`, "warning");
}

export async function applyActive(pi: ExtensionAPI, ctx: ExtensionContext, store: AgentStore): Promise<void> {
	const agent = store.active;
	if (!agent) {
		pi.setActiveTools(builtinToolNames(pi));
		clearRender(ctx);
		return;
	}

	if (agent.config.model) await applyModel(pi, ctx, agent.config.model);
	if (agent.config.thinkingLevel) {
		pi.setThinkingLevel(agent.config.thinkingLevel);
	}

	const toolResult = await loadAgentTools(pi, agent, store);
	const subResult = loadSubagentTools(pi, agent, store);
	pi.setActiveTools(computeActiveTools(pi, agent, store));

	const agentToolCount = (store.registeredTools.get(agent.id) ?? []).length;
	renderActive(ctx, agent, agentToolCount);
	notifyWarnings(ctx, [...toolResult.warnings, ...subResult.warnings]);
}

export async function activate(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	target: AgentDefinition | null,
	store: AgentStore,
): Promise<void> {
	const previous = store.active;
	const prevHadSkills = previous ? previous.skillPaths.length > 0 : false;
	const targetHasSkills = target ? target.skillPaths.length > 0 : false;

	if (target && target.scope === "project" && !store.trustedProjectAgents.has(target.id)) {
		if (ctx.hasUI) {
			const trusted = await ctx.ui.confirm(
				"Project agent",
				`Activate project agent '${target.id}'? It comes from this repository.`,
			);
			if (!trusted) return;
		}
		store.trustedProjectAgents.add(target.id);
	}

	persistActive(pi, target ? target.id : null, target?.scope);
	store.active = target;

	if (prevHadSkills || targetHasSkills) {
		await ctx.reload();
		return;
	}

	await applyActive(pi, ctx, store);
	if (ctx.hasUI) {
		ctx.ui.notify(target ? `Activated agent '${target.id}'` : "Deactivated agent", "info");
	}
}
