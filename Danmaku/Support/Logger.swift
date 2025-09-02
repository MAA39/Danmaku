import os.log

enum Log {
    static let audio   = Logger(subsystem: "com.masakazu.Danmaku", category: "audio")
    static let stt     = Logger(subsystem: "com.masakazu.Danmaku", category: "stt")
    static let overlay = Logger(subsystem: "com.masakazu.Danmaku", category: "overlay")
    static let db      = Logger(subsystem: "com.masakazu.Danmaku", category: "db")
}

extension Log {
    static let input   = Logger(subsystem: "com.masakazu.Danmaku", category: "input")
}
