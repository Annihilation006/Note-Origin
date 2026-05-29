@_cdecl("execute_data_purge")
public func execute_data_purge(
    cStr: UnsafePointer<CChar>,
    lang: UnsafePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
    // CChar 是 Int8，转 UInt8 再转 UInt32 避免负数问题
    var date = ""
    var i = 0
    while cStr[i] != 0 {
        let byte = UInt8(bitPattern: cStr[i])
        date.append(Character(UnicodeScalar(UInt32(byte))!))
        i += 1
    }

    let secretMsg = "Note for \(date): This is a hardware-level encrypted message."

    let xorScalars = secretMsg.unicodeScalars.compactMap { scalar -> UnicodeScalar? in
        UnicodeScalar(scalar.value ^ 0x07)
    }
    let result = String(xorScalars.map { Character($0) })

    let utf8 = Array(result.utf8) + [0]
    let ptr = UnsafeMutablePointer<CChar>.allocate(capacity: utf8.count)
    for (idx, byte) in utf8.enumerated() {
        ptr[idx] = CChar(bitPattern: byte)
    }
    return ptr
}
