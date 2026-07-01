import { defineCollection, z } from "astro:content";
import { typstLoader } from "./loaders/typst-loader";

const blog = defineCollection({
	loader: typstLoader({ dir: "src/content/blog" }),
	schema: z.object({
		title: z.string(),
		date: z.coerce.date(),
		draft: z.boolean().optional().default(false),
		tags: z.array(z.string()).optional().default([]),
		description: z.string().optional().default(""),
		body: z.string(),
	}),
});

export const collections = { blog };
