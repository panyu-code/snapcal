import SwiftUI

// MARK: - 搜索关键词高亮 (抖音式: 所有命中处品牌绿)

extension Text {

    /// 命中部分品牌绿高亮, 其余保持调用方样式
    /// - Parameter text: 原始文本 (如食物名称)
    /// - Parameter keyword: 搜索关键词, 为空时原样返回
    static func highlighted(_ text: String, keyword: String) -> Text {
        guard !keyword.isEmpty else { return Text(text) }
        var attr = AttributedString(text)
        var cursor = attr.startIndex
        while cursor < attr.endIndex {
            let sub = attr[cursor..<attr.endIndex]
            guard let hit = sub.range(of: keyword, options: .caseInsensitive) else { break }
            attr[hit].foregroundColor = .brandGreen
            cursor = hit.upperBound
        }
        return Text(attr)
    }
}
