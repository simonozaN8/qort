/// Supabase konfigūracija.
/// Produkcijoje naudokite: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xrsewjtkxcudvxyxkpti.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhyc2V3anRreGN1ZHZ4eXhrcHRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5ODMyOTYsImV4cCI6MjA4MTU1OTI5Nn0._V-u9Dscw2yflrw4btcxS5oAfPZvjlu8BydOpjvOz3E',
  );
}
