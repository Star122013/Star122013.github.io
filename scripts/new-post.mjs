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
const file = path.join("src/content/blog", `${slug}.typ`);

if (fs.existsSync(file)) {
	console.error(`File already exists: ${file}`);
	process.exit(1);
}

const template = `#import "_template.typ": *

#show: post.with(
  title: "${title.replace(/"/g, '\\"')}",
  date: ${date},
  tags: (),
  description: "",
)

= ${title}

Write your post here.
`;

fs.writeFileSync(file, template);
console.log(`Created: ${file}`);
