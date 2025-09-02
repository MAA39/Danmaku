import Foundation
import SQLite3

/// SQLite に確定チャンクを保存・参照する最小ストア。
/// DB: ~/Library/Application Support/Danmaku/danmaku.sqlite
/// テーブル: chunks(id INTEGER PK, started_at REAL, ended_at REAL, text TEXT)
final class ChunkStore {
    private var db: OpaquePointer?

    /// DBを開き、なければ作成。WALで速度/堅牢さバランス。
    init() throws {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)
            .appendingPathComponent("Danmaku", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let url = dir.appendingPathComponent("danmaku.sqlite")

        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) != SQLITE_OK {
            defer { sqlite3_close(db) }
            throw NSError(domain: "ChunkStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "DBを開けませんでした"])
        }
        exec("PRAGMA journal_mode=WAL;")
        exec("PRAGMA synchronous=NORMAL;")
        exec("""
            CREATE TABLE IF NOT EXISTS chunks(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              started_at REAL NOT NULL,
              ended_at REAL NOT NULL,
              text TEXT NOT NULL
            );
        """)
    }

    deinit { if db != nil { sqlite3_close(db) } }

    /// 1件INSERT（トランザクション不要の単発）
    func insert(text: String, startedAt: Date, endedAt: Date) {
        let sql = "INSERT INTO chunks(started_at, ended_at, text) VALUES(?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_double(stmt, 1, startedAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 2, endedAt.timeIntervalSince1970)
        text.withCString { cstr in
            sqlite3_bind_text(stmt, 3, cstr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    /// デバッグ用：最新10件を返す
    func latest(limit: Int = 10) -> [(Date, String)] {
        var rows: [(Date, String)] = []
        let sql = "SELECT ended_at, text FROM chunks ORDER BY id DESC LIMIT ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        sqlite3_bind_int(stmt, 1, Int32(limit))
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ts = sqlite3_column_double(stmt, 0)
            let txt = String(cString: sqlite3_column_text(stmt, 1))
            rows.append((Date(timeIntervalSince1970: ts), txt))
        }
        sqlite3_finalize(stmt)
        return rows
    }

    // MARK: - Helpers
    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            if let e = err { print("SQLite error:", String(cString: e)) }
            sqlite3_free(err)
        }
    }
}
