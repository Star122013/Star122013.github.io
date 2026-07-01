// Blog post template
// Usage:
//   #import "_template.typ": *
//   #show: post.with(title: "...", date: datetime(...))

#set page(width: auto, height: auto, margin: 0pt)
#set text(size: 11pt)

#let post(title: "", date: datetime.today(), tags: (), description: "", body) = {
  [#metadata((title: title, date: date, tags: tags, description: description))<frontmatter>]
  body
}
