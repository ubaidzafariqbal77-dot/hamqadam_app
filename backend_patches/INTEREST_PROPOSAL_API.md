# Interest / Proposal workflow — backend work the app now expects

Source: `Hamqadam_Complete_Interest_Proposal_Communication_Developer_Specification.docx`.
The Flutter side is done; everything below has to land in the Laravel backend.

## 1. Message templates (spec §6, §12, §13)

`GET /api/v1/message-templates?type=interest|proposal&language=en`

```json
{ "success": true, "data": [
  { "id": 1, "type": "interest", "title": "Simple & Sincere",
    "opening": "...", "body": "...", "closing": "...",
    "language": "en", "status": "active", "display_order": 1 }
] }
```

- Return only active, non-empty rows, ordered by `display_order`.
- Table: id, type, title, opening, body, closing, language, status, display_order,
  created_at, updated_at, created_by, updated_by (admin audit).
- Admin Dashboard: create / edit / activate-deactivate / reorder.
- Seed with the 15 + 15 texts from the spec (same wording is in
  `lib/constants/message_template_seed.dart`; the app only uses that copy when this
  endpoint fails).

## 2. AI Proposal Generator (spec §5)

`POST /api/v1/ai/proposal`

Request: `receiver_id`, `language` (`en` | `ur`, more later), `include_family_intro` (bool),
`intentions` (optional, the sender's own words), `generation` (1, 2, 3… for Regenerate).

Response: `{ "data": { "text": "..." } }`. Draft only — never send or store a proposal.
Do not invent education, job, income, family or intentions that the sender didn't write
and that aren't on the public profile. If it fails, return an error; the app falls back to templates.

## 3. Access rules (spec §4)

- `POST /proposals` must return 403 unless an **accepted** interest exists between the pair.
- 409 on duplicate active interest (pending/accepted either way) and duplicate active proposal.
- Accepting an interest opens chat + audio/video calls for both users. Decline, block or report revokes them.
- `POST /interests/{id}/accept|reject` should return the updated `interest` with `member`.

## 4. Push + email (spec §7, §8)

| Event | To | Push / email |
|---|---|---|
| Interest sent | receiver | immediate (§7.1 copy) |
| Interest accepted | sender | immediate (§7.2) |
| Interest pending | receiver | one reminder after 24h; never after decline |
| Proposal sent | receiver | immediate (§7.3) |
| Proposal pending | receiver | one reminder after 48h; never after decline |
| Proposal accepted | sender | immediate (§7.4), then start family-discussion workflow |
| Family meeting | both | immediate + reminders 24h and 1h before |

Use the exact titles/bodies/subjects from the spec. Respect notification preferences.
Emails must not include profile details, only a secure in-app deep link.
