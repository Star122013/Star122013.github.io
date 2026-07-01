import { getCollection } from "astro:content";
import rss from "@astrojs/rss";
import { site } from "../config";

export const prerender = true;

export async function GET() {
	const posts = await getCollection("blog");
	const published = posts
		.filter((p) => !p.data.draft)
		.sort((a, b) => b.data.date.getTime() - a.data.date.getTime());

	return rss({
		title: site.title,
		description: site.description,
		site: site.url || "https://example.com",
		items: published.map((post) => ({
			title: post.data.title,
			pubDate: post.data.date,
			description: post.data.description,
			link: `/blog/${post.id}/`,
		})),
	});
}
