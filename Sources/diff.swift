import Foundation


public enum Diff: Equatable {
    case equal(String)
    case insert(String)
    case delete(String)

    public var text: String {
        switch self {
        case .equal(let text):
            return text
        case .insert(let text):
            return text
        case .delete(let text):
            return text
        }
    }

    public func with(text: String) -> Diff {
        switch self {
        case .equal:
            return .equal(text)
        case .insert:
            return .insert(text)
        case .delete:
            return .delete(text)
        }
    }

    public static func == (lhs: Diff, rhs: Diff) -> Bool {
        switch (lhs, rhs) {
        case (.equal(let text1), .equal(let text2)):
            return text1 == text2
        case (.insert(let text1), .insert(let text2)):
            return text1 == text2
        case (.delete(let text1), .delete(let text2)):
            return text1 == text2
        default:
            return false
        }
    }
}


func diffEqual(text1: String, text2: String) -> [Diff]? {
    // Check for equality (speedup).
    if text1 == text2 {
        if text1.isEmpty {
            return []
        }
        return [.equal(text1)]
    }
    
    return nil
}


public func diff(text1: String, text2: String,
                 timeout: CFTimeInterval? = nil) -> [Diff] {

    let performHalfMatch = timeout == nil || (timeout ?? 0) > 0
    let deadline = timeout?.advanced(by: CFAbsoluteTimeGetCurrent())
    return diff(text1: text1, text2: text2,
                performHalfMatch: performHalfMatch,
                deadline: deadline)
}


func diff(text1: String, text2: String,
          performHalfMatch: Bool,
          deadline: CFAbsoluteTime?) -> [Diff] {

    var text1 = text1
    var text2 = text2

    if let diffs = diffEqual(text1: text1, text2: text2) {
        return diffs
    }

    // Trim off common prefix (speedup).
    let prefixLength = commonPrefixLength(text1: text1, text2: text2)
    let commonPrefix = text1.substring(to: prefixLength)
    text1 = text1.substring(from: prefixLength)
    text2 = text2.substring(from: prefixLength)

    // Trim off common suffix (speedup).
    let suffixLength = commonSuffixLength(text1: text1, text2: text2)
    // NOTE: length of text1 and text2 without prefix
    let length1 = text1.characters.count
    let length2 = text2.characters.count
    let commonSuffix = text1.substring(from: length1 - suffixLength)
    text1 = text1.substring(to: length1 - suffixLength)
    text2 = text2.substring(to: length2 - suffixLength)

    var diffs = diffMiddle(text1: text1, length1: length1 - suffixLength,
                           text2: text2, length2: length2 - suffixLength,
                           performHalfMatch: performHalfMatch,
                           deadline: deadline)

    // Restore the prefix.
    if !commonPrefix.isEmpty {
        diffs.insert(.equal(commonPrefix), at: 0)
    }

    // Restore and suffix.
    if !commonSuffix.isEmpty {
        diffs.append(.equal(commonSuffix))
    }

    return cleanupMerge(diffs: diffs)
}


func diffMiddle(text1: String, length1: Int,
                text2: String, length2: Int,
                performHalfMatch: Bool,
                deadline: CFAbsoluteTime?) -> [Diff] {

    // Just added some text? (speedup).
    if text1.isEmpty {
        return [.insert(text2)]
    }

    // Just deleted some text? (speedup).
    if text2.isEmpty {
        return [.delete(text1)]
    }

    let (longText, shortText, shortTextLength) =
        length1 > length2
            ? (text1, text2, length2)
            : (text2, text1, length1)

    if let range = longText.range(of: shortText) {
        // Shorter text is inside the longer text (speedup).
        let commonStart = range.lowerBound
        let prefix = longText.substring(to: commonStart)
        let suffixStart = longText.index(commonStart,
                                         offsetBy: shortTextLength)
        let suffix = longText.substring(from: suffixStart)
        if length1 <= length2 {
            return [.insert(prefix), .equal(shortText), .insert(suffix)]
        } else {
            // Swap insertions for deletions if diff is reversed.
            return [.delete(prefix), .equal(shortText), .delete(suffix)]
        }
    }

    if shortTextLength == 1 {
        // Single character string.
        // After the previous speedup, the character can't be an equality.
        return [.delete(text1), .insert(text2)]
    }

    // Don't risk returning a non-optimal diff if we have unlimited time.
    if performHalfMatch,
        let halfMatch = halfMatch(text1: text1, text2: text2,
                                  length1: length1, length2: length2)
    {
        let diffsA = diff(text1: halfMatch.text1A, text2: halfMatch.text2A,
                          performHalfMatch: performHalfMatch,
                          deadline: deadline)
        let diffsB = diff(text1: halfMatch.text1B, text2: halfMatch.text2B,
                          performHalfMatch: performHalfMatch,
                          deadline: deadline)
        let equal = [Diff.equal(halfMatch.midCommon)]
        return diffsA + equal + diffsB
    }

    return bisect(text1: text1, length1: length1,
                  text2: text2, length2: length2,
                  performHalfMatch: performHalfMatch,
                  deadline: deadline)
}


struct HalfMatch {
    let text1A: String
    let text1B: String
    let text2A: String
    let text2B: String
    let midCommon: String
}


extension HalfMatch: Equatable {}


func == (lhs: HalfMatch, rhs: HalfMatch) -> Bool {
    return lhs.text1A == rhs.text1A
        && lhs.text1B == rhs.text1B
        && lhs.text2A == rhs.text2A
        && lhs.text2B == rhs.text2B
        && lhs.midCommon == rhs.midCommon
}


func halfMatch(text1: String, text2: String,
               length1: Int? = nil, length2: Int? = nil) -> HalfMatch? {

    let length1 = length1 ?? text1.characters.count
    let length2 = length2 ?? text2.characters.count

    let (longText, longLength, shortText, shortLength) = length1 > length2
        ? (text1, length1, text2, length2)
        : (text2, length2, text1, length1)

    if longLength < 4 || shortLength * 2 < longLength {
        // Pointless.
        return nil
    }

    // First check if the second quarter is the seed for a half-match.
    // Then check again based on the third quarter.

    let halfMatches = (
        halfMatchI(longText: longText, longLength: longLength,
                   shortText: shortText, i: (longLength + 3) / 4),
        halfMatchI(longText: longText, longLength: longLength,
                   shortText: shortText, i: (longLength + 1) / 2)
    )

    let finalHalfMatch: HalfMatch
    switch halfMatches {
        case (nil, nil):
            return nil
        case (.some(let halfMatch), nil):
            finalHalfMatch = halfMatch
        case (nil, .some(let halfMatch)):
            finalHalfMatch = halfMatch
        case (.some(let halfMatch1), .some(let halfMatch2)):
            // Both matched.  Select the longest.
            let firstIsLonger =
                halfMatch1.midCommon.characters.count > halfMatch2.midCommon.characters.count
            finalHalfMatch = firstIsLonger ? halfMatch1 : halfMatch2
    }

    // A half-match was found, sort out the return data.
    if length1 > length2 {
        return finalHalfMatch
    } else {
        return HalfMatch(text1A: finalHalfMatch.text2A, text1B: finalHalfMatch.text2B,
                         text2A: finalHalfMatch.text1A, text2B: finalHalfMatch.text1B,
                         midCommon: finalHalfMatch.midCommon)
    }
}


func halfMatchI(longText: String, longLength: Int, shortText: String, i: Int) -> HalfMatch? {

    // Start with a 1/4 length substring at position i as a seed.
    let seed = longText[i..<(i + longLength / 4)]

    var currentOffset = -1
    var bestCommon = ""
    var bestCommonLength = 0
    var bestLongTextA = ""
    var bestLongTextB = ""
    var bestShortTextA = ""
    var bestShortTextB = ""

    while let offset = shortText.index(of: seed, from: currentOffset + 1) {
        let prefixLength = commonPrefixLength(text1: longText.substring(from: i),
                                              text2: shortText.substring(from: offset))
        let suffixLength = commonSuffixLength(text1: longText.substring(to: i),
                                              text2: shortText.substring(to: offset))
        if bestCommonLength < suffixLength + prefixLength {
            bestCommon = shortText[(offset - suffixLength)..<offset]
                + shortText[offset..<(offset + prefixLength)]
            bestCommonLength = bestCommon.characters.count
            bestLongTextA = longText.substring(to: i - suffixLength)
            bestLongTextB = longText.substring(from: i + prefixLength)
            bestShortTextA = shortText.substring(to: offset - suffixLength)
            bestShortTextB = shortText.substring(from: offset + prefixLength)
        }

        currentOffset = offset
    }

    guard bestCommonLength * 2 >= longLength else {
        return nil
    }

    return HalfMatch(
        text1A: bestLongTextA,
        text1B: bestLongTextB,
        text2A: bestShortTextA,
        text2B: bestShortTextB,
        midCommon: bestCommon
    )
}


func bisect(text1: String, length1: Int,
            text2: String, length2: Int,
            performHalfMatch: Bool,
            deadline: CFAbsoluteTime?) -> [Diff] {

    let maxD = (length1 + length2 + 1) / 2
    let vOffset = maxD
    let vLength = 2 * maxD

    var v1 = [Int](repeating: -1, count: vLength)
    var v2 = [Int](repeating: -1, count: vLength)

    v1[vOffset + 1] = 0
    v2[vOffset + 1] = 0

    let delta = length1 - length2
    // If the total number of characters is odd, then the front path will
    // collide with the reverse path.
    let front = delta % 2 != 0
    // Offsets for start and end of k loop.
    // Prevents mapping of space beyond the grid.
    var k1Start = 0
    var k1End = 0
    var k2Start = 0
    var k2End = 0

    for d in 0..<maxD {

        // Bail out if deadline is reached.
        if let deadline = deadline {
            guard CFAbsoluteTimeGetCurrent() < deadline else {
                break
            }
        }

        // Walk the front path one step.
        // NOTE: can't use stride, k1end is increased

        var k1 = -d + k1Start
        while k1 <= d - k1End {

            let k1Offset = vOffset + k1
            var x1 = k1 == -d || (k1 != d && v1[k1Offset - 1] < v1[k1Offset + 1])
                ? v1[k1Offset + 1]
                : v1[k1Offset - 1] + 1
            var y1 = x1 - k1
            while x1 < length1 && y1 < length2
                && text1[x1] == text2[y1]
            {
                x1 += 1
                y1 += 1
            }

            v1[k1Offset] = x1
            if x1 > length1 {
                // Ran off the right of the graph.
                k1End += 2
            } else if y1 > length2 {
                // Ran off the bottom of the graph.
                k1Start += 2
            } else if front {
                let k2Offset = vOffset + delta - k1
                if k2Offset >= 0 && k2Offset < vLength && v2[k2Offset] != -1 {
                    // Mirror x2 onto top-left coordinate system.
                    let x2 = length1 - v2[k2Offset]
                    if x1 >= x2 {
                        // Overlap detected.
                        return bisectSplit(text1: text1, text2: text2,
                                           x: x1, y: y1,
                                           performHalfMatch: performHalfMatch,
                                           deadline: deadline)
                    }
                }
            }

            k1 += 2
        }

        // Walk the reverse path one step.
        var k2 = -d + k2Start
        while k2 <= d - k2End {

            let k2Offset = vOffset + k2
            var x2 = k2 == -d || (k2 != d && v2[k2Offset - 1] < v2[k2Offset + 1])
                ? v2[k2Offset + 1]
                : v2[k2Offset - 1] + 1

            var y2 = x2 - k2
            while x2 < length1 && y2 < length2
                && text1[length1 - x2 - 1] == text2[length2 - y2 - 1]
            {
                    x2 += 1
                    y2 += 1
            }
            v2[k2Offset] = x2
            if x2 > length1 {
                // Ran off the left of the graph.
                k2End += 2
            } else if y2 > length2 {
                // Ran off the top of the graph.
                k2Start += 2
            } else if !front {
                let k1Offset = vOffset + delta - k2
                if k1Offset >= 0 && k1Offset < vLength && v1[k1Offset] != -1 {
                    let x1 = v1[k1Offset]
                    let y1 = vOffset + x1 - k1Offset
                    // Mirror x2 onto top-left coordinate system.
                    x2 = length1 - x2
                    if x1 >= x2 {
                        // Overlap detected.
                        return bisectSplit(text1: text1, text2: text2,
                                           x: x1, y: y1,
                                           performHalfMatch: performHalfMatch,
                                           deadline: deadline)
                    }
                }
            }
            k2 += 2
        }
    }

    // Diff took too long and hit the deadline or
    // number of diffs equals number of characters, no commonality at all.
    return [.delete(text1), .insert(text2)]
}


func bisectSplit(text1: String, text2: String, x: Int, y: Int,
                 performHalfMatch: Bool,
                 deadline: CFAbsoluteTime?) -> [Diff] {

    let text1A = text1.substring(to: x)
    let text2A = text2.substring(to: y)
    let text1B = text1.substring(from: x)
    let text2B = text2.substring(from: y)

    // Compute both diffs serially.
    let diffsA = diff(text1: text1A, text2: text2A,
                      performHalfMatch: performHalfMatch,
                      deadline: deadline)
    let diffsB = diff(text1: text1B, text2: text2B,
                      performHalfMatch: performHalfMatch,
                      deadline: deadline)

    return diffsA + diffsB
}

