import { execSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import type { Loader } from "astro/loaders";
import { z } from "astro/zod";

/**
 * Collect all `index.typ` files inside immediate subdirectories of `contentDir`.
 * Skips directories starting with `_` or `.`. Returns { dirName, filePath }.
 */
function findIndexTypFiles(contentDir: string): { dirName: string; filePath: string }[] {
	const results: { dirName: string; filePath: string }[] = [];

	for (const entry of readdirSync(contentDir, { withFileTypes: true })) {
		if (!entry.isDirectory()) continue;
		if (entry.name.startsWith("_") || entry.name.startsWith(".")) continue;

		const subFiles = readdirSync(join(contentDir, entry.name));
		if (subFiles.includes("index.typ")) {
			results.push({
				dirName: entry.name,
				filePath: join(contentDir, entry.name, "index.typ"),
			});
		}
	}

	return results;
}

/**
 * Extract frontmatter from a .typ file using typst eval.
 * Expects: #metadata((title: "...", date: datetime(...), ...))<frontmatter>
 *
 * @param root - project root passed to `typst eval --root` so that relative
 *               imports across subdirectories don't fail the sandbox check.
 */
function parseFrontmatter(filePath: string, root: string) {
	try {
		const out = execSync(
			`typst eval --root "${root}" 'query(<frontmatter>)' --in "${filePath}" --format json`,
			{ timeout: 10_000, stdio: "pipe", encoding: "utf-8" },
		);
		const parsed = JSON.parse(out);
		const meta = parsed?.[0]?.value;
		if (!meta) return null;

		const dateStr = String(meta.date || "");
		const date = dateStr.replace(
			/^datetime\(year:\s*(\d+),\s*month:\s*(\d+),\s*day:\s*(\d+).*\)$/,
			"$1-$2-$3",
		);

		return {
			title: String(meta.title || "Untitled"),
			date,
			draft: meta.draft === true,
			tags: Array.isArray(meta.tags) ? meta.tags.map(String) : [],
			description: String(meta.description || ""),
		};
	} catch (err) {
		const msg = err instanceof Error ? err.message : String(err);
		throw new Error(
			`typst eval failed for ${filePath}. Is typst installed? ${msg}`,
		);
	}
}

export function typstLoader(options: { dir: string }): Loader {
	return {
		name: "typst-loader",

		load: async ({ store, parseData, logger }) => {
			const contentDir = resolve(options.dir);
			const indexFiles = findIndexTypFiles(contentDir);

			if (indexFiles.length === 0) return;

			const tmpDir = join(contentDir, "_tmp");
			mkdirSync(tmpDir, { recursive: true });

			for (const { dirName, filePath } of indexFiles) {
				// Pass contentDir as --root so that `../_template.typ` and
				// other relative imports resolve while staying inside the
				// typst sandbox.
				const metadata = parseFrontmatter(filePath, contentDir);
				if (!metadata) {
					logger.warn(`Skipping ${dirName}/index.typ: no frontmatter found`);
					continue;
				}

				// Compile to HTML.
				const outFile = join(tmpDir, dirName + ".html");
				execSync(
					`typst compile --root "${contentDir}" --features html --format html "${filePath}" "${outFile}"`,
					{ timeout: 15_000, stdio: "pipe" },
				);

				const fullHtml = readFileSync(outFile, "utf-8");
				rmSync(outFile);

				const bodyMatch = fullHtml.match(/<body[^>]*>([\s\S]*)<\/body>/i);
				const bodyContent = bodyMatch ? bodyMatch[1].trim() : fullHtml;

				// ID is the post directory name
				const id = dirName;
				const data = await parseData({
					id,
					data: { ...metadata, body: bodyContent },
				});

				store.set({ id, data });
			}

			rmSync(tmpDir, { recursive: true });
		},

		schema: z.object({
			title: z.string(),
			date: z.coerce.date(),
			draft: z.boolean().optional().default(false),
			tags: z.array(z.string()).optional().default([]),
			description: z.string().optional().default(""),
			body: z.string(),
		}),
	};
}
