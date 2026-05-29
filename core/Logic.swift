import Foundation

@_cdecl("execute_data_purge")
public func execute_data_purge(cStr: UnsafePointer<CChar>, lang: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
    let date = String(cString: cStr)
    let secretMsg = "Note for \(date): This is a hardware-level encrypted message."
    // 修复：从 unicodeScalars 迭代，避免 Character 无 .value 的编译错误
    let xorData = secretMsg.unicodeScalars.compactMap { UnicodeScalar($0.value ^ 0x07) }
    let result = String(xorData.map { Character($0) })
    return strdup(result)
}
