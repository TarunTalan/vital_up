// Renders the Supabase Auth dashboard templates (Authentication > Emails)
// from the same layout the send-email hook uses, so a code looks the same
// whichever path sends it. Run after changing _shared/email.ts:
//
//   node supabase/email_templates/build.ts
//
// then paste each file into its dashboard template with the subject below.

import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { type AuthEmailKind, block, renderAuthEmail, strong } from "../functions/_shared/email.ts";

const TOKEN = "{{ .Token }}";
const here = dirname(fileURLToPath(import.meta.url));

const templates: Array<{
  file: string;
  kind: AuthEmailKind;
  intro?: string;
  extra?: ReturnType<typeof block.button>[];
}> = [
  { file: "signup_confirmation.html", kind: "signup" },
  { file: "password_recovery.html", kind: "recovery" },
  {
    file: "magic_link.html",
    kind: "magiclink",
    intro: "Enter this code in the app to sign in, or use the button on this phone.",
    extra: [block.button("Sign in to VitalUp", "{{ .ConfirmationURL }}")],
  },
  {
    file: "email_change.html",
    kind: "email_change",
    intro: `Enter this code in the app to change your email from ${strong("{{ .Email }}")} to ${strong("{{ .NewEmail }}")}.`,
    extra: [block.button("Confirm new email", "{{ .ConfirmationURL }}")],
  },
];

for (const t of templates) {
  const { subject, html } = renderAuthEmail(t.kind, TOKEN, { intro: t.intro, extra: t.extra });
  writeFileSync(join(here, t.file), html);
  console.log(`${t.file.padEnd(26)} subject: ${subject}`);
}
