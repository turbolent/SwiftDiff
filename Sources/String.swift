import Foundation


extension String {

    subscript(range: Range<Int>) -> String {
        guard !range.isEmpty else {
            return ""
        }

        let startIndex = index(self.startIndex, offsetBy: range.lowerBound)
        let endIndex = index(self.startIndex, offsetBy: range.upperBound - 1)
        return self[startIndex...endIndex]
    }

    func substring(to offset: Int) -> String {
        let index = self.index(startIndex,
                               offsetBy: max(offset, 0),
                               limitedBy: endIndex)
        return substring(to: index ?? endIndex)
    }

    func substring(from offset: Int) -> String {
        let index = self.index(startIndex,
                               offsetBy: max(offset, 0),
                               limitedBy: endIndex)
        return substring(from: index ?? endIndex)
    }

    func substring(last count: Int) -> String {
        let index = self.index(endIndex,
                               offsetBy: min(-count, 0),
                               limitedBy: startIndex)
        return substring(from: index ?? startIndex)
    }

    func index(of: String, from: Int = 0) -> Int? {
        let startIndex = index(self.startIndex, offsetBy: from)

        guard let range = self.range(of: of,
                                     options: [],
                                     range: startIndex..<endIndex) else {
            return nil
        }

        return characters.distance(from: self.startIndex,
                                   to: range.lowerBound)
    }
}
