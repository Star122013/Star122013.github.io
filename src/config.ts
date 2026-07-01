export const site = {
	title: "Stardust Notebook",
	description: "A minimalist Typst-powered blog.",
	url: "https://yourdomain.com", // change this to your actual domain
	lang: "en",
	favicon: "/favicon.svg", // path to your favicon
} as const;

export const pagination = {
	pageSize: 5,
} as const;

export const ui = {
	logo: "Blog",
	nav: [
		{ label: "Home", href: "/" },
		{ label: "Tags", href: "/tags" },
		{ label: "About", href: "/about" },
	],
	footer: "© 2026 Blog. Built with Astro & Typst.",
	github: "https://github.com/yourusername",
	email: "hello@example.com",
} as const;
