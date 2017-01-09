import Foundation


extension NSRegularExpression {

    func matches(_ string: String, options: NSRegularExpression.MatchingOptions = []) -> Bool {
        let range = NSRange(location: 0, length: string.unicodeScalars.count)
        return firstMatch(in: string, options: options, range: range) != nil
    }

}
