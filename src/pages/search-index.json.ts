import { getCollection } from "astro:content";

export const prerender = true;

export async function GET() {
	const posts = await getCollection("blog");
	const published = posts
		.filter((p) => !p.data.draft)
		.sort((a, b) => b.data.date.getTime() - a.data.date.getTime());

	const index = published.map((post) => ({
		id: post.id,
		title: post.data.title,
		date: post.data.date.toISOString().slice(0, 10),
		description: post.data.description,
		tags: post.data.tags,
	}));

	return new Response(JSON.stringify(index), {
		headers: { "Content-Type": "application/json" },
	});
}
