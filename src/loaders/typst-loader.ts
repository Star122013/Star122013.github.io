import { execSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import type { Loader } from "astro/loaders";
import { z } from "astro/zod";

/**
 * Extract frontmatter from a .typ file using typst eval.
 * Expects: #metadata((title: "...", date: datetime(...), ...))<frontmatter>
 */
function parseFrontmatter(filePath: string) {
	try {
		const out = execSync(
			`typst eval 'query(<frontmatter>)' --in "${filePath}" --format json`,
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
			const typFiles = readdirSync(contentDir).filter(
				(f) => f.endsWith(".typ") && !f.startsWith("_"),
			);

			if (typFiles.length === 0) return;

			const tmpDir = join(contentDir, "_tmp");
			mkdirSync(tmpDir, { recursive: true });

			for (const file of typFiles) {
				const filePath = join(contentDir, file);

				const metadata = parseFrontmatter(filePath);
				if (!metadata) {
					logger.warn(`Skipping ${file}: no frontmatter found`);
					continue;
				}

				// Compile to HTML
				const outFile = join(tmpDir, file + ".html");
				execSync(
					`typst compile --features html --format html "${filePath}" "${outFile}"`,
					{ timeout: 15_000, stdio: "pipe" },
				);

				const fullHtml = readFileSync(outFile, "utf-8");
				rmSync(outFile);

				const bodyMatch = fullHtml.match(/<body[^>]*>([\s\S]*)<\/body>/i);
				const bodyContent = bodyMatch ? bodyMatch[1].trim() : fullHtml;

				const id = file.replace(/\.typ$/, "");
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
