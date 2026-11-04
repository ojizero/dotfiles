import * as fs from "node:fs";
import * as path from "node:path";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type { AgentRef } from "./agent.js";

function isRealDir(p: string): boolean {
	try {
		return fs.statSync(p).isDirectory();
	} catch {
		return false;
	}
}

function collectFrom(root: string, scope: AgentRef["scope"]): AgentRef[] {
	const refs: AgentRef[] = [];
	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(root, { withFileTypes: true });
	} catch {
		return refs;
	}
	for (const entry of entries) {
		if (entry.isSymbolicLink() || !entry.isDirectory()) continue;
		const dir = path.join(root, entry.name);
		if (!fs.existsSync(path.join(dir, "config.json"))) continue;
		refs.push({ id: entry.name, scope, dir });
	}
	return refs;
}

function findProjectAgentsDir(cwd: string): string | null {
	let current = cwd;
	while (true) {
		const candidate = path.join(current, ".pi", "agents");
		if (isRealDir(candidate)) return candidate;
		if (isRealDir(path.join(current, ".git"))) return null;
		const parent = path.dirname(current);
		if (parent === current) return null;
		current = parent;
	}
}

export function discoverAgentDirs(cwd: string): AgentRef[] {
	const globalRoot = path.join(getAgentDir(), "agents");
	const projectRoot = findProjectAgentsDir(cwd);
	return [
		...collectFrom(globalRoot, "global"),
		...(projectRoot ? collectFrom(projectRoot, "project") : []),
	];
}
