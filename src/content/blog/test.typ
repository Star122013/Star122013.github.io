#import "_template.typ": *

#show: post.with(
  title: "test",
  date: datetime(year: 2026, month: 7, day: 3),
  tags: ("test"),
  description: "test",
)

= test

Write your post here.
