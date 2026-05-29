// 不 import Foundation —— Android 交叉编译环境下 Foundation 依赖 SwiftAndroid，会编译失败
// 纯 Swift 实现，零依赖

@_cdecl("execute_data_purge")
public func execute_data_purge(
    cStr: UnsafePointer<CChar>,
    lang: UnsafePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
    // 手动把 C 字符串转成 Swift String
    var date = ""
    var i = 0
    while cStr[i] != 0 {
        date.append(Character(UnicodeScalar(UInt32(cStr[i] > 0 ? cStr[i] : 0 + 256))!))
        i += 1
    }

    let secretMsg = "Note for \(date): This is a hardware-level encrypted message."

    // XOR 0x07 置换
    let xorScalars = secretMsg.unicodeScalars.compactMap { scalar -> UnicodeScalar? in
        UnicodeScalar(scalar.value ^ 0x07)
    }
    let result = String(xorScalars.map { Character($0) })

    // 手动复制到堆上返回给 C 调用方（替代 Foundation 的 strdup）
    let utf8 = Array(result.utf8) + [0]
    let ptr = UnsafeMutablePointer<CChar>.allocate(capacity: utf8.count)
    for (idx, byte) in utf8.enumerated() {
        ptr[idx] = CChar(bitPattern: byte)
    }
    return ptr
}
