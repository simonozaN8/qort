# QORT – Supabase diegimo instrukcijos

Projektas: **https://xrsewjtkxcudvxyxkpti.supabase.co**

Atlikite žingsnius **eilės tvarka**. Jei kažkas neveikia – sustokite ir patikrinkite klaidą SQL Editor lange (apačioje raudonas tekstas).

---

## 1. Prisijunkite prie Supabase

1. Eikite į [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Atidarykite projektą **xrsewjtkxcudvxyxkpti**
3. Kairėje meniu: **SQL Editor** → **New query**

---

## 2. Paleiskite migracijas (viena po kitos)

Kiekvieną failą atidarykite iš aplanko `supabase/migrations/`, nukopijuokite **visą turinį**, įklijuokite į SQL Editor ir spauskite **Run** (arba Ctrl+Enter).

| Eilė | Failas | Ką daro |
|------|--------|---------|
| 1 | `20260521000001_functions.sql` | RPC funkcijos (XP, RP, auto-complete) |
| 2 | `20260521000002_indexes.sql` | Indeksai greitesnėms užklausoms |
| 3 | `20260521000003_triggers.sql` | Profilis registruojantis + XP po mačo |
| 4 | `20260521000004_rls.sql` | RLS saugumo politikos |
| 5 | `20260521000005_cron.sql` | Auto-patvirtinimas kas 10 min (reikia pg_cron) |
| 6 | `20260521000006_storage.sql` | Storage bucket politikos |
| 7 | `20260521000007_performance.sql` | Papildomi indeksai greičiui (daug vartotojų) |
| 8 | `20260521000008_missing_columns.sql` | Jei terminalas: `updated_at` / `rp_history` does not exist |
| 9 | `20260521000009_sports_catalog_phase1.sql` | Universalus sportų katalogas (Fazė 1) |
| — | `seed_sports_catalog.sql` | **Po 9** — 16+ mėgėjų sportų šakų |
| 10 | `20260521000010_tournament_team_registration.sql` | Komandų registracija turnyruose (`team_id`) |
| 11 | `20260521000011_event_organizer_approval.sql` | Mokama organizatoriaus paslauga + `approval_status` |

**Alternatyva (vienas kartas):** paleiskite `supabase/apply_all.sql` – viskas iš eilės viename faile.

### Organizuoti renginį (per programėlės „+“)

- Naudotojas siunčia **paraišką** (`approval_status: pending`, `status: pending`).
- Viešame turnyrų sąraše rodomi tik **`approval_status = approved`** ir **`status = open`** renginiai.
- **Partner Dashboard** (profilis → skydelis): skiltis **Paraiškos renginiams** — patvirtinti / atmesti.
- Mokėjimas (**49 €**) kol kas suderinamas su komanda rankiniu būdu (`payment_status`); Stripe — vėliau.

Po kiekvieno failo turėtumėte matyti: **Success. No rows returned**.

---

## 3. Įjunkite pg_cron (auto-patvirtinimui)

1. Dashboard → **Database** → **Extensions**
2. Ieškokite **pg_cron** → spauskite **Enable**
3. Grįžkite į SQL Editor ir paleiskite `20260521000005_cron.sql` dar kartą (jei pirmą kartą metė klaidą)

> Jei pg_cron negalimas (nemokamas planas) – auto-patvirtinimas veiks tik per programėlę (`MatchAutoCompleteService`). Tai OK development režimui.

---

## 4. Sukurkite Storage bucket'us

Dashboard → **Storage** → **New bucket**:

| Bucket pavadinimas | Public? |
|--------------------|---------|
| `avatars` | Taip (public) |
| `images` | Taip |
| `team-logos` | Taip |
| `tournament-images` | Taip |

Po sukūrimo paleiskite `20260521000006_storage.sql`.

---

## 5. Auth nustatymai

Dashboard → **Authentication** → **Providers** → **Email**:

- Įjunkite **Email** provider
- Development: galite išjungti **Confirm email** (kad registracija veiktų iš karto)
- Production: **įjunkite** Confirm email

Dashboard → **Authentication** → **URL Configuration**:

- **Site URL:** jūsų web adresas (pvz. `https://qort.lt` arba `http://localhost:3000`)
- **Redirect URLs:** pridėkite `io.supabase.flutter://login-callback/` (mobile) ir web URL

---

## 6. Patikrinkite, ar RPC veikia

SQL Editor → New query:

```sql
-- Turėtų grąžinti 0 (nieko nekeičia testui)
SELECT public.increment_profile_xp(auth.uid(), 0);

-- Sąrašas funkcijų
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public' AND routine_name LIKE '%profile%' OR routine_name LIKE '%match%';
```

Jei `increment_profile_xp` nerandama – pakartokite žingsnį 2, failas `000001_functions.sql`.

---

## 7. Flutter aplikacijos raktai

### Development (dabartiniai raktai faile)

Jau veikia su numatytaisiais `lib/core/config/supabase_config.dart`.

### Production build

```bash
flutter build apk --dart-define=SUPABASE_URL=https://xrsewjtkxcudvxyxkpti.supabase.co --dart-define=SUPABASE_ANON_KEY=JŪSŲ_ANON_KEY

flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Anon key rasite: Dashboard → **Project Settings** → **API** → `anon` `public`.

> **Niekada** neįkelkite `service_role` rakto į Flutter kodą.

---

## 8. Sporto katalogas (jei tuščias)

Jei onboarding nerodo sporto šakų, SQL Editor:

Paleiskite `supabase/seed_sports_catalog.sql`

---

## 9. Migracija iš seno `my_sports` JSON

Jei turite senų vartotojų su sportais tik `profiles.my_sports` lauke:

```sql
SELECT public.migrate_my_sports_to_user_sports();
```

Grąžins skaičių – kiek įrašų perkelta. Paleiskite **vieną kartą**.

---

## 10. RLS testas (svarbu prieš production)

1. Prisijunkite programėlėje kaip paprastas vartotojas
2. Patikrinkite: reitingai, turnyrai, profilis, pokalbiai
3. Jei matote `permission denied` – SQL Editor:

```sql
-- Laikinai pamatyti kur blokuoja (TIK DEBUG):
-- ALTER TABLE matches DISABLE ROW LEVEL SECURITY;
-- Po testo vėl įjunkite:
-- ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
```

Problemos dažniausiai: trūksta politikos lentelei – praneškite kuriame ekrane klaida.

---

## 11. Rekomenduojami Dashboard nustatymai dideliam srautui

| Vieta | Nustatymas |
|-------|------------|
| Database → Connection pooling | Naudokite **Supavisor** pooler connection string serverio pusėje |
| API → Rate limits | Stebėkite Usage; didinant planą didėja limitai |
| Realtime | Įjunkite tik lentelėms `direct_messages`, `match_chat` (ne visoms) |
| Logs | Įjunkite Postgres slow query log (>500ms) |

---

## Failų struktūra

```
supabase/
├── INSTRUKCIJOS.md          ← šis failas
├── apply_all.sql            ← viskas viename (SQL Editor)
└── migrations/
    ├── 20260521000001_functions.sql
    ├── 20260521000002_indexes.sql
    ├── 20260521000003_triggers.sql
    ├── 20260521000004_rls.sql
    ├── 20260521000005_cron.sql
    ├── 20260521000006_storage.sql
    └── 20260521000007_performance.sql
```

---

## Dažnos klaidos

| Klaida | Sprendimas |
|--------|------------|
| `function increment_profile_xp does not exist` | Paleiskite `000001_functions.sql` |
| `permission denied for table matches` | Paleiskite `000004_rls.sql` arba patikrinkite ar prisijungęs |
| `relation user_sports does not exist` | Lentelė turi būti sukurta anksčiau projekte; žr. `schema_reference.sql` |
| pg_cron extension not found | Įjunkite Extensions → pg_cron |
| Storage upload failed | Sukurkite bucket + paleiskite `000006_storage.sql` |
| Registracija – dubliuotas profilis | Trigger jau sukuria profilį; `login_screen` nebededa antro įrašo |
| XP nepridedamas po mačo | Paleiskite `000003_triggers.sql` (trigger `on_match_completed_xp`) |
| Dvigubas XP | Įsitikinkite, kad paleidote triggers – klientas XP nebeduoda |

---

## Pagalba

Jei migracija sustoja ant konkretaus `ALTER TABLE` – jūsų DB schema gali šiek tiek skirtis. Nukopijuokite klaidos tekstą ir koreguokite tik tą eilutę (arba praleiskite ją, jei stulpelis jau egzistuoja).
