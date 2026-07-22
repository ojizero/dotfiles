import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { Scope } from "./agent.js";

export const ACTIVE_ENTRY = "file-agents/active";

interface ActiveEntryData {
	agentId: string | null;
	scope?: Scope;
}

export function persistActive(pi: ExtensionAPI, agentId: string | null, scope?: Scope): void {
	pi.appendEntry<ActiveEntryData>(ACTIVE_ENTRY, { agentId, scope });
}

export function rehydrateActive(ctx: ExtensionContext): { agentId: string; scope: Scope } | null {
	let last: ActiveEntryData | null = null;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || entry.customType !== ACTIVE_ENTRY) continue;
		last = entry.data as ActiveEntryData;
	}
	if (!last || !last.agentId) return null;
	return { agentId: last.agentId, scope: last.scope ?? "global" };
}
