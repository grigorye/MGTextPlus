//
//  SourceEditorCommand.swift
//  EditorPlus
//
//  Created by Tuan Truong on 11/7/16.
//  Copyright © 2016 Tuan Truong. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        guard let textRange = invocation.buffer.selections.firstObject as? XCSourceTextRange,
            invocation.buffer.lines.count > 0 else {
                completionHandler(nil)
                return
        }
        
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            completionHandler(nil)
            return
        }
        
        let targetRange = Range(uncheckedBounds: (lower: textRange.start.line, upper: min(textRange.end.line + 1, invocation.buffer.lines.count)))
        let indexSet = IndexSet(integersIn: targetRange)
        let selectedLines = invocation.buffer.lines.objects(at: indexSet)
        
        func deleteLines(indexSet: IndexSet) {
            invocation.buffer.lines.removeObjects(at: indexSet)
            let lineSelection = XCSourceTextRange()
            lineSelection.start = XCSourceTextPosition(line: targetRange.lowerBound, column: 0)
            lineSelection.end = lineSelection.start
            invocation.buffer.selections.setArray([lineSelection])
        }
        
        func className() -> String? {
            let pattern = "class ([^:<{ ]+)"
            for line in invocation.buffer.lines as! [String] {
                let groups = line.capturedGroups(withRegex: pattern)
                if let className = groups.first, !className.isEmpty {
                    return className
                }
            }
            return nil
        }
        
        func spaces() -> String {
            return Array<String>(repeating: " ", count: invocation.buffer.indentationWidth).joined()
        }
        
        switch invocation.commandIdentifier {
        case bundleIdentifier + ".RemoveComment":
            var commentIndexArray = [Int]()
            for lineIndex in textRange.start.line...textRange.end.line {
                guard lineIndex < invocation.buffer.lines.count else {
                    break
                }
                let line = invocation.buffer.lines[lineIndex] as! String
                if line.trim().hasPrefix("//") {
                    commentIndexArray.append(lineIndex)
                }
                else if line.contains("//") {
                    invocation.buffer.lines[lineIndex] = line.removeComment().trimEnd()
                }
            }
            if commentIndexArray.count > 0 {
                let indexSetToRemove = IndexSet(commentIndexArray)
                deleteLines(indexSet: indexSetToRemove)
            }
        case bundleIdentifier + ".AddClassExtension":
            if let className = className() {
                var extensionName: String
                if selectedLines.count == 1,
                    let name = (selectedLines[0] as? String)?.trim(),
                    !name.isEmpty {
                    extensionName = name
                }
                else {
                    extensionName = "<#Delegate#>"
                }
                let ext = "// MARK: - \(extensionName)" + "\n" + "extension \(className): \(extensionName) {\n\(spaces())\n}"
                deleteLines(indexSet: indexSet)
                let insertTargetRange = Range(uncheckedBounds: (lower: textRange.start.line, upper: textRange.start.line + 1))
                let insertIndexSet = IndexSet(integersIn: insertTargetRange)
                invocation.buffer.lines.insert([ext], at: insertIndexSet)
                
                let lineSelection = XCSourceTextRange()
                lineSelection.start = XCSourceTextPosition(line: insertTargetRange.lowerBound + 2, column: invocation.buffer.indentationWidth)
                lineSelection.end = lineSelection.start
                invocation.buffer.selections.setArray([lineSelection])
            }
        case bundleIdentifier + ".AddClassDelegate":
            if let className = className() {
                let delegate = "protocol \(className)Delegate: class {\n\(spaces())\n}"
                deleteLines(indexSet: indexSet)
                let insertTargetRange = Range(uncheckedBounds: (lower: textRange.start.line, upper: textRange.start.line + 1))
                let insertIndexSet = IndexSet(integersIn: insertTargetRange)
                invocation.buffer.lines.insert([delegate], at: insertIndexSet)
                
                let lineSelection = XCSourceTextRange()
                lineSelection.start = XCSourceTextPosition(line: insertTargetRange.lowerBound + 1, column: invocation.buffer.indentationWidth)
                lineSelection.end = lineSelection.start
                invocation.buffer.selections.setArray([lineSelection])
            }

            break
        default:
            break
        }
        
        completionHandler(nil)
    }
    
}


// MARK: - Extension
extension String {
    
}
