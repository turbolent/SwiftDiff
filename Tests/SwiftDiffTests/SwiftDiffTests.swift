import XCTest
@testable import SwiftDiff
import CoreFoundation
import Dispatch


class SwiftDiffTests: XCTestCase {

    func testDiffCommonPrefix() {
        // Detect any common prefix.

        // Null case.
        XCTAssertEqual(0, commonPrefixLength(text1: "abc", text2: "xyz"))

        // Non-null case.
        XCTAssertEqual(4, commonPrefixLength(text1: "1234abcdef", text2: "1234xyz"))

        // Whole case.
        XCTAssertEqual(4, commonPrefixLength(text1: "1234", text2: "1234xyz"))
    }

    func testDiffCommonSuffix() {
        // Detect any common suffix.

        // Null case.
        XCTAssertEqual(0, commonSuffixLength(text1: "abc", text2: "xyz"))

        // Non-null case.
        XCTAssertEqual(4, commonSuffixLength(text1: "abcdef1234", text2: "xyz1234"))

        // Whole case.
        XCTAssertEqual(4, commonSuffixLength(text1: "1234", text2: "xyz1234"))
    }

    func testDiffCommonOverlap() {
        // Detect any suffix/prefix overlap.

        // Null case.
        XCTAssertEqual(0, commonOverlapLength(text1: "", text2: "abcd"));

        // Whole case.
        XCTAssertEqual(3, commonOverlapLength(text1: "abc", text2: "abcd"));

        // No overlap.
        XCTAssertEqual(0, commonOverlapLength(text1: "123456", text2: "abcd"));

        // Overlap.
        XCTAssertEqual(3, commonOverlapLength(text1: "123456xxx", text2: "xxxabcd"));

        // Unicode.
        // Some overly clever languages (C#) may treat ligatures as equal to their
        // component letters.  E.g. U+FB01 == 'fi'
        XCTAssertEqual(0, commonOverlapLength(text1: "fi", text2: "\u{fb01}i"));
    }

    func testDiff() {
        // Null case.
        XCTAssertEqual([],
                       diff(text1: "", text2: ""))

        // Equality.
        XCTAssertEqual([.equal("abc")],
                       diff(text1: "abc", text2: "abc"))

        // Simple insertion.
        XCTAssertEqual([.equal("ab"), .insert("123"), .equal("c")],
                       diff(text1: "abc",
                            text2: "ab123c"))

        // Simple deletion.
        XCTAssertEqual([.equal("a"), .delete("123"), .equal("bc")],
                       diff(text1: "a123bc",
                            text2: "abc"))

        // Two insertions.
        XCTAssertEqual([.equal("a"), .insert("123"),
                        .equal("b"), .insert("456"),
                        .equal("c")],
                       diff(text1: "abc",
                            text2: "a123b456c"))

        // Two deletions.
        XCTAssertEqual([.equal("a"), .delete("123"),
                        .equal("b"), .delete("456"),
                        .equal("c")],
                       diff(text1: "a123b456c",
                            text2: "abc"))

        // Simple cases.
        XCTAssertEqual([.delete("a"), .insert("b")],
                       diff(text1: "a",
                            text2: "b"))

        XCTAssertEqual([.delete("a"), .insert("\u{0680}"), .equal("x"), .delete("\t"), .insert("\0")],
                       diff(text1: "ax\t",
                            text2: "\u{0680}x\0"))

        // Requires first phase of cleanupMerge.
        XCTAssertEqual([.delete("Apple"), .insert("Banana"), .equal("s are a"),
                        .insert("lso"), .equal(" fruit.")],
                       diff(text1: "Apples are a fruit.",
                            text2: "Bananas are also fruit."))

        // Overlaps.
        XCTAssertEqual([.delete("1"), .equal("a"), .delete("y"), .equal("b"), .delete("2"), .insert("xab")],
                       diff(text1: "1ayb2",
                            text2: "abxab"))

        // Requires second phase of cleanupMerge.
        XCTAssertEqual([.insert("xaxcx"), .equal("abc"), .delete("y")],
                       diff(text1: "abcy", text2: "xaxcxabc"))

        XCTAssertEqual([.delete("ABCD"), .equal("a"), .delete("="), .insert("-"), .equal("bcd"),
                        .delete("="), .insert("-"), .equal("efghijklmnopqrs"), .delete("EFGHIJKLMNOefg")],
                       diff(text1: "ABCDa=bcd=efghijklmnopqrsEFGHIJKLMNOefg",
                            text2: "a-bcd-efghijklmnopqrs"))

        // Large equality.
        XCTAssertEqual([.insert(" "), .equal("a"), .insert("nd"),
                        .equal(" [[Pennsylvania]]"), .delete(" and [[New")],
                       diff(text1: "a [[Pennsylvania]] and [[New",
                            text2: " and [[Pennsylvania]]"))


        // Timeout.
        var a = "`Twas brillig, and the slithy toves\nDid gyre and gimble in the wabe:\nAll mimsy were the borogoves,\nAnd the mome raths outgrabe.\n"
        var b = "I am the very model of a modern major general,\nI\'ve information vegetable, animal, and mineral,\nI know the kings of England, and I quote the fights historical,\nFrom Marathon to Waterloo, in order categorical.\n"
        // Increase the text lengths by 1024 times to ensure a timeout.
        for _ in 0..<10 {
            a = a + a
            b = b + b
        }

        // 100ms
        let timeout = 0.1
        let timeoutExpectation = expectation(description: "timeout")
        var duration: CFTimeInterval? = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = diff(text1: a, text2: b, timeout: timeout)
            let endTime = CFAbsoluteTimeGetCurrent()
            duration = endTime - startTime
            timeoutExpectation.fulfill()
        }

        // Ensure diff calculation doesn't take forever
        waitForExpectations(timeout: 5) { error in
            guard error == nil else {
                return
            }
            XCTAssertNotNil(duration)
            // Test that we took at least the timeout period.
            XCTAssertLessThanOrEqual(timeout, duration ?? Double.nan)
        }
    }

    func testDiffHalfMatch() {
        // Detect a halfmatch.

        // No match.
        XCTAssertEqual(nil, halfMatch(text1: "1234567890",
                                      text2: "abcdef"))

        XCTAssertEqual(nil, halfMatch(text1: "12345",
                                      text2: "23"))

        // Single Match.
        XCTAssertEqual(HalfMatch(text1A: "12", text1B: "9",
                                 text2A: "a", text2B: "z",
                                 midCommon: "345678"),
                       halfMatch(text1: "123456789",
                                 text2: "a345678z"))

        XCTAssertEqual(HalfMatch(text1A: "a", text1B: "z",
                                 text2A: "12", text2B: "90",
                                 midCommon: "345678"),
                       halfMatch(text1: "a345678z",
                                 text2: "1234567890"))

        XCTAssertEqual(HalfMatch(text1A: "abc", text1B: "z",
                                 text2A: "1234", text2B: "0",
                                 midCommon: "56789"),
                       halfMatch(text1: "abc56789z",
                                 text2: "1234567890"))

        XCTAssertEqual(HalfMatch(text1A: "a", text1B: "xyz",
                                 text2A: "1", text2B: "7890",
                                 midCommon: "23456"),
                       halfMatch(text1: "a23456xyz",
                                 text2: "1234567890"))

        // Multiple Matches.
        XCTAssertEqual(HalfMatch(text1A: "12123", text1B: "123121",
                                 text2A: "a", text2B: "z",
                                 midCommon: "1234123451234"),
                       halfMatch(text1: "121231234123451234123121",
                                 text2: "a1234123451234z"))

        XCTAssertEqual(HalfMatch(text1A: "", text1B: "-=-=-=-=-=",
                                 text2A: "x", text2B: "",
                                 midCommon: "x-=-=-=-=-=-=-="),
                       halfMatch(text1: "x-=-=-=-=-=-=-=-=-=-=-=-=",
                                 text2: "xx-=-=-=-=-=-=-="))

        XCTAssertEqual(HalfMatch(text1A: "-=-=-=-=-=", text1B: "",
                                 text2A: "", text2B: "y",
                                 midCommon: "-=-=-=-=-=-=-=y"),
                       halfMatch(text1: "-=-=-=-=-=-=-=-=-=-=-=-=y",
                                 text2: "-=-=-=-=-=-=-=yy"))

        // Non-optimal halfmatch.
        // Optimal diff would be -q+x=H-i+e=lloHe+Hu=llo-Hew+y not -qHillo+x=HelloHe-w+Hulloy
        XCTAssertEqual(HalfMatch(text1A: "qHillo", text1B: "w",
                                 text2A: "x", text2B: "Hulloy",
                                 midCommon: "HelloHe"),
                       halfMatch(text1: "qHilloHelloHew",
                                 text2: "xHelloHeHulloy"))
    }

    func testCleanupMerge() {
        // Cleanup a messy diff.

        // First phase:

        // Null case.
        XCTAssertEqual([],
                       cleanupMerge(diffs: []))

        // No change case.
        XCTAssertEqual([.equal("a"), .delete("b"), .insert("c")],
                       cleanupMerge(diffs:
                        [.equal("a"), .delete("b"), .insert("c")]))

        // Merge equalities.
        XCTAssertEqual([.equal("abc")],
                       cleanupMerge(diffs:
                        [.equal("a"), .equal("b"), .equal("c")]))

        // Merge deletions.
        XCTAssertEqual([.delete("abc")],
                       cleanupMerge(diffs:
                        [.delete("a"), .delete("b"), .delete("c")]))

        // Merge insertions.
        XCTAssertEqual([.insert("abc")],
                       cleanupMerge(diffs:
                        [.insert("a"), .insert("b"), .insert("c")]))

        // Merge interweave.
        XCTAssertEqual([.delete("ac"), .insert("bd"), .equal("ef")],
                       cleanupMerge(diffs:
                        [.delete("a"), .insert("b"), .delete("c"), .insert("d"), .equal("e"), .equal("f")]))

        // Prefix and suffix detection.
        XCTAssertEqual([.equal("a"), .delete("d"), .insert("b"), .equal("c")],
                       cleanupMerge(diffs:
                        [.delete("a"), .insert("abc"), .delete("dc")]))

        // Prefix and suffix detection with equalities.
        XCTAssertEqual([.equal("xa"), .delete("d"), .insert("b"), .equal("cy")],
                       cleanupMerge(diffs:
                        [.equal("x"), .delete("a"), .insert("abc"), .delete("dc"), .equal("y")]))

        // Second phase:

        // Slide edit left.
        XCTAssertEqual([.insert("ab"), .equal("ac")],
                       cleanupMerge(diffs:
                        [.equal("a"), .insert("ba"), .equal("c")]))

        // Slide edit right.
        XCTAssertEqual([.equal("ca"), .insert("ba")],
                       cleanupMerge(diffs:
                        [.equal("c"), .insert("ab"), .equal("a")]))

        // Slide edit left recursive.
        XCTAssertEqual([.delete("abc"), .equal("acx")],
                       cleanupMerge(diffs:
                        [.equal("a"), .delete("b"), .equal("c"), .delete("ac"), .equal("x")]))

        // Slide edit right recursive.
        XCTAssertEqual([.equal("xca"), .delete("cba")],
                       cleanupMerge(diffs:
                        [.equal("x"), .delete("ca"), .equal("c"), .delete("b"), .equal("a")]))
    }

    func testCleanupSemanticScore() {
        XCTAssertEqual(6, cleanupSemanticScore(text1: "", text2: ""))
        XCTAssertEqual(6, cleanupSemanticScore(text1: " ", text2: ""))
        XCTAssertEqual(5, cleanupSemanticScore(text1: "\n\n", text2: "\n\n"))
        XCTAssertEqual(5, cleanupSemanticScore(text1: "\r\n\n", text2: "\n\r\n"))
        XCTAssertEqual(5, cleanupSemanticScore(text1: "\r\n\r\n", text2: "\n\n"))
        XCTAssertEqual(2, cleanupSemanticScore(text1: " ", text2: " "))
    }

    func testCleanupSemanticLossless() {
        // Slide diffs to match logical boundaries.

        // Null case.
        XCTAssertEqual([],
                       cleanupSemanticLossless(diffs: []))

        // Blank lines.
        XCTAssertEqual([.equal("AAA\r\n\r\n"), .insert("BBB\r\nDDD\r\n\r\n"), .equal("BBB\r\nEEE")],
                       cleanupSemanticLossless(diffs:
                        [.equal("AAA\r\n\r\nBBB"), .insert("\r\nDDD\r\n\r\nBBB"), .equal("\r\nEEE")]))

        // Line boundaries.
        XCTAssertEqual([.equal("AAA\r\n"), .insert("BBB DDD\r\n"), .equal("BBB EEE")],
                       cleanupSemanticLossless(diffs:
                        [.equal("AAA\r\nBBB"), .insert(" DDD\r\nBBB"), .equal(" EEE")]))

        // Word boundaries.
        XCTAssertEqual([.equal("The "), .insert("cow and the "), .equal("cat.")],
                       cleanupSemanticLossless(diffs:
                        [.equal("The c"), .insert("ow and the c"), .equal("at.")]))

        // Alphanumeric boundaries.

        XCTAssertEqual([.equal("The-"), .insert("cow-and-the-"), .equal("cat.")],
                       cleanupSemanticLossless(diffs:
                        [.equal("The-c"), .insert("ow-and-the-c"), .equal("at.")]))

        // Hitting the start.
        XCTAssertEqual([.delete("a"), .equal("aax")],
                       cleanupSemanticLossless(diffs:
                        [.equal("a"), .delete("a"), .equal("ax")]))

        // Hitting the end.
        XCTAssertEqual([.equal("xaa"), .delete("a")],
                       cleanupSemanticLossless(diffs:
                        [.equal("xa"), .delete("a"), .equal("a")]))

        // Sentence boundaries.
        XCTAssertEqual([.equal("The xxx."), .insert(" The zzz."), .equal(" The yyy.")],
                       cleanupSemanticLossless(diffs:
                        [.equal("The xxx. The "), .insert("zzz. The "), .equal("yyy.")]))
    }

    func testDiffCleanupSemantic() {
        // Cleanup semantically trivial equalities.

        // Null case.
        XCTAssertEqual([],
                       cleanupSemantic(diffs: []))

        // No elimination #1.
        XCTAssertEqual([.delete("ab"), .insert("cd"), .equal("12"), .delete("e")],
                       cleanupSemantic(diffs:
                        [.delete("ab"), .insert("cd"), .equal("12"), .delete("e")]))

        // No elimination #2.

        XCTAssertEqual([.delete("abc"), .insert("ABC"), .equal("1234"), .delete("wxyz")],
                       cleanupSemantic(diffs:
                        [.delete("abc"), .insert("ABC"), .equal("1234"), .delete("wxyz")]))

        // Simple elimination.
        XCTAssertEqual([.delete("abc"), .insert("b")],
                       cleanupSemantic(diffs: [.delete("a"), .equal("b"), .delete("c")]))

        // Backpass elimination.
        XCTAssertEqual([.delete("abcdef"), .insert("cdfg")],
                       cleanupSemantic(diffs:
                        [.delete("ab"), .equal("cd"), .delete("e"), .equal("f"), .insert("g")]))

        // Multiple eliminations.
        XCTAssertEqual([.delete("AB_AB"), .insert("1A2_1A2")],
                       cleanupSemantic(diffs:
                        [.insert("1"), .equal("A"), .delete("B"), .insert("2"), .equal("_"),
                         .insert("1"), .equal("A"), .delete("B"), .insert("2")]))

        // Word boundaries.
        XCTAssertEqual([.equal("The "), .delete("cow and the "), .equal("cat.")],
                       cleanupSemantic(diffs:
                        [.equal("The c"), .delete("ow and the c"), .equal("at.")]))

        // No overlap elimination.
        XCTAssertEqual([.delete("abcxx"), .insert("xxdef")],
                       cleanupSemantic(diffs:
                        [.delete("abcxx"), .insert("xxdef")]))

        // Overlap elimination.
        XCTAssertEqual([.delete("abc"), .equal("xxx"), .insert("def")],
                       cleanupSemantic(diffs:
                        [.delete("abcxxx"), .insert("xxxdef")]))

        // Reverse overlap elimination.
        XCTAssertEqual([.insert("def"), .equal("xxx"), .delete("abc")],
                       cleanupSemantic(diffs:
                        [.delete("xxxabc"), .insert("defxxx")]))

        // Two overlap eliminations.
        XCTAssertEqual([.delete("abcd"), .equal("1212"), .insert("efghi"), .equal("----"),
                        .delete("A"), .equal("3"), .insert("BC")],
                       cleanupSemantic(diffs:
                        [.delete("abcd1212"), .insert("1212efghi"), .equal("----"),
                         .delete("A3"), .insert("3BC")]))
    }
}

#if os(Linux)
    extension SwiftDiffTests {
        static var allTests : [(String, (SwiftDiffTests) -> () throws -> Void)] {
            return [
                ("testDiffCommonPrefix", testDiffCommonPrefix),
                ("testDiffCommonSuffix", testDiffCommonSuffix),
                ("testDiffCommonOverlap", testDiffCommonOverlap),
                ("testDiff", testDiff),
                ("testDiffHalfMatch", testDiffHalfMatch),
                ("testCleanupMerge", testCleanupMerge),
                ("testCleanupSemanticScore", testCleanupSemanticScore),
                ("testCleanupSemanticLossless", testCleanupSemanticLossless),
                ("testDiffCleanupSemantic", testDiffCleanupSemantic),
            ]
        }
    }
#endif
