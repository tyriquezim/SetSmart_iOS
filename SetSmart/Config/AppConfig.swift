import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        if let str = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
           let url = URL(string: str) { return url }
        return URL(string: "https://woynvgflkzbnquhftesv.supabase.co")!
    }()

    static let supabaseAnonKey: String =
        Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String
        ?? "sb_publishable_ybaR21bJy6Wpc3w2Fu6KRw__5O9bkTm"

    static let usdaAPIKey: String =
        Bundle.main.object(forInfoDictionaryKey: "USDAAPIKey") as? String
        ?? "bzFrCTLw8jm6QRMMrt9TdTdNHhR7C99tfrJLRfNM"
}
