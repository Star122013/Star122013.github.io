export const site = {
	title: "Stardust Notebook",
	description: "A minimalist Typst-powered blog.",
	url: "https://blog.qwerhyy.cyou", // change this to your actual domain
	lang: "en",
	favicon: "/favicon.svg", // path to your favicon
} as const;

export const pagination = {
	pageSize: 5,
} as const;

export const ui = {
	nav: [
		{ label: "Home", href: "/" },
		{ label: "Tags", href: "/tags" },
		{ label: "About", href: "/about" },
	],
	footer: "© 2026 Blog. Built with Astro & Typst.",
	github: "https://github.com/Star122013",
	email: "hyy122013@outlook.com",
} as const;
