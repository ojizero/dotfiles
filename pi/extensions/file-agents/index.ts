import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { type AgentDefinition, createStore, loadAgent } from "./agent.js";
import { applyActive } from "./activate.js";
import { registerAgentsCommand } from "./command.js";
import { discoverAgentDirs } from "./discovery.js";
import { clearRender } from "./render.js";
import { rehydrateActive } from "./state.js";

export default function fileAgents(pi: ExtensionAPI) {
	const store = createStore();
	registerAgentsCommand(pi, store);

	pi.on("session_start", async (_event, ctx) => {
		try {
			store.active = null;
			const rehydrated = rehydrateActive(ctx);
			if (!rehydrated) return;
			// AgentRef.id is the directory name, but the persisted id is the config-derived
			// AgentDefinition.id (config.json's optional `id` override). Resolve each candidate
			// through loadAgent and match on the config id so a custom `id` still rehydrates.
			let loaded: AgentDefinition | null = null;
			for (const candidate of discoverAgentDirs(ctx.cwd)) {
				if (candidate.scope !== rehydrated.scope) continue;
				const result = loadAgent(candidate);
				if (result.ok && result.value.id === rehydrated.agentId) {
					loaded = result.value;
					break;
				}
			}
			if (!loaded) return;
			store.active = loaded;
			store.trustedProjectAgents.add(loaded.id);
			await applyActive(pi, ctx, store);
		} catch {
			store.active = null;
		}
	});

	pi.on("resources_discover", (_event, _ctx) => {
		try {
			return { skillPaths: store.active?.skillPaths ?? [] };
		} catch {
			return { skillPaths: [] };
		}
	});

	pi.on("before_agent_start", (event, _ctx) => {
		try {
			const agent = store.active;
			if (!agent) return;
			return {
				systemPrompt: `${event.systemPrompt}\n\n<file-agent id="${agent.id}">\n${agent.instructions}\n</file-agent>`,
			};
		} catch {
			return undefined;
		}
	});

	pi.on("session_shutdown", (_event, ctx) => {
		try {
			clearRender(ctx);
		} catch {
			/* ignore */
		}
	});
}
