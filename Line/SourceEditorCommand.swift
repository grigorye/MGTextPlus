//
//  SourceEditorCommand.swift
//  Line
//
//  Created by Tuan Truong on 11/5/16.
//  Copyright © 2016 Tuan Truong. All rights reserved.
//

import Foundation
import XcodeKit
import AppKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    enum CommandDirection {
        case up
        case down
    }
    
    func perform(with invocation: XCSourceEditorCommandInvocation,
                 completionHandler: @escaping (Error?) -> Void ) -> Void {
        guard let textRange = invocation.buffer.selections.firstObject as? XCSourceTextRange,
            invocation.buffer.lines.count > 0 else {
            completionHandler(nil)
            return
        }
        
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            completionHandler(nil)
            return
        }
        
        let targetRange = Range(uncheckedBounds: (lower: textRange.start.line,
                                                  upper: min(textRange.end.line + 1, invocation.buffer.lines.count)))
        
        let indexSet = IndexSet(integersIn: targetRange)
        let selectedLines = invocation.buffer.lines.objects(at: indexSet)
        
        func deleteLines(indexSet: IndexSet) {
            invocation.buffer.lines.removeObjects(at: indexSet)
            let lineSelection = XCSourceTextRange()
            lineSelection.start = XCSourceTextPosition(line: targetRange.lowerBound, column: 0)
            lineSelection.end = XCSourceTextPosition(line: targetRange.lowerBound, column: 0)
            invocation.buffer.selections.setArray([lineSelection])
        }
        
        func clearLines(indexSet: IndexSet) {
            for i in indexSet {
                invocation.buffer.lines[i] = ""
            }
        
            let lineSelection = XCSourceTextRange()
            lineSelection.start = XCSourceTextPosition(line: targetRange.lowerBound, column: 0)
            lineSelection.end = XCSourceTextPosition(line: targetRange.lowerBound, column: 0)
            invocation.buffer.selections.setArray([lineSelection])
        }

        func copyLines(_ lines: [String]) {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(lines.joined(), forType: NSPasteboard.PasteboardType.string)
        }
        
        func duplicateLine(direction: CommandDirection) {
            let lineSelection = XCSourceTextRange()
            
            switch direction {
            case .up:
                lineSelection.start = XCSourceTextPosition(line: textRange.start.line,
                                                           column: textRange.start.column)
                lineSelection.end = XCSourceTextPosition(line: textRange.end.line,
                                                         column: textRange.end.column)
            case .down:
                lineSelection.start = XCSourceTextPosition(line: textRange.start.line + targetRange.count,
                                                           column: textRange.start.column)
                lineSelection.end = XCSourceTextPosition(line: textRange.end.line + targetRange.count,
                                                         column: textRange.end.column)
            }
            
            invocation.buffer.lines.insert(selectedLines, at: indexSet)
            invocation.buffer.selections.setArray([lineSelection])
        }
        
        func notReachingTop() -> Bool {
            return textRange.start.line > 0
        }
        
        func notReachingBottom() -> Bool {
            return textRange.end.line < (invocation.buffer.lines.count - 1)
        }
        
        func moveLine(direction: CommandDirection) {
            let lineIndexesWhereInsertingSelectionAfterMove: IndexSet
            let lineSelection = XCSourceTextRange()
            
            switch direction {
            case .up:
                guard notReachingTop() else { return }
                
                lineIndexesWhereInsertingSelectionAfterMove = IndexSet(indexSet.map { $0 - 1 })
                lineSelection.start = XCSourceTextPosition(line: textRange.start.line - 1,
                                                           column: textRange.start.column)
                lineSelection.end = XCSourceTextPosition(line: textRange.end.line - 1,
                                                         column: textRange.end.column)
            case .down:
                guard notReachingBottom() else { return }
                
                lineIndexesWhereInsertingSelectionAfterMove = IndexSet(indexSet.map { $0 + 1 })
                lineSelection.start = XCSourceTextPosition(line: textRange.start.line + 1,
                                                           column: textRange.start.column)
                lineSelection.end = XCSourceTextPosition(line: textRange.end.line + 1,
                                                         column: textRange.end.column)
            }
            
            invocation.buffer.lines.removeObjects(at: indexSet)
            invocation.buffer.lines.insert(selectedLines, at: lineIndexesWhereInsertingSelectionAfterMove)
            invocation.buffer.selections.setArray([lineSelection])
        }
        
        func joinLines(_ selectedLines: [String]) -> String {
            let openingBracesNotExpectingSpace = "[("
            let closingBracesNonExpectingSpace = "])"
            let newLine = selectedLines.reduce("", { acc, line in
                let separator: String = {
                    if let c = acc.last, openingBracesNotExpectingSpace.contains(c) {
                        return ""
                    }
                    if let c = line.first, closingBracesNonExpectingSpace.contains(c) {
                        return ""
                    }
                    if acc.isEmpty || line.isEmpty {
                        return ""
                    }
                    return " "
                }()
                return acc + separator + line
            })
            return newLine
        }
        
        func insertLine(direction: CommandDirection) {
            if direction == .down && !notReachingBottom() { return }
            
            let firstRow = textRange.start.line
            guard var firstLine = invocation.buffer.lines[firstRow] as? String else { return }
            firstLine = firstLine.trimEnd()
            
            var insertedLine = firstLine.leadingSpaces()
            let insertedRow: Int
            
            switch direction {
            case .up:
                insertedRow = max(firstRow, 0)
            case .down:
                insertedRow = firstRow + 1
                
                if firstLine.hasSuffix("{")
                    || firstLine.hasSuffix("(")
                    || firstLine.hasSuffix(":") {
                    insertedLine = String.spaces(count: invocation.buffer.indentationWidth) + insertedLine
                }
            }
            
            invocation.buffer.lines.insert(insertedLine, at: insertedRow)
            
            let lineSelection = XCSourceTextRange(
                start: XCSourceTextPosition(line: insertedRow, column: insertedLine.count),
                end: XCSourceTextPosition(line: insertedRow, column: insertedLine.count)
            )
            invocation.buffer.selections.setArray([lineSelection])
        }
        
        // Switch all different commands id based which defined in Info.plist
        switch invocation.commandIdentifier {
        case bundleIdentifier + ".DeleteLine":
            deleteLines(indexSet: indexSet)
        case bundleIdentifier + ".MoveLineUp":
            moveLine(direction: .up)
        case bundleIdentifier + ".MoveLineDown":
            moveLine(direction: .down)
        case bundleIdentifier + ".DuplicateLineUp":
            duplicateLine(direction: .up)
        case bundleIdentifier + ".DuplicateLineDown":
            duplicateLine(direction: .down)
        case bundleIdentifier + ".CopyLine":
            guard let lines = selectedLines as? [String] else { break }
            copyLines(lines)
        case bundleIdentifier + ".CutLine":
            guard let lines = selectedLines as? [String] else { break }
            copyLines(lines)
            deleteLines(indexSet: indexSet)
        case bundleIdentifier + ".JoinLines":
            if indexSet.count == 1 {
                guard let currentRow = indexSet.last,
                    currentRow < invocation.buffer.lines.count - 1,
                    let firstLine = invocation.buffer.lines[currentRow] as? String,
                    let secondLine = invocation.buffer.lines[currentRow + 1] as? String
                    else { break }
                
                let newLine = joinLines([firstLine.trimEnd(), secondLine.trimStart()])
                invocation.buffer.lines[currentRow] = newLine
                invocation.buffer.lines.removeObject(at: currentRow + 1)
                
                if textRange.start.column == textRange.end.column {
                    let lineSelection = XCSourceTextRange()
                    lineSelection.start = XCSourceTextPosition(line: textRange.start.line, column: firstLine.count)
                    lineSelection.end = lineSelection.start
                    invocation.buffer.selections.setArray([lineSelection])
                }
            } else if indexSet.count > 1 {
                guard let currentRow = indexSet.first else { return }
                
                let ignoreLastLine = (textRange.end.column == 0) && (textRange.end.line != invocation.buffer.lines.count)
                let selectedLines: [String] = (selectedLines as? [String] ?? [])
                    .enumerated().map { index, line in
                        if index == 0 {
                            return line.trimEnd()
                        } else if index == selectedLines.count - 1 {
                            return line.trimStart()
                        } else {
                            return line.trim()
                        }
                    }
                    .dropLast(ignoreLastLine ? 1 : 0)

                let newLine = joinLines(selectedLines)
                invocation.buffer.lines[currentRow] = newLine
                
                let indexSetToRemove = IndexSet(
                    integersIn: Range(
                        uncheckedBounds: (
                            lower: textRange.start.line + 1,
                            upper: min(textRange.end.line + (ignoreLastLine ? 0 : 1), invocation.buffer.lines.count)
                        )
                    )
                )
                
                deleteLines(indexSet: indexSetToRemove)
                
                let lineSelection = XCSourceTextRange()
                lineSelection.start = XCSourceTextPosition(line: textRange.start.line, column: textRange.start.column)
                lineSelection.end = XCSourceTextPosition(line: textRange.start.line, column: newLine.count - (ignoreLastLine ? 0 : 1))
                invocation.buffer.selections.setArray([lineSelection])
            }
        case bundleIdentifier + ".SplitLineByComma":
            guard let selectedLines = selectedLines as? [String] else { return }
            
            var textArray = selectedLines.flatMap {
                $0.components(separatedBy: ",")
            }
            
            let firstLine = selectedLines[0]
            let firstLineText: String?
            
            if let range: Range<String.Index> = firstLine.range(of: ",") {
                firstLineText = String(firstLine[..<range.lowerBound]) + ","
            } else if let range: Range<String.Index> = firstLine.range(of: "\n") {
                firstLineText = String(firstLine[..<range.lowerBound])
            } else {
                firstLineText = nil
            }
            
            let leadingSpaces: String
            
            if let firstLineText = firstLineText?.trimEnd() {
                textArray[0] = firstLineText
                
                if let index = firstLineText.lastIndex(of: "(") {
                    let distance = firstLineText.distance(to: index)
                    leadingSpaces = String.spaces(count: distance + 1)
                } else if let index = firstLineText.lastIndex(of: "[") {
                    let distance = firstLineText.distance(to: index)
                    leadingSpaces = String.spaces(count: distance + 1)
                } else {
                    leadingSpaces = String.spaces(count: invocation.buffer.indentationWidth)
                        + firstLineText.leadingSpaces()
                }
            } else {
                leadingSpaces = ""
            }
            
            var remainingLines = [String]()
            
            for i in 1..<textArray.count {
                let text = textArray[i].trim()
                
                if !text.isEmpty {
                    remainingLines.append(leadingSpaces + text)
                }
            }
            
            let result = [textArray[0], remainingLines.joined(separator: ",\n")].joined(separator: "\n")
            deleteLines(indexSet: indexSet)
            
            let insertTargetRange = Range(
                uncheckedBounds: (lower: textRange.start.line, upper: textRange.start.line + 1)
            )
            let insertIndexSet = IndexSet(integersIn: insertTargetRange)
            invocation.buffer.lines.insert([result], at: insertIndexSet)
        case bundleIdentifier + ".RemoveEmptyLines":
            var emptyLineIndexArray = [Int]()
            
            for lineIndex in textRange.start.line...textRange.end.line {
                guard lineIndex < invocation.buffer.lines.count - 1,
                    let line = invocation.buffer.lines[lineIndex] as? String
                    else { break }
                
                if line.trim().isEmpty {
                    emptyLineIndexArray.append(lineIndex)
                }
            }
            
            let indexSetToRemove = IndexSet(emptyLineIndexArray)
            deleteLines(indexSet: indexSetToRemove)
        case bundleIdentifier + ".InsertLineAfter":
            insertLine(direction: .down)
        case bundleIdentifier + ".InsertLineBefore":
            insertLine(direction: .up)
        case bundleIdentifier + ".ClearLine":
            clearLines(indexSet: indexSet)
        case bundleIdentifier + ".ClearLineAndPaste":
            clearLines(indexSet: indexSet)
            let pasteboard = NSPasteboard.general
            
            if let pasteboardString = pasteboard.string(forType: .string) {
                if notReachingBottom() {
                    invocation.buffer.lines.removeObject(at: textRange.start.line)
                }
                
                invocation.buffer.lines.insert(pasteboardString.trimEnd(), at: textRange.start.line)
            }
        default:
            break
        }
        
        completionHandler(nil)
    }
    
}
