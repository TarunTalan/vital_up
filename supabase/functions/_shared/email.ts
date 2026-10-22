// One layout for every VitalUp email (auth codes, support, account
// deletion), so they all look like the app and like each other.
//
// Built for email clients, not browsers: tables for layout, inline styles,
// a 560px column that shrinks to the screen, bulletproof buttons and MSO
// fallbacks for Outlook. Light by default (Gmail and Outlook recolour on
// their own); clients that read prefers-color-scheme (Apple Mail, iOS,
// Outlook.com) get the app's dark theme instead.
//
// Pure (no Deno APIs): supabase/email_templates/build.ts renders the
// dashboard templates from it with Node.

/** How long an emailed auth code works (Supabase Auth > Email OTP expiry). */
export const CODE_EXPIRY = "10 minutes";

export const SUPPORT_EMAIL = "support@vitalup.live";
export const PRIVACY_EMAIL = "privacy@vitalup.live";
const SITE = "https://vitalup.live";
const LOGO_URL = `${SITE}/assets/vitalup_light_logo.png`;

// App tokens (lib/core/theme/app_colors.dart).
const LIGHT = {
  page: "#F2F4F5",
  card: "#FFFFFF",
  line: "#E3E6E8",
  panel: "#F6F8F9",
  text: "#1C1C1C",
  muted: "#757575",
  accent: "#0B7C90", // primaryTextLight: the brand cyan as readable text
  danger: "#C23B3A",
  codeBg: "#E6F8FB",
  codeLine: "#BDEBF4",
};
const DARK = {
  page: "#0C0C0C",
  card: "#1C1C1C",
  line: "#343434",
  panel: "#242424",
  text: "#FEFEFE",
  muted: "#A3A3A3",
  accent: "#19C3E0",
  danger: "#F0857F",
  codeBg: "#0D515D",
  codeLine: "#146B7A",
};
const BRAND = "#19C3E0";
const ON_BRAND = "#0C0C0C";

const FONT = "'Nunito', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
const MONO = "'JetBrains Mono', 'SFMono-Regular', Menlo, Consolas, 'Courier New', monospace";

export function escapeHtml(value: string): string {
  return (value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

/** Escaped user text with its line breaks kept. */
export function multiline(value: string): string {
  return escapeHtml(value).replace(/\r?\n/g, "<br>");
}

/** "22 Oct 2026, 14:05 UTC" (falls back to the input when it isn't a date). */
export function formatEmailDate(value: string | Date): string {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return String(value || "Unknown");
  const day = date.toLocaleDateString("en-GB", {
    timeZone: "UTC",
    day: "numeric",
    month: "short",
    year: "numeric",
  });
  const time = date.toLocaleTimeString("en-GB", {
    timeZone: "UTC",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  return `${day}, ${time} UTC`;
}

/** A piece of the email body, with its plain-text twin. */
export interface EmailBlock {
  html: string;
  text: string;
}

export interface EmailContent {
  /** Inbox preview line (hidden in the body). */
  preheader: string;
  /** Small label above the heading. */
  eyebrow?: string;
  /** "danger" colours the eyebrow red (deletions). */
  tone?: "brand" | "danger";
  heading: string;
  /** Intro paragraph, already-escaped HTML. */
  intro: string;
  blocks?: EmailBlock[];
  /** Grey closing line under the body, already-escaped HTML. */
  closing?: string;
  /** Why the reader got this email (footer). */
  reason: string;
}

const stripTags = (html: string) =>
  html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&middot;/g, "·")
    .replace(/&#039;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");

const panelStyle = (radius = 14) =>
  `background-color:${LIGHT.panel}; border:1px solid ${LIGHT.line}; border-radius:${radius}px;`;

export const block = {
  /** The one-time code, big and easy to copy. */
  code(code: string, caption = `Expires in ${CODE_EXPIRY}. Never share it with anyone.`): EmailBlock {
    return {
      html: `<table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" class="code-panel" style="background-color:${LIGHT.codeBg}; border:1px solid ${LIGHT.codeLine}; border-radius:16px;">
  <tr>
    <td align="center" style="padding:24px 16px 20px;">
      <div class="code t-text" style="font-family:${MONO}; font-size:34px; line-height:40px; font-weight:700; letter-spacing:8px; padding-left:8px; color:${LIGHT.text}; white-space:nowrap;">${code}</div>
      <div class="t-muted" style="font-family:${FONT}; font-size:13px; line-height:20px; color:${LIGHT.muted}; padding-top:8px;">${escapeHtml(caption)}</div>
    </td>
  </tr>
</table>`,
      text: `${code}\n${caption}`,
    };
  },

  /** Primary button (full width on phones). */
  button(label: string, url: string): EmailBlock {
    return {
      html: `<table role="presentation" border="0" cellpadding="0" cellspacing="0" class="btn">
  <tr>
    <td align="center" bgcolor="${BRAND}" style="border-radius:14px; background-color:${BRAND};">
      <!--[if mso]><v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" href="${url}" style="height:48px; v-text-anchor:middle; width:220px;" arcsize="30%" stroke="f" fillcolor="${BRAND}"><center style="color:${ON_BRAND}; font-family:Arial, sans-serif; font-size:16px; font-weight:bold;">${escapeHtml(label)}</center></v:roundrect><![endif]-->
      <!--[if !mso]><!--><a href="${url}" target="_blank" style="display:inline-block; padding:14px 32px; font-family:${FONT}; font-size:16px; line-height:20px; font-weight:700; color:${ON_BRAND}; text-decoration:none; border-radius:14px;">${escapeHtml(label)}</a><!--<![endif]-->
    </td>
  </tr>
</table>`,
      text: `${label}: ${url}`,
    };
  },

  /** A quiet panel with one short message. [html] is already escaped. */
  note(html: string): EmailBlock {
    return {
      html: `<table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" class="panel" style="${panelStyle()}">
  <tr>
    <td class="t-text" style="padding:16px 20px; font-family:${FONT}; font-size:14px; line-height:22px; color:${LIGHT.text};">${html}</td>
  </tr>
</table>`,
      text: stripTags(html),
    };
  },

  /** Label / value rows. Values are already-escaped HTML. */
  details(rows: Array<[label: string, valueHtml: string]>, title?: string): EmailBlock {
    const body = rows
      .map(([label, value], i) => {
        const line = i === 0 ? "" : ` border-top:1px solid ${LIGHT.line};`;
        return `<tr>
    <td class="dl t-muted hair" width="36%" valign="top" style="padding:12px 12px 12px 20px;${line} font-family:${FONT}; font-size:13px; line-height:20px; color:${LIGHT.muted};">${escapeHtml(label)}</td>
    <td class="dd t-text hair" valign="top" style="padding:12px 20px 12px 0;${line} font-family:${FONT}; font-size:14px; line-height:20px; font-weight:600; color:${LIGHT.text}; word-break:break-word;">${value}</td>
  </tr>`;
      })
      .join("\n  ");
    const heading = title
      ? `<div class="t-muted" style="font-family:${FONT}; font-size:12px; line-height:16px; font-weight:700; letter-spacing:1px; text-transform:uppercase; color:${LIGHT.muted}; padding:0 0 8px 4px;">${escapeHtml(title)}</div>\n`
      : "";
    return {
      html: `${heading}<table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" class="panel" style="${panelStyle()}">
  ${body}
</table>`,
      text: (title ? `${title}\n` : "") + rows.map(([l, v]) => `${l}: ${stripTags(v)}`).join("\n"),
    };
  },

  /** Someone's own words (a ticket, a request note). [text] is raw. */
  quote(text: string, title?: string): EmailBlock {
    const heading = title
      ? `<div class="t-muted" style="font-family:${FONT}; font-size:12px; line-height:16px; font-weight:700; letter-spacing:1px; text-transform:uppercase; color:${LIGHT.muted}; padding:0 0 8px 4px;">${escapeHtml(title)}</div>\n`
      : "";
    return {
      html: `${heading}<table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" class="panel" style="${panelStyle()}">
  <tr>
    <td class="t-text" style="padding:16px 20px; font-family:${FONT}; font-size:15px; line-height:24px; color:${LIGHT.text}; word-break:break-word;">${multiline(text)}</td>
  </tr>
</table>`,
      text: (title ? `${title}\n` : "") + text,
    };
  },

  /** A short list with brand dots. Items are already-escaped HTML. */
  list(items: string[], title?: string): EmailBlock {
    const rows = items
      .map((item) => `<tr>
    <td width="20" valign="top" style="padding:9px 0 0 20px; font-size:0; line-height:0;"><span style="display:inline-block; width:6px; height:6px; border-radius:3px; background-color:${BRAND};"></span></td>
    <td class="t-text" valign="top" style="padding:2px 20px 2px 4px; font-family:${FONT}; font-size:14px; line-height:22px; color:${LIGHT.text};">${item}</td>
  </tr>`)
      .join("\n  ");
    const heading = title
      ? `<div class="t-muted" style="font-family:${FONT}; font-size:12px; line-height:16px; font-weight:700; letter-spacing:1px; text-transform:uppercase; color:${LIGHT.muted}; padding:0 0 8px 4px;">${escapeHtml(title)}</div>\n`
      : "";
    return {
      html: `${heading}<table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" class="panel" style="${panelStyle()}">
  <tr><td colspan="2" style="height:12px; font-size:0; line-height:0;">&nbsp;</td></tr>
  ${rows}
  <tr><td colspan="2" style="height:12px; font-size:0; line-height:0;">&nbsp;</td></tr>
</table>`,
      text: (title ? `${title}\n` : "") + items.map((i) => `- ${stripTags(i)}`).join("\n"),
    };
  },
};

/** A link in the accent colour. */
export function link(label: string, href: string): string {
  return `<a href="${href}" target="_blank" class="t-accent" style="color:${LIGHT.accent}; font-weight:700; text-decoration:none;">${escapeHtml(label)}</a>`;
}

/** Bold text in the main text colour. */
export function strong(html: string): string {
  return `<strong class="t-text" style="color:${LIGHT.text}; font-weight:700;">${html}</strong>`;
}

const css = (c: typeof DARK) => `
      body, .bg-page { background-color:${c.page} !important; }
      .bg-card { background-color:${c.card} !important; border-color:${c.line} !important; }
      .panel { background-color:${c.panel} !important; border-color:${c.line} !important; }
      .hair { border-color:${c.line} !important; }
      .code-panel { background-color:${c.codeBg} !important; border-color:${c.codeLine} !important; }
      .t-text { color:${c.text} !important; }
      .t-muted { color:${c.muted} !important; }
      .t-accent { color:${c.accent} !important; }
      .t-danger { color:${c.danger} !important; }`;

/** The full email: HTML document plus a plain-text version. */
export function renderEmail(content: EmailContent): { html: string; text: string } {
  const year = new Date().getUTCFullYear();
  const eyebrowColor = content.tone === "danger" ? LIGHT.danger : LIGHT.accent;
  const eyebrowClass = content.tone === "danger" ? "t-danger" : "t-accent";
  const blocks = (content.blocks ?? [])
    .map((b) => `<tr>
                  <td style="padding-top:24px;">
${b.html}
                  </td>
                </tr>`)
    .join("\n                ");

  const html = `<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="x-apple-disable-message-reformatting">
  <meta name="format-detection" content="telephone=no, date=no, address=no, email=no">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <title>${escapeHtml(content.heading)}</title>
  <!--[if mso]>
  <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
  <style>td, a, div, span, p { font-family: Arial, sans-serif !important; }</style>
  <![endif]-->
  <!--[if !mso]><!-->
  <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800&display=swap" rel="stylesheet">
  <!--<![endif]-->
  <style>
    :root { color-scheme: light dark; supported-color-schemes: light dark; }
    body { margin:0 !important; padding:0 !important; width:100% !important; -webkit-text-size-adjust:100%; -ms-text-size-adjust:100%; }
    table { border-collapse:separate; mso-table-lspace:0pt; mso-table-rspace:0pt; }
    img { border:0; outline:none; text-decoration:none; -ms-interpolation-mode:bicubic; }
    a { text-decoration:none; }
    a[x-apple-data-detectors] { color:inherit !important; text-decoration:none !important; }
    u + #body a { color:inherit; text-decoration:none; }
    @media only screen and (max-width:600px) {
      .gutter { padding:24px 16px !important; }
      .card-pad { padding:32px 24px !important; }
      .h1 { font-size:24px !important; line-height:30px !important; }
      .code { font-size:30px !important; line-height:36px !important; letter-spacing:6px !important; padding-left:6px !important; }
      .btn { width:100% !important; }
      .btn a { display:block !important; }
      .dl, .dd { display:block !important; width:auto !important; }
      .dl { padding:12px 20px 0 !important; }
      .dd { padding:2px 20px 12px !important; border-top:0 !important; }
    }
    @media (prefers-color-scheme: dark) {${css(DARK)}
    }
    [data-ogsc] .bg-card, [data-ogsb] .bg-card { background-color:${DARK.card} !important; }
    [data-ogsc] .t-text { color:${DARK.text} !important; }
    [data-ogsc] .t-muted { color:${DARK.muted} !important; }
    [data-ogsc] .t-accent { color:${DARK.accent} !important; }
  </style>
</head>
<body id="body" class="bg-page" style="margin:0; padding:0; background-color:${LIGHT.page}; word-spacing:normal;">
  <div style="display:none; max-height:0; max-width:0; overflow:hidden; opacity:0; mso-hide:all; font-size:1px; line-height:1px; color:${LIGHT.page};">${escapeHtml(content.preheader)}&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;</div>
  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" class="bg-page" style="background-color:${LIGHT.page};">
    <tr>
      <td align="center" class="gutter" style="padding:40px 16px;">
        <!--[if mso]><table role="presentation" width="560" align="center" cellpadding="0" cellspacing="0" border="0"><tr><td><![endif]-->
        <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="max-width:560px; margin:0 auto;">
          <tr>
            <td align="center" style="padding:0 0 24px;">
              <a href="${SITE}" target="_blank" style="text-decoration:none;">
                <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                  <tr>
                    <td valign="middle" style="padding-right:10px;">
                      <img src="${LOGO_URL}" width="40" height="40" alt="VitalUp" style="display:block; width:40px; height:40px; border-radius:11px; border:1px solid ${LIGHT.line};">
                    </td>
                    <td valign="middle" class="t-text" style="font-family:${FONT}; font-size:22px; line-height:28px; font-weight:800; letter-spacing:-0.3px; color:${LIGHT.text};">VitalUp</td>
                  </tr>
                </table>
              </a>
            </td>
          </tr>
          <tr>
            <td class="bg-card card-pad" style="background-color:${LIGHT.card}; border:1px solid ${LIGHT.line}; border-radius:24px; padding:40px;">
              <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0">
${content.eyebrow ? `                <tr>
                  <td class="${eyebrowClass}" style="padding-bottom:8px; font-family:${FONT}; font-size:12px; line-height:16px; font-weight:800; letter-spacing:1.2px; text-transform:uppercase; color:${eyebrowColor};">${escapeHtml(content.eyebrow)}</td>
                </tr>
` : ""}                <tr>
                  <td class="h1 t-text" style="font-family:${FONT}; font-size:26px; line-height:34px; font-weight:800; letter-spacing:-0.3px; color:${LIGHT.text};">${escapeHtml(content.heading)}</td>
                </tr>
                <tr>
                  <td class="t-muted" style="padding-top:12px; font-family:${FONT}; font-size:16px; line-height:26px; color:${LIGHT.muted};">${content.intro}</td>
                </tr>
                ${blocks}
${content.closing ? `                <tr>
                  <td class="t-muted hair" style="padding-top:24px; font-family:${FONT}; font-size:14px; line-height:22px; color:${LIGHT.muted};">${content.closing}</td>
                </tr>
` : ""}              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:24px 16px 0; font-family:${FONT}; font-size:12px; line-height:20px;">
              <div class="t-muted" style="color:${LIGHT.muted};">${escapeHtml(content.reason)}</div>
              <div class="t-muted" style="color:${LIGHT.muted}; padding-top:8px;">
                <a href="${SITE}" target="_blank" class="t-muted" style="color:${LIGHT.muted}; text-decoration:underline;">vitalup.live</a>
                &nbsp;&middot;&nbsp;
                <a href="${SITE}/privacy" target="_blank" class="t-muted" style="color:${LIGHT.muted}; text-decoration:underline;">Privacy</a>
                &nbsp;&middot;&nbsp;
                <a href="${SITE}/terms" target="_blank" class="t-muted" style="color:${LIGHT.muted}; text-decoration:underline;">Terms</a>
                &nbsp;&middot;&nbsp;
                <a href="mailto:${SUPPORT_EMAIL}" class="t-muted" style="color:${LIGHT.muted}; text-decoration:underline;">Support</a>
              </div>
              <div class="t-muted" style="color:${LIGHT.muted}; padding-top:8px;">&copy; ${year} VitalUp</div>
            </td>
          </tr>
        </table>
        <!--[if mso]></td></tr></table><![endif]-->
      </td>
    </tr>
  </table>
</body>
</html>`;

  const text = [
    content.eyebrow ? content.eyebrow.toUpperCase() : "",
    content.heading,
    "",
    stripTags(content.intro),
    ...(content.blocks ?? []).flatMap((b) => ["", b.text]),
    ...(content.closing ? ["", stripTags(content.closing)] : []),
    "",
    "--",
    content.reason,
    `VitalUp · ${SITE} · ${SUPPORT_EMAIL}`,
  ]
    .filter((line, i) => i > 0 || line)
    .join("\n");

  return { html, text };
}

// ---------------------------------------------------------------------------
// Auth codes: shared by the Send Email hook and the dashboard templates.
// ---------------------------------------------------------------------------

export type AuthEmailKind =
  | "signup"
  | "recovery"
  | "magiclink"
  | "email_change"
  | "reauthentication"
  | "invite";

interface AuthCopy {
  subject: (code: string) => string;
  eyebrow: string;
  heading: string;
  intro: string;
  closing: string;
}

const AUTH_COPY: Record<AuthEmailKind, AuthCopy> = {
  signup: {
    subject: (c) => `${c} is your VitalUp code`,
    eyebrow: "Confirm your email",
    heading: "Welcome to VitalUp",
    intro: "Enter this code in the app to confirm your email and finish signing up.",
    closing: "Didn't sign up? You can ignore this email. No account is made without the code.",
  },
  recovery: {
    subject: (c) => `${c} is your VitalUp password reset code`,
    eyebrow: "Password reset",
    heading: "Reset your password",
    intro: "Enter this code in the app to choose a new password.",
    closing: "Didn't ask for this? You can ignore this email. Your password stays the same.",
  },
  magiclink: {
    subject: (c) => `${c} is your VitalUp sign-in code`,
    eyebrow: "Sign in",
    heading: "Your sign-in code",
    intro: "Enter this code in the app to sign in.",
    closing: "Didn't try to sign in? You can ignore this email. Your account is safe.",
  },
  email_change: {
    subject: (c) => `${c} is your VitalUp email change code`,
    eyebrow: "Email change",
    heading: "Confirm your new email",
    intro: "Enter this code in the app to confirm the change.",
    closing: `Didn't ask for this? Write to ${link(SUPPORT_EMAIL, `mailto:${SUPPORT_EMAIL}`)} and we'll secure your account.`,
  },
  reauthentication: {
    subject: (c) => `${c} is your VitalUp confirmation code`,
    eyebrow: "Security check",
    heading: "Confirm it's you",
    intro: "Enter this code in the app to continue.",
    closing: `Didn't ask for this? Change your password and write to ${link(SUPPORT_EMAIL, `mailto:${SUPPORT_EMAIL}`)}.`,
  },
  invite: {
    subject: () => "You're invited to VitalUp",
    eyebrow: "Invitation",
    heading: "You're invited to VitalUp",
    intro: "Enter this code in the app to accept your invitation.",
    closing: "Not expecting this? You can ignore this email.",
  },
};

export function authEmailKind(action: unknown): AuthEmailKind {
  switch (action) {
    case "recovery":
    case "magiclink":
    case "email_change":
    case "reauthentication":
    case "invite":
      return action;
    case "email":
      return "magiclink";
    case "email_change_new":
    case "email_change_current":
      return "email_change";
    default:
      return "signup";
  }
}

/**
 * A code email. [code] is inserted as is (escape it first; the dashboard
 * templates pass `{{ .Token }}`); [extra] adds blocks under the code.
 */
export function renderAuthEmail(
  kind: AuthEmailKind,
  code: string,
  options: { intro?: string; extra?: EmailBlock[] } = {},
): { subject: string; html: string; text: string } {
  const copy = AUTH_COPY[kind];
  const { html, text } = renderEmail({
    preheader: `${copy.intro} It expires in ${CODE_EXPIRY}.`,
    eyebrow: copy.eyebrow,
    heading: copy.heading,
    intro: options.intro ?? copy.intro,
    blocks: [block.code(code), ...(options.extra ?? [])],
    closing: copy.closing,
    reason: "You received this because this address was entered in VitalUp.",
  });
  return { subject: copy.subject(code), html, text };
}
