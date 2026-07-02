#import "_template.typ": *

#show: post.with(
  title: "My First Post",
  date: datetime(year: 2026, month: 7, day: 1),
  tags: ("typst", "astro"),
  description: "My very first blog post written in Typst",
)

= My First Post

This is my first blog post written in *Typst*.

Typst is a modern typesetting system that's great for writing. Let me show you some of its features.

== Image

Here is a test figure with caption:

#figure(
  image("test-image.png", width: 100%),
  caption: [A test image with *styled* caption.],
)

== Math

Inline math: $x^2 + y^2 = z^2$

Display math:

$ integral_0^infinity e^(-x^2) dif x = sqrt(pi) / 2 $

== Footnotes

This sentence has a footnote.[#footnote[This is the footnote content. It will appear alongside the article.]]

Another footnote here.[#footnote[Second footnote for testing purposes.]]

== Lists

- Typst is fast
- Typst has great syntax
- Typst can do math

== Callouts

> Tip: This is a helpful tip callout with some useful information.

> Warning: This is a warning callout that requires attention.

== Code

Typst code can be shown with `raw` blocks:

```typc
#let greet(name) = [
  Hello, #name!
]
```
