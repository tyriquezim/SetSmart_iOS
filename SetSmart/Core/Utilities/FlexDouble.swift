import Foundation

/// Decodes a Double from either a JSON number or a JSON string.
/// PostgREST sometimes returns `numeric` columns as strings.
struct FlexDouble: Codable, Sendable {
    let value: Double?

    init(_ v: Double?) { value = v }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil()                                              { value = nil; return }
        if let d = try? c.decode(Double.self)                         { value = d;   return }
        if let s = try? c.decode(String.self), let d = Double(s)      { value = d;   return }
        value = nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if let v = value { try c.encode(v) } else { try c.encodeNil() }
    }
}
