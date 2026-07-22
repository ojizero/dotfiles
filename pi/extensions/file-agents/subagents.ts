import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { pathToFileURL } from "node:url";
import { defineTool, type ExtensionAPI, type ToolDefinition } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";
import { loadAgent, type AgentDefinition, type AgentStore, type LoadResult } from "./agent.js";
import { registerExtra } from "./tools.js";

function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && fs.existsSync(currentScript)) {
		return { command: process.execPath, args: [currentScript, ...args] };
	}
	const execName = path.basename(process.execPath).toLowerCase();
	if (!/^(node|bun)(\.exe)?$/.test(execName)) {
		return { command: process.execPath, args };
	}
	return { command: "pi", args };
}

// Generates a throwaway pi extension module that registers the subagent's own
// tools/ files in the spawned subprocess. `--no-session` subprocesses do not run
// file-agents' own rehydration, and tool files are ToolDefinition modules (not
// extension factories), so they cannot be passed to `--extension` directly.
// Each tool is registered under its file id (matching config.tools + `--tools`).
function buildToolBridgeSource(toolFiles: string[]): string {
	const imports: string[] = [];
	const entries: string[] = [];
	toolFiles.forEach((file, i) => {
		const id = path.basename(file, path.extname(file));
		imports.push(`import _t${i} from ${JSON.stringify(pathToFileURL(file).href)};`);
		entries.push(`[${JSON.stringify(id)}, _t${i}]`);
	});
	return [
		...imports,
		"export default (pi) => {",
		`\tconst defs = [${entries.join(", ")}];`,
		"\tfor (const [id, def] of defs) {",
		"\t\tif (def) pi.registerTool({ ...def, name: id });",
		"\t}",
		"};",
		"",
	].join("\n");
}

function collectAssistantText(message: any): string {
	if (!message || message.role !== "assistant" || !Array.isArray(message.content)) return "";
	return message.content
		.filter((c: any) => c?.type === "text" && typeof c.text === "string")
		.map((c: any) => c.text)
		.join("");
}

async function runSubagent(
	sub: AgentDefinition,
	task: string,
	cwd: string,
	signal: AbortSignal | undefined,
): Promise<{ text: string; exitCode: number; stderr: string; aborted: boolean }> {
	const args = ["--mode", "json", "-p", "--no-session"];
	if (sub.config.model) args.push("--model", sub.config.model);
	if (sub.config.tools && sub.config.tools.length > 0) args.push("--tools", sub.config.tools.join(","));

	let tmpDir: string | null = null;
	const ensureTmpDir = (): string => {
		if (!tmpDir) tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "file-agents-"));
		return tmpDir;
	};

	if (sub.instructions.trim()) {
		const promptFile = path.join(ensureTmpDir(), "system-prompt.md");
		fs.writeFileSync(promptFile, sub.instructions, "utf-8");
		args.push("--append-system-prompt", promptFile);
	}
	if (sub.toolFiles.length > 0) {
		const bridgeFile = path.join(ensureTmpDir(), "tools-bridge.mjs");
		fs.writeFileSync(bridgeFile, buildToolBridgeSource(sub.toolFiles), "utf-8");
		args.push("--extension", bridgeFile);
	}
	args.push(`Task: ${task}`);

	let output = "";
	let stderr = "";
	let aborted = false;
	try {
		const exitCode = await new Promise<number>((resolve) => {
			const invocation = getPiInvocation(args);
			const proc = spawn(invocation.command, invocation.args, {
				cwd,
				shell: false,
				stdio: ["ignore", "pipe", "pipe"],
			});
			let buffer = "";
			const processLine = (line: string) => {
				if (!line.trim()) return;
				let event: any;
				try {
					event = JSON.parse(line);
				} catch {
					return;
				}
				if (event.type === "message_end" && event.message) {
					output += collectAssistantText(event.message);
				}
			};
			proc.stdout.on("data", (data) => {
				buffer += data.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) processLine(line);
			});
			proc.stderr.on("data", (data) => {
				stderr += data.toString();
			});
			proc.on("close", (code) => {
				if (buffer.trim()) processLine(buffer);
				resolve(code ?? 0);
			});
			proc.on("error", () => resolve(1));
			if (signal) {
				const kill = () => {
					aborted = true;
					proc.kill("SIGTERM");
					setTimeout(() => {
						if (!proc.killed) proc.kill("SIGKILL");
					}, 5000);
				};
				if (signal.aborted) kill();
				else signal.addEventListener("abort", kill, { once: true });
			}
		});
		return { text: output, exitCode, stderr, aborted };
	} finally {
		if (tmpDir) try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch { /* ignore */ }
	}
}

export function buildDelegationTool(parentId: string, subDir: string): LoadResult<ToolDefinition> {
	const subId = path.basename(subDir);
	const result = loadAgent({ id: subId, scope: "global", dir: subDir }, { requireDescription: true });
	if (!result.ok) return result;
	const sub = result.value;

	const tool = defineTool({
		name: `${parentId}__delegate_${subId}`,
		label: `Delegate → ${sub.id}`,
		description: sub.config.description ?? `Delegate a task to the ${sub.id} subagent.`,
		parameters: Type.Object({
			task: Type.String({ description: `Task to delegate to the ${sub.id} subagent.` }),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			try {
				const run = await runSubagent(sub, params.task, ctx.cwd, signal);
				if (run.aborted) {
					return { content: [{ type: "text", text: `Subagent '${sub.id}' was aborted.` }], details: {} };
				}
				if (run.exitCode !== 0) {
					const detail = run.stderr.trim() || `exit code ${run.exitCode}`;
					return {
						content: [{ type: "text", text: `Subagent '${sub.id}' failed: ${detail}` }],
						details: {},
					};
				}
				return {
					content: [{ type: "text", text: run.text.trim() || "(no output)" }],
					details: {},
				};
			} catch (err) {
				return {
					content: [{ type: "text", text: `Subagent '${sub.id}' error: ${(err as Error).message}` }],
					details: {},
				};
			}
		},
	});

	return { ok: true, value: tool };
}

export function loadSubagentTools(
	pi: ExtensionAPI,
	agent: AgentDefinition,
	store: AgentStore,
): { registered: string[]; warnings: string[] } {
	const registered: string[] = [];
	const warnings: string[] = [];
	for (const subDir of agent.subagentDirs) {
		const result = buildDelegationTool(agent.id, subDir);
		if (!result.ok) {
			warnings.push(result.warning);
			continue;
		}
		pi.registerTool(result.value);
		registered.push(result.value.name);
	}
	if (registered.length > 0) registerExtra(store, agent.id, registered);
	return { registered, warnings };
}
