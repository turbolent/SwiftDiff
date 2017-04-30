# SwiftDiff

SwiftDiff is a (partial) port of the [Google Diff, Match and Patch Library (google-diff-match-patch)](https://code.google.com/p/google-diff-match-patch/) to Swift. The Google Diff, Match and Patch Library was originally written by [Neil Fraser](http://neil.fraser.name). 

So far only the diff algorithm has been ported. It allows comparing two blocks of plain text and efficiently returning a list of their differences. It supports detecting in-line text differences.

## License

SwiftDiff is licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0) – see the `LICENSE` file for details.

The original Google Diff, Match and Patch Library is also licensed under the same license and Copyright (c) 2006 Google Inc.

## Usage


```swift
diff(text1: "The quick brown fox jumps over the lazy dog.", 
     text2: "That quick brown fox jumped over a lazy dog.")
```

```swift
[
  .equal("Th"),
  .delete("e"),
  .insert("at"),
  .equal(" quick brown fox jump"),
  .delete("s"),
  .insert("ed"),
  .equal(" over "),
  .delete("the"),
  .insert("a"),
  .equal(" lazy dog.")
]
```

