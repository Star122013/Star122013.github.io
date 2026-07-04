#!/usr/bin/env node
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const title = process.argv[2];
if (!title) {
	console.error('Usage: pnpm new-post "My Post Title"');
	process.exit(1);
}

const slug = title
	.toLowerCase()
	.replace(/[^a-z0-9]+/g, "-")
	.replace(/^-|-$/g, "");

const now = new Date();
const date = `datetime(year: ${now.getFullYear()}, month: ${now.getMonth() + 1}, day: ${now.getDate()})`;

// Each post is a folder containing index.typ + its own images
const postDir = path.join("src/content/blog", slug);
const file = path.join(postDir, "index.typ");

if (fs.existsSync(postDir)) {
	console.error(`Post already exists: ${postDir}`);
	process.exit(1);
}

const template = `#import "../_template.typ": *

#show: post.with(
  title: "${title.replace(/"/g, '\\"')}",
  date: ${date},
  tags: (),
  description: "",
)

= ${title}

Write your post here.
`;

fs.mkdirSync(postDir, { recursive: true });
fs.writeFileSync(file, template);
console.log(`Created: ${file}`);
console.log(`Images for this post go in: ${postDir}/`);
