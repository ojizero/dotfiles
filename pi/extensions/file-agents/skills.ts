import * as fs from "node:fs";
import * as path from "node:path";

export function skillPathsFor(agentDir: string): string[] {
	const skillsDir = path.join(agentDir, "skills");
	const paths: string[] = [];
	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(skillsDir, { withFileTypes: true });
	} catch {
		return paths;
	}
	for (const entry of entries) {
		if (entry.isSymbolicLink()) continue;
		if (entry.isFile() && entry.name.endsWith(".md")) {
			paths.push(path.join(skillsDir, entry.name));
			continue;
		}
		if (entry.isDirectory()) {
			const skillFile = path.join(skillsDir, entry.name, "SKILL.md");
			if (fs.existsSync(skillFile)) paths.push(path.join(skillsDir, entry.name));
		}
	}
	return paths.sort();
}
