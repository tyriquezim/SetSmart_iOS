import Supabase

enum SupabaseClientProvider {
    static let shared = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                flowType: .implicit
            )
        )
    )
}
