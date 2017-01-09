import Foundation


func cleanupMerge(diffs: [Diff]) -> [Diff] {
    var diffs = diffs
    var changes: Bool

    repeat {

        // Add a dummy entry at the end.
        diffs.append(.equal(""))
        var pointer = 0
        var countDelete = 0
        var countInsert = 0
        var textDelete = ""
        var textInsert = ""
        while pointer < diffs.count {
            switch diffs[pointer] {
            case .insert(let text):
                countInsert += 1
                textInsert += text
                pointer += 1
            case .delete(let text):
                countDelete += 1
                textDelete += text
                pointer += 1
            case .equal:
                // Upon reaching an equality, check for prior redundancies.
                if countDelete + countInsert > 1 {
                    if countDelete != 0 && countInsert != 0 {
                        // Factor out any common prefixies.
                        let prefixLength = commonPrefixLength(text1: textInsert, text2: textDelete)
                        if prefixLength != 0 {
                            let index = pointer - countDelete - countInsert
                            let prefix = textInsert.substring(to: prefixLength)
                            if index > 0, case .equal(let text) = diffs[index - 1] {
                                diffs[index - 1] = .equal(text + prefix)
                            } else {
                                diffs.insert(.equal(prefix), at: 0)
                                pointer += 1
                            }
                            textInsert = textInsert.substring(from: prefixLength)
                            textDelete = textDelete.substring(from: prefixLength)
                        }
                        // Factor out any common suffixies.
                        let suffixLength = commonSuffixLength(text1: textInsert, text2: textDelete)
                        if suffixLength != 0 {
                            let insertLength = textInsert.characters.count
                            let deleteLength = textDelete.characters.count

                            let diff = diffs[pointer]
                            diffs[pointer] = diff.with(text:
                                textInsert.substring(from: insertLength - suffixLength)
                                    + diff.text
                            )

                            textInsert = textInsert.substring(to: insertLength - suffixLength)
                            textDelete = textDelete.substring(to: deleteLength - suffixLength)
                        }
                    }
                    // Delete the offending records and add the merged ones.
                    if countDelete == 0 {
                        let index = pointer - countInsert
                        diffs.removeSubrange(index..<(index + countInsert))
                        diffs.insert(.insert(textInsert),
                                     at: index)
                    } else if countInsert == 0 {
                        let index = pointer - countDelete
                        diffs.removeSubrange(index..<(index + countDelete))
                        diffs.insert(.delete(textDelete),
                                     at: index)
                    } else {
                        let index = pointer - countDelete - countInsert
                        diffs.removeSubrange(index..<(index + countDelete + countInsert))
                        diffs.insert(contentsOf: [.delete(textDelete), .insert(textInsert)],
                                     at: index)
                    }

                    pointer = pointer - countDelete - countInsert
                        + (countDelete > 0 ? 1 : 0) + (countInsert > 0 ? 1 : 0) + 1
                } else if pointer != 0, case .equal(let text) = diffs[pointer - 1] {
                    // Merge this equality with the previous one.
                    diffs[pointer - 1] = .equal(text + diffs[pointer].text)
                    diffs.remove(at: pointer)
                } else {
                    pointer += 1
                }
                countInsert = 0
                countDelete = 0
                textDelete = ""
                textInsert = ""
            }
        }

        if diffs.last?.text == "" {
            // Remove the dummy entry at the end.
            diffs.removeLast()
        }

        // Second pass: look for single edits surrounded on both sides by equalities
        // which can be shifted sideways to eliminate an equality.
        // e.g: A<ins>BA</ins>C -> <ins>AB</ins>AC
        changes = false
        pointer = 1
        // Intentionally ignore the first and last element (don't need checking).
        while pointer < diffs.count - 1 {
            if case .equal = diffs[pointer - 1], case .equal = diffs[pointer + 1] {
                // This is a single edit surrounded by equalities.
                let suffixStart = diffs[pointer].text.characters.count
                    - diffs[pointer - 1].text.characters.count
                let suffix = diffs[pointer].text.substring(from: suffixStart)
                let previousDiff = diffs[pointer - 1]
                if suffix == previousDiff.text {
                    // Shift the edit over the previous equality.
                    let diff = diffs[pointer]
                    let nextDiff = diffs[pointer + 1]
                    diffs[pointer] = diff.with(text:
                        previousDiff.text
                            + diff.text.substring(to: diff.text.characters.count
                                - previousDiff.text.characters.count))
                    diffs[pointer + 1] =
                        nextDiff.with(text: previousDiff.text + nextDiff.text)
                    diffs.remove(at: pointer - 1)
                    changes = true
                } else {
                    let diff = diffs[pointer]
                    let nextDiff = diffs[pointer + 1]
                    let length = nextDiff.text.characters.count
                    let prefix = diff.text.substring(to: length)
                    if prefix == nextDiff.text {
                        // Shift the edit over the next equality.
                        diffs[pointer - 1] =
                            previousDiff.with(text: previousDiff.text + nextDiff.text)
                        diffs[pointer] = diffs[pointer].with(text:
                            diffs[pointer].text.substring(from: nextDiff.text.characters.count) +
                                nextDiff.text)
                        diffs.remove(at: pointer + 1)
                        changes = true
                    }
                }
            }
            pointer += 1
        }

        // If shifts were made, the diff needs reordering and another shift sweep.
        // NOTE: instead of recursing, simply loop
    } while changes

    return diffs
}


func cleanupSemanticLossless(diffs: [Diff]) -> [Diff] {
    var diffs = diffs

    // Intentionally ignore the first and last element (don't need checking).
    var pointer = 1
    while pointer < diffs.count - 1 {
        if case .equal(var equality1) = diffs[pointer - 1],
            case .equal(var equality2) = diffs[pointer + 1]
        {
            // This is a single edit surrounded by equalities.
            var edit = diffs[pointer].text

            // First, shift the edit as far left as possible.
            let commonOffset = commonSuffixLength(text1: equality1, text2: edit)
            if commonOffset != 0 {
                let editLength = edit.characters.count
                let commonString = edit.substring(from: editLength - commonOffset)
                equality1 = equality1.substring(to: equality1.characters.count - commonOffset)
                edit = commonString + edit.substring(to: editLength - commonOffset)
                equality2 = commonString + equality2
            }

            // Second, step character by character right, looking for the best fit.
            var bestEquality1 = equality1
            var bestEdit = edit
            var bestEquality2 = equality2
            var bestScore = cleanupSemanticScore(text1: equality1, text2: edit) +
                cleanupSemanticScore(text1: edit, text2: equality2)
            while edit.characters.first == equality2.characters.first {
                if let first = edit.characters.first {
                    equality1.append(first)
                }
                edit = edit.substring(from: 1)
                if let char = equality2.characters.first {
                    edit.append(char)
                }
                equality2 = equality2.substring(from: 1)
                let score = cleanupSemanticScore(text1: equality1, text2: edit) +
                    cleanupSemanticScore(text1: edit, text2: equality2)
                // The >= encourages trailing rather than leading whitespace on edits.
                if score >= bestScore {
                    bestScore = score
                    bestEquality1 = equality1
                    bestEdit = edit
                    bestEquality2 = equality2
                }
            }

            let previousDiff = diffs[pointer - 1]
            if previousDiff.text != bestEquality1 {
                // We have an improvement, save it back to the diff.
                if !bestEquality1.isEmpty {
                    diffs[pointer - 1] = previousDiff.with(text: bestEquality1)
                } else {
                    diffs.remove(at: pointer - 1)
                    pointer -= 1
                }
                diffs[pointer] = diffs[pointer].with(text: bestEdit)
                if !bestEquality2.isEmpty {
                    diffs[pointer + 1] = diffs[pointer + 1].with(text: bestEquality2)
                } else {
                    diffs.remove(at: pointer + 1)
                    pointer -= 1
                }
            }
        }
        pointer += 1
    }
    return diffs
}


fileprivate let blanklineEndRegex =
    try! NSRegularExpression(pattern: "\\n\\r?\\n\\Z", options: [])

fileprivate let blanklineStartRegex =
    try! NSRegularExpression(pattern: "\\A\\r?\\n\\r?\\n", options: [])


func cleanupSemanticScore(text1: String, text2: String) -> Int {
    guard let char1 = text1.unicodeScalars.last,
        let char2 = text2.unicodeScalars.first else
    {
        // Edges are the best.
        return 6
    }

    // Each port of this function behaves slightly differently due to
    // subtle differences in each language's definition of things like
    // 'whitespace'.  Since this function's purpose is largely cosmetic,
    // the choice has been made to use each language's native features
    // rather than force total conformity.

    let nonAlphaNumeric1 = !char1.isAlphanumeric
    let nonAlphaNumeric2 = !char2.isAlphanumeric
    let whitespace1 = nonAlphaNumeric1
        && char1.isWhitespaceOrNewline
    let whitespace2 = nonAlphaNumeric2
        && char2.isWhitespaceOrNewline
    let lineBreak1 = whitespace1
        && char1.isNewline
    let lineBreak2 = whitespace2
        && char2.isNewline
    let blankLine1 = lineBreak1
        && blanklineEndRegex.matches(text1)
    let blankLine2 = lineBreak2
        && blanklineStartRegex.matches(text2)

    if blankLine1 || blankLine2 {
        // Five points for blank lines.
        return 5
    } else if lineBreak1 || lineBreak2 {
        // Four points for line breaks.
        return 4
    } else if nonAlphaNumeric1 && !whitespace1 && whitespace2 {
        // Three points for end of sentences.
        return 3
    } else if whitespace1 || whitespace2 {
        // Two points for whitespace.
        return 2
    } else if nonAlphaNumeric1 || nonAlphaNumeric2 {
        // One point for non-alphanumeric.
        return 1
    }
    return 0
}


public func cleanupSemantic(diffs: [Diff]) -> [Diff] {
    var diffs = diffs

    var changes = false

    // Stack of indices where equalities are found.
    var equalities: [Int] = []
    var equalitiesLength = 0

    // Always equal to diffs[equalities[equalitiesLength - 1]].text
    var lastEquality: String? = nil

    // Index of current position.
    var pointer = 0

    // Number of characters that changed prior to the equality.
    var lengthInsertions1 = 0
    var lengthDeletions1 = 0

    // Number of characters that changed after the equality.
    var lengthInsertions2 = 0
    var lengthDeletions2 = 0

    while pointer < diffs.count {
        let diff = diffs[pointer]
        let diffTextLength = diff.text.characters.count

        if case .equal(let text) = diff {
            // Equality found.
            equalities.append(pointer)
            equalitiesLength += 1
            lengthInsertions1 = lengthInsertions2
            lengthDeletions1 = lengthDeletions2
            lengthInsertions2 = 0
            lengthDeletions2 = 0
            lastEquality = text
        } else {
            // An insertion or deletion.
            if case .insert = diff {
                lengthInsertions2 += diffTextLength
            } else {
                lengthDeletions2 += diffTextLength
            }

            // Eliminate an equality that is smaller or equal to the edits on both
            // sides of it.
            if let equality = lastEquality {
                let length = equality.characters.count
                if length <= max(lengthInsertions1,
                                 lengthDeletions1)
                    && length <= max(lengthInsertions2,
                                     lengthDeletions2)
                {
                    // Duplicate record.
                    let lastEqualityIndex = equalities[equalitiesLength - 1]
                    diffs.insert(.delete(equality),
                                 at: lastEqualityIndex)

                    // Change second copy to insert.
                    diffs[lastEqualityIndex + 1] = .insert(diffs[lastEqualityIndex + 1].text)

                    // Throw away the equality we just deleted.
                    // Throw away the previous equality (it needs to be reevaluated).
                    let deleteCount = 2
                    equalities.removeLast(min(deleteCount, equalitiesLength))
                    equalitiesLength = max(0, equalitiesLength - deleteCount)

                    pointer = equalitiesLength > 0 ? equalities[equalitiesLength - 1] : -1
                    // Reset the counters.
                    lengthInsertions1 = 0
                    lengthDeletions1 = 0
                    lengthInsertions2 = 0
                    lengthDeletions2 = 0
                    lastEquality = nil
                    changes = true
                }
            }
        }
        pointer += 1
    }

    // Normalize the diff.
    if changes {
        diffs = cleanupMerge(diffs: diffs)
    }
    diffs = cleanupSemanticLossless(diffs: diffs)

    // Find any overlaps between deletions and insertions.
    // e.g: <del>abcxxx</del><ins>xxxdef</ins>
    //   -> <del>abc</del>xxx<ins>def</ins>
    // e.g: <del>xxxabc</del><ins>defxxx</ins>
    //   -> <ins>def</ins>xxx<del>abc</del>
    // Only extract an overlap if it is as big as the edit ahead or behind it.
    pointer = 1
    while pointer < diffs.count {

        if case .delete(let deletion) = diffs[pointer - 1],
            case .insert(let insertion) = diffs[pointer]
        {
            let deletionLength = deletion.characters.count
            let insertionLength = insertion.characters.count

            let overlapLength1 = commonOverlapLength(text1: deletion, text2: insertion)
            let overlapLength2 = commonOverlapLength(text1: insertion, text2: deletion)
            if overlapLength1 >= overlapLength2 {
                if Float(overlapLength1) >= Float(deletionLength) / 2.0
                    || Float(overlapLength1) >= Float(insertionLength) / 2.0
                {
                    // Overlap found.  Insert an equality and trim the surrounding edits.
                    diffs.insert(.equal(insertion.substring(to: overlapLength1)),
                                 at: pointer)
                    diffs[pointer - 1] =
                        .delete(deletion.substring(to: deletionLength - overlapLength1))
                    diffs[pointer + 1] = .insert(insertion.substring(from: overlapLength1))
                    pointer += 1
                }
            } else {
                if Float(overlapLength2) >= Float(deletionLength) / 2.0
                    || Float(overlapLength2) >= Float(insertionLength) / 2.0
                {
                    // Reverse overlap found.
                    // Insert an equality and swap and trim the surrounding edits.
                    diffs.insert(.equal(deletion.substring(to: overlapLength2)),
                                 at: pointer)
                    diffs[pointer - 1] =
                        .insert(insertion.substring(to: insertionLength - overlapLength2))
                    diffs[pointer + 1] =
                        .delete(deletion.substring(from: overlapLength2))
                    pointer += 1
                }
            }
            pointer += 1
        }
        pointer += 1
    }
    
    return diffs
}
