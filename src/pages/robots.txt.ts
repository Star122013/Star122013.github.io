import { site } from "../config";

export const prerender = true;

export async function GET() {
	const url = site.url || "https://yourdomain.com";
	const text = `User-agent: *
Allow: /

Sitemap: ${url}/sitemap-index.xml
`;

	return new Response(text, {
		headers: { "Content-Type": "text/plain" },
	});
}
