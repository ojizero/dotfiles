import type { ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { AgentDefinition } from "./agent.js";

const STATUS_KEY = "file-agents";
const WIDGET_KEY = "file-agents";

function shortModel(model: string | undefined): string | null {
	if (!model) return null;
	const slash = model.lastIndexOf("/");
	return slash >= 0 ? model.slice(slash + 1) : model;
}

function plural(count: number, noun: string): string {
	return `${count} ${noun}${count === 1 ? "" : "s"}`;
}

export function renderActive(ctx: ExtensionContext, agent: AgentDefinition, agentToolCount: number): void {
	if (!ctx.hasUI) return;
	ctx.ui.setStatus(STATUS_KEY, `agent: ${agent.id}`);

	const parts = [`⌾ ${agent.id}`];
	const model = shortModel(agent.config.model);
	if (model) parts.push(model);
	parts.push(plural(agentToolCount, "tool"));
	parts.push(plural(agent.skillPaths.length, "skill"));
	ctx.ui.setWidget(WIDGET_KEY, [parts.join(" · ")], { placement: "aboveEditor" });
}

export function clearRender(ctx: ExtensionContext): void {
	if (!ctx.hasUI) return;
	ctx.ui.setStatus(STATUS_KEY, undefined);
	ctx.ui.setWidget(WIDGET_KEY, undefined);
}
