import Foundation

/// A minimal .zip writer with no compression. An .xlsx file is a zip of XML files,
/// and this is all it needs.
struct ZipWriter {
    private struct Entry {
        let name: Data
        let size: UInt32
        let crc: UInt32
        let offset: UInt32
    }

    private var entries: [Entry] = []
    private var body = Data()

    /// 1 January 1980, the earliest date a zip file can record.
    private let dosDate: UInt16 = 0x0021
    private let dosTime: UInt16 = 0
    /// Bit 11: file names are UTF-8.
    private let flags: UInt16 = 0x0800

    mutating func add(_ path: String, _ data: Data) {
        let name = Data(path.utf8)
        let entry = Entry(name: name, size: UInt32(data.count), crc: CRC32.checksum(data), offset: UInt32(body.count))
        body.appendLE(UInt32(0x0403_4b50))  // local file header
        body.appendLE(UInt16(20))           // version needed
        body.appendLE(flags)
        body.appendLE(UInt16(0))            // stored, not compressed
        body.appendLE(dosTime)
        body.appendLE(dosDate)
        body.appendLE(entry.crc)
        body.appendLE(entry.size)           // compressed size
        body.appendLE(entry.size)           // uncompressed size
        body.appendLE(UInt16(name.count))
        body.appendLE(UInt16(0))            // extra field length
        body.append(name)
        body.append(data)
        entries.append(entry)
    }

    mutating func add(_ path: String, _ text: String) {
        add(path, Data(text.utf8))
    }

    func finish() -> Data {
        var out = body
        let directoryStart = UInt32(out.count)
        for entry in entries {
            out.appendLE(UInt32(0x0201_4b50))   // central directory header
            out.appendLE(UInt16(20))            // version made by
            out.appendLE(UInt16(20))            // version needed
            out.appendLE(flags)
            out.appendLE(UInt16(0))             // stored
            out.appendLE(dosTime)
            out.appendLE(dosDate)
            out.appendLE(entry.crc)
            out.appendLE(entry.size)
            out.appendLE(entry.size)
            out.appendLE(UInt16(entry.name.count))
            out.appendLE(UInt16(0))             // extra field length
            out.appendLE(UInt16(0))             // comment length
            out.appendLE(UInt16(0))             // disk number
            out.appendLE(UInt16(0))             // internal attributes
            out.appendLE(UInt32(0))             // external attributes
            out.appendLE(entry.offset)
            out.append(entry.name)
        }
        let directorySize = UInt32(out.count) - directoryStart
        out.appendLE(UInt32(0x0605_4b50))       // end of central directory
        out.appendLE(UInt16(0))
        out.appendLE(UInt16(0))
        out.appendLE(UInt16(entries.count))
        out.appendLE(UInt16(entries.count))
        out.appendLE(directorySize)
        out.appendLE(directoryStart)
        out.appendLE(UInt16(0))                 // comment length
        return out
    }
}

extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        let bytes = Swift.withUnsafeBytes(of: &little) { Array($0) }
        self.append(contentsOf: bytes)
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}
