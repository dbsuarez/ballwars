/// Supabase project for user-made ball groups (see supabase/migrations).
/// Both values are public by design: they ship inside the app, and the
/// database's row level security decides what each user may do. Never put
/// the secret / service_role key here.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://ehepdokwjmudssgkxoij.supabase.co';
  static const String publishableKey = 'sb_publishable_IfBSXF1hJS4K086RNVyG4Q_Xx9d6pED';

  /// Storage bucket holding uploaded ball images (`<owner uid>/<file>.png`).
  static const String imageBucket = 'ball-images';
}
