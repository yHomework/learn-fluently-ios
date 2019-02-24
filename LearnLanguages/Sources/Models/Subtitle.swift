//
//  Subtitles.swift
//  LearnLanguages
//
//  Created by Amir Khorsandi on 12/26/18.
//  Copyright © 2018 Amir Khorsandi. All rights reserved.
//

import Foundation
import SWXMLHash

struct Subtitle {

    // MARK: Constants

    enum ParseError: Error {
        case failed
        case invalidFormat
    }


    // MARK: Properties

    private(set) var items: [SubtitleItem] = []


    // MARK: Life cycle

    public init(fileUrl: URL) {

        do {
            let fileContent = try String(contentsOf: fileUrl, encoding: String.Encoding.utf8)
            do {
                if isXML(fileContent: fileContent) {
                    items = self.parseXMLSub(fileContent)
                } else {
                    items = try self.parseSRTSub(fileContent)
                }
            } catch {
                debugPrint(error)
            }
        } catch {
            debugPrint(error)
        }
    }


    // MARK: Private functions

    private func isXML(fileContent: String) -> Bool {
        return fileContent.starts(with: "<?xml")
    }

    private func parseXMLSub(_ rawXML: String) -> [SubtitleItem] {
        let delay = 0.0
        let xml = SWXMLHash.parse(rawXML)
        var items: [SubtitleItem] = []
        var index = 0
        let texts = xml["transcript"].children
        texts.forEach { xmlIndexer in
            guard let element = xmlIndexer.element,
                let start = element.attribute(by: "start")?.text,
                let duration = element.attribute(by: "dur")?.text else {
                    return
            }
            var end = delay + (Double(start) ?? 0) + (Double(duration) ?? 0)
            if index + 1 < texts.count {
                if let endText = texts[index + 1].element!.attribute(by: "start")?.text {
                    end = delay + (Double(endText) ?? 0) - 0.01
                }
            }

            items.append(
                SubtitleItem(
                    texts: [htmlToText(encodedString: element.text)],
                    start: delay + (Double(start) ?? 0),
                    end: end,
                    index: index + 1
                )
            )
            index += 1
        }
        return items
    }

    private func parseSRTSub(_ rawSub: String) throws -> [SubtitleItem] {
        var allTitles = [SubtitleItem]()
        var components = rawSub.components(separatedBy: "\r\n\r\n")

        // Fall back to \n\n separation
        if components.count == 1 {
            components = rawSub.components(separatedBy: "\n\n")
        }

        for component in components {
            if component.isEmpty {
                continue
            }

            let scanner = Scanner(string: component)

            var indexResult: Int = -99
            var startResult: NSString?
            var endResult: NSString?
            var textResult: NSString?

            let indexScanSuccess = scanner.scanInt(&indexResult)
            let startTimeScanResult = scanner.scanUpToCharacters(from: CharacterSet.whitespaces, into: &startResult)
            let dividerScanSuccess = scanner.scanUpTo("> ", into: nil)
            scanner.scanLocation += 2
            let endTimeScanResult = scanner.scanUpToCharacters(from: CharacterSet.newlines, into: &endResult)
            scanner.scanLocation += 1

            var textLines = [String]()

            // Iterate over text lines
            while scanner.isAtEnd == false {
                let textLineScanResult = scanner.scanUpToCharacters(from: CharacterSet.newlines, into: &textResult)

                guard textLineScanResult else {
                    throw ParseError.invalidFormat
                }

                let plainText = htmlToText(encodedString: textResult! as String)

                if plainText
                    .lowercased()
                    .filter({ char -> Bool in
                        String(char).rangeOfCharacter(from: NSCharacterSet.lowercaseLetters) != nil
                    })
                    .lengthOfBytes(using: .utf8) > 2 {
                    textLines.append(plainText)
                }
            }

            guard indexScanSuccess && startTimeScanResult && dividerScanSuccess && endTimeScanResult else {
                throw ParseError.invalidFormat
            }

            let startTimeInterval: TimeInterval = timeIntervalFromString(startResult! as String)
            let endTimeInterval: TimeInterval = timeIntervalFromString(endResult! as String)

            if !textLines.isEmpty {
                let title = SubtitleItem(texts: textLines, start: startTimeInterval, end: endTimeInterval, index: indexResult)
                allTitles.append(title)
            }
        }

        return allTitles
    }

    private func timeIntervalFromString(_ timeString: String) -> TimeInterval {
        let scanner = Scanner(string: timeString)

        var hoursResult: Int = 0
        var minutesResult: Int = 0
        var secondsResult: NSString?
        var millisecondsResult: NSString?

        // Extract time components from string
        scanner.scanInt(&hoursResult)
        scanner.scanLocation += 1
        scanner.scanInt(&minutesResult)
        scanner.scanLocation += 1
        scanner.scanUpTo(",", into: &secondsResult)
        scanner.scanLocation += 1
        scanner.scanUpToCharacters(from: CharacterSet.newlines, into: &millisecondsResult)

        let secondsString = secondsResult! as String
        let seconds = Int(secondsString)

        let millisecondsString = millisecondsResult! as String
        let milliseconds = Int(millisecondsString)

        let timeInterval: Double = Double(hoursResult) * 3_600 + Double(minutesResult) * 60 + Double(seconds!) + Double(Double(milliseconds!) / 1_000)

        return timeInterval as TimeInterval
    }


    private func htmlToText(encodedString: String) -> String {
        return encodedString.attributedHtmlString?.string ?? ""
        //return (encodedString as NSString).byConvertingHTMLToPlainText()
    }

}

private extension String {

    var utfData: Data {
        return Data(utf8)
    }

    var attributedHtmlString: NSAttributedString? {

        do {
            return try NSAttributedString(
                data: utfData,
                options:
                [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil)
        } catch {
            print("Error:", error)
            return nil
        }
    }
}

private extension NSString {

    func byConvertingHTMLToPlainText() -> String {

        let stopCharacters = CharacterSet(charactersIn: "< \t\n\r\(0x0085)\(0x000C)\(0x2028)\(0x2029)")
        let newLineAndWhitespaceCharacters = CharacterSet(charactersIn: " \t\n\r\(0x0085)\(0x000C)\(0x2028)\(0x2029)")
        let tagNameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let tagNamesNotWhiteSpace = ["a", "b", "i", "q", "span", "em", "strong", "cite", "abbr", "acronym", "label"]

        let result = NSMutableString(capacity: length)
        let scanner = Scanner(string: self as String)
        scanner.charactersToBeSkipped = nil
        scanner.caseSensitive = true
        var str: NSString?
        var tagName: NSString?
        var dontReplaceTagWithSpace = false

        repeat {
            // Scan up to the start of a tag or whitespace
            if scanner.scanUpToCharacters(from: stopCharacters, into: &str), let string = str {
                result.append(string as String)
                str = nil
            }
            // Check if we've stopped at a tag/comment or whitespace
            if scanner.scanString("<", into: nil) {
                // Stopped at a comment, script tag, or other tag
                if scanner.scanString("!--", into: nil) {
                    // Comment
                    scanner.scanUpTo("-->", into: nil)
                    scanner.scanString("-->", into: nil)
                } else if scanner.scanString("script", into: nil) {
                    // Script tag where things don't need escaping!
                    scanner.scanUpTo("</script>", into: nil)
                    scanner.scanString("</script>", into: nil)
                } else {
                    // Tag - remove and replace with space unless it's
                    // a closing inline tag then dont replace with a space
                    if scanner.scanString("/", into: nil) {
                        // Closing tag - replace with space unless it's inline
                        tagName = nil
                        dontReplaceTagWithSpace = false
                        if scanner.scanCharacters(from: tagNameCharacters, into: &tagName),
                            let strongTagName = tagName?.lowercased {
                            tagName = strongTagName as NSString
                            dontReplaceTagWithSpace = tagNamesNotWhiteSpace.contains(strongTagName)
                        }
                        // Replace tag with string unless it was an inline
                        if !dontReplaceTagWithSpace && result.length > 0 && !scanner.isAtEnd {
                            result.append(" ")
                        }
                    }
                    // Scan past tag
                    scanner.scanUpTo(">", into: nil)
                    scanner.scanString(">", into: nil)
                }
            } else {
                // Stopped at whitespace - replace all whitespace and newlines with a space
                if scanner.scanCharacters(from: newLineAndWhitespaceCharacters, into: nil) {
                    if result.length > 0 && !scanner.isAtEnd {
                        result.append(" ") // Dont append space to beginning or end of result
                    }
                }
            }
        } while !scanner.isAtEnd

        // Cleanup

        // Decode HTML entities and return (this isn't included in this gist, but is often important)
        // let retString = (result as String).stringByDecodingHTMLEntities

        // Return
        return result as String
    }

}
