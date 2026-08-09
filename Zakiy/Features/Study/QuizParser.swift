import Foundation

/// Parses the raw markdown-ish quiz text returned by the backend AI generation endpoint into
/// structured `QuizQuestion` values. The backend emits questions in the form:
///
/// 1. Question text?
/// أ) option one
/// ب) option two
/// ج) option three
/// د) option four
/// الإجابة: أ
enum QuizParser {
    static func parse(_ raw: String) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let blocks = raw.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        for block in blocks {
            let lines = block.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let firstLine = lines.first else { continue }

            let questionText = stripLeadingNumber(firstLine)
            var options: [String] = []
            var correctIndex = 0

            for line in lines.dropFirst() {
                if let range = line.range(of: "الإجابة") ?? line.range(of: "Answer") {
                    let answerPart = line[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: ": )ي"))
                    correctIndex = optionLetterIndex(answerPart)
                } else if let optionText = stripOptionPrefix(line) {
                    options.append(optionText)
                }
            }

            guard !options.isEmpty else { continue }
            questions.append(QuizQuestion(question: questionText, options: options, correctIndex: min(correctIndex, options.count - 1)))
        }

        return questions
    }

    private static func stripLeadingNumber(_ line: String) -> String {
        var text = line
        while let first = text.first, first.isNumber || first == "." || first == ")" || first == " " {
            text.removeFirst()
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    private static let optionPrefixes = ["أ)", "ب)", "ج)", "د)", "ه)", "A)", "B)", "C)", "D)", "E)", "a)", "b)", "c)", "d)", "e)"]

    private static func stripOptionPrefix(_ line: String) -> String? {
        for prefix in optionPrefixes where line.hasPrefix(prefix) {
            return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func optionLetterIndex(_ letter: String) -> Int {
        let arabicLetters = ["أ", "ب", "ج", "د", "ه"]
        let latinLetters = ["A", "B", "C", "D", "E", "a", "b", "c", "d", "e"]
        let trimmed = letter.trimmingCharacters(in: .whitespaces)
        if let index = arabicLetters.firstIndex(where: { trimmed.hasPrefix($0) }) {
            return index
        }
        if let index = latinLetters.firstIndex(where: { trimmed.hasPrefix($0) }) {
            return index % 5
        }
        return 0
    }
}
