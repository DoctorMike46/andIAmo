# GDPR & Privacy

Documento di riferimento per la conformità al GDPR. Da espandere prima del rilascio pubblico con il consulente legale.

## Principi applicati

### Liceità
- **Base giuridica:** consenso (art. 6 lett. a) per profilazione AI, geolocalizzazione, marketing/analytics; esecuzione del contratto (art. 6 lett. b) per fornire il servizio core (auth, catalogo).
- **Consensi granulari**: 4 toggle separati — `tos`, `privacy_policy` (obbligatori), `geolocation`, `ai_profiling`, `analytics`, `marketing` (opzionali).

### Minimizzazione
- Solo `birth_year`, no data nascita completa
- Cognome non obbligatorio
- Niente PII nei log applicativi (filtro `structlog`)

### Funzionamento senza consensi opzionali
- **Senza geolocalizzazione**: l'utente seleziona la città. Tutti gli endpoint che accettano `lat/lng` accettano `?city=` come fallback (centroide).
- **Senza profilazione AI**: branch rule-based del recommender; nessuna chiamata a Voyage/Claude per quell'utente; `users.profile_embedding` resta `NULL`.
- **Senza analytics**: nessun invio a `POST /interactions`.

## Diritti dell'interessato

| Diritto | Endpoint / processo |
|---|---|
| Accesso (art. 15) | `GET /me/export` → bundle ZIP (JSON+CSV), URL pre-signed S3, validità 24h |
| Rettifica (art. 16) | `PATCH /me`, `POST /me/consents` |
| Cancellazione (art. 17) | `DELETE /me` → `users.deleted_at` set; job purge dopo 30g (anonimizza interactions, hard-delete users/favorites/consents/embedding) |
| Limitazione (art. 18) | `POST /me/consents` con `granted=false` su tipi opzionali |
| Portabilità (art. 20) | Stesso bundle di art. 15, in formato JSON machine-readable |
| Opposizione (art. 21) | Toggle granulari in Privacy Center |
| Decisioni automatizzate (art. 22) | Le raccomandazioni sono *suggerimenti* non vincolanti — non costituiscono decisione automatizzata che produce effetti giuridici. Comunicato esplicitamente nell'informativa privacy. |

## Audit trail consensi

Tabella `consents` **append-only**:
- ogni grant/revoke crea un nuovo record
- index su `(user_id, consent_type, created_at DESC)` per recuperare lo stato corrente
- vista `current_consents` come materialized view o query

Campi audit: `version` del testo accettato, `ip_address`, `user_agent`, `created_at`.

## Retention

| Dato | Retention |
|---|---|
| Account attivo | indefinito |
| Account soft-deleted | 30 giorni → hard delete |
| `recommendation_logs` | 90 giorni → purge automatico |
| `user_interactions` (con consenso analytics) | 12 mesi rolling, partizionato per mese |
| Backup DB | 30 giorni |
| Log applicativi | 30 giorni (no PII) |

## Trasferimenti extra-UE

- **Anthropic (Claude)**: USA. Standard Contractual Clauses + DPA Anthropic. Disclosure nell'informativa.
- **Voyage AI**: USA. SCC + DPA. Disclosure nell'informativa.
- Dati personali inviati ad AI providers: **mai** dati identificativi diretti (no email, no nome). Solo descrizioni aggregate ("utente preferisce locali rustici, dieta vegetariana, città Milano").

## DPIA (Data Protection Impact Assessment)

DPIA richiesta per la profilazione AI sistematica. Da redigere come allegato a questo doc. Punti chiave:
1. Necessità e proporzionalità della profilazione: l'app non funziona meglio senza? → la rule-based esiste come fallback, l'AI è un *miglioramento opzionale*
2. Rischi: ri-identificazione tramite embedding, bias del modello → embedding aggregati, audit periodico delle raccomandazioni per fairness
3. Misure: consenso granulare e revocabile in qualsiasi momento, possibilità di richiedere intervento umano (post-MVP)

## Sicurezza

- TLS 1.3 ovunque (Caddy)
- Postgres at-rest encryption (Hetzner managed)
- Password: argon2id (parametri OWASP 2024)
- JWT firmati EdDSA o HS256, access 15m + refresh 30g revocabili
- Secrets in env vars (mai committati)
- Rate limiting per endpoint sensibili (login, register, forgot-password)

## Open items

- [ ] Privacy Policy testo finale (consulente legale)
- [ ] Cookie banner web (se ci sarà una landing)
- [ ] Registro dei trattamenti (art. 30)
- [ ] Nomina DPO se applicabile
- [ ] DPIA dettagliata
