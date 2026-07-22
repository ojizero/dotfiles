import * as fs from "node:fs";
import * as path from "node:path";
import type { ThinkingLevel } from "@mariozechner/pi-agent-core";
import { loadConfig } from "./config.js";
import { skillPathsFor } from "./skills.js";

export type Scope = "global" | "project";

export interface AgentConfig {
	id: string;
	name?: string;
	description?: string;
	model?: string;
	instructions?: string;
	thinkingLevel?: ThinkingLevel;
	tools?: string[];
	builtinTools?: string[];
}

export interface AgentRef {
	id: string;
	scope: Scope;
	dir: string;
}

export interface AgentDefinition extends AgentRef {
	config: AgentConfig;
	instructions: string;
	toolFiles: string[];
	skillPaths: string[];
	subagentDirs: string[];
}

export type LoadResult<T> = { ok: true; value: T } | { ok: false; warning: string };

export interface AgentStore {
	active: AgentDefinition | null;
	trustedProjectAgents: Set<string>;
	registeredTools: Map<string, string[]>;
}

export function createStore(): AgentStore {
	return { active: null, trustedProjectAgents: new Set(), registeredTools: new Map() };
}

const TOOL_EXTENSIONS = [".ts", ".js", ".mjs"];

function isTestFile(name: string): boolean {
	return /\.(test|spec)\.[cm]?[jt]s$/.test(name);
}

function safeReaddir(dir: string): fs.Dirent[] {
	try {
		return fs.readdirSync(dir, { withFileTypes: true });
	} catch {
		return [];
	}
}

function collectToolFiles(dir: string): string[] {
	const toolsDir = path.join(dir, "tools");
	const files: string[] = [];
	for (const entry of safeReaddir(toolsDir)) {
		if (entry.isSymbolicLink() || !entry.isFile()) continue;
		if (isTestFile(entry.name)) continue;
		if (!TOOL_EXTENSIONS.includes(path.extname(entry.name))) continue;
		files.push(path.join(toolsDir, entry.name));
	}
	return files.sort();
}

function collectSubagentDirs(dir: string): string[] {
	const subDir = path.join(dir, "subagents");
	const dirs: string[] = [];
	for (const entry of safeReaddir(subDir)) {
		if (entry.isSymbolicLink() || !entry.isDirectory()) continue;
		const candidate = path.join(subDir, entry.name);
		if (fs.existsSync(path.join(candidate, "config.json"))) dirs.push(candidate);
	}
	return dirs.sort();
}

export function loadAgent(ref: AgentRef, opts: { requireDescription?: boolean } = {}): LoadResult<AgentDefinition> {
	const configResult = loadConfig(ref.dir);
	if (!configResult.ok) return configResult;
	const config = configResult.value;

	if (opts.requireDescription && !config.description) {
		return { ok: false, warning: `agent '${ref.id}' is missing required 'description' in config.json` };
	}

	let instructions = config.instructions;
	if (instructions === undefined) {
		const file = path.join(ref.dir, "instructions.md");
		try {
			instructions = fs.readFileSync(file, "utf-8");
		} catch {
			return {
				ok: false,
				warning: `agent '${ref.id}' has no instructions (missing instructions.md and no config.instructions)`,
			};
		}
	}

	return {
		ok: true,
		value: {
			...ref,
			id: config.id,
			config,
			instructions,
			toolFiles: collectToolFiles(ref.dir),
			skillPaths: skillPathsFor(ref.dir),
			subagentDirs: collectSubagentDirs(ref.dir),
		},
	};
}
