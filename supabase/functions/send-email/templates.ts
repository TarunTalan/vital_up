// send-email's support and deletion-request emails (layout in
// ../_shared/email.ts). Pure, so they can be previewed outside Deno.

import { block, escapeHtml, formatEmailDate, link, renderEmail, strong } from "../_shared/email.ts";

/** New ticket for the support desk; Reply goes to the user. */
export function renderSupportTicket(p: {
  user_email: string;
  user_name?: string;
  user_id: string;
  category: string;
  subject: string;
  description: string;
  include_diagnostics: boolean;
  app_version?: string;
  os_platform?: string;
  device_model?: string;
  created_at: string;
}): { html: string; text: string } {
  const email = escapeHtml(p.user_email);
  const blocks = [
    block.quote(p.description, "Message"),
    block.details([
      ["Name", escapeHtml(p.user_name || "Not given")],
      ["Email", link(p.user_email, `mailto:${email}`)],
      ["User ID", escapeHtml(p.user_id)],
      ["Topic", escapeHtml(p.category)],
      ["Received", formatEmailDate(p.created_at)],
    ], "From"),
  ];
  if (p.include_diagnostics) {
    blocks.push(block.details([
      ["App version", escapeHtml(p.app_version || "Unknown")],
      ["Platform", escapeHtml(p.os_platform || "Unknown")],
      ["Device", escapeHtml(p.device_model || "Unknown")],
    ], "Device"));
  }
  return renderEmail({
    preheader: `${p.user_name || p.user_email}: ${p.description.slice(0, 90)}`,
    eyebrow: `Support ticket · ${p.category}`,
    heading: p.subject,
    intro: `From ${strong(escapeHtml(p.user_name || p.user_email))}. Reply to this email to answer them directly.`,
    blocks,
    reason: "Sent from the VitalUp app's contact form to the support desk.",
  });
}

/** Receipt for the user who sent a ticket. */
export function renderSupportConfirmation(p: {
  user_name?: string;
  category: string;
  subject: string;
  description: string;
}): { html: string; text: string } {
  const name = p.user_name ? `, ${escapeHtml(p.user_name)}` : "";
  return renderEmail({
    preheader: "Thanks for writing in. We usually reply within 24 hours.",
    eyebrow: "VitalUp support",
    heading: "We received your request",
    intro: `Thanks for writing in${name}. We usually reply within 24 hours.`,
    blocks: [
      block.details([
        ["Topic", escapeHtml(p.category)],
        ["Subject", escapeHtml(p.subject)],
      ]),
      block.quote(p.description, "Your message"),
    ],
    closing: "Want to add details or screenshots? Just reply to this email.",
    reason: "You received this because you contacted VitalUp support.",
  });
}

/** Website deletion form, for the privacy desk. */
export function renderDeletionAdmin(p: {
  user_email: string;
  scope: string;
  description: string;
  created_at: string;
}): { html: string; text: string } {
  const email = escapeHtml(p.user_email);
  return renderEmail({
    preheader: `Deletion requested for ${p.user_email}. Complete within 72 hours.`,
    eyebrow: "Action required · Deletion request",
    tone: "danger",
    heading: "Account deletion requested",
    intro: "Sent from the form on vitalup.live. Confirm the owner, then delete the account within 72 hours.",
    blocks: [
      block.details([
        ["Account", link(p.user_email, `mailto:${email}`)],
        ["Scope", escapeHtml(p.scope)],
        ["Received", formatEmailDate(p.created_at)],
      ]),
      block.quote(p.description, "Notes"),
    ],
    closing: "Reply to this email to reach the requester.",
    reason: "Sent to the VitalUp privacy desk.",
  });
}

/** Receipt for someone who used the website deletion form. */
export function renderDeletionReceipt(p: { user_email: string; scope: string }): { html: string; text: string } {
  return renderEmail({
    preheader: "We'll confirm it's your account, then delete it within 72 hours.",
    eyebrow: "Privacy",
    heading: "We received your deletion request",
    intro: `We'll confirm that ${strong(escapeHtml(p.user_email))} is your account, then delete it and its data within 72 hours.`,
    blocks: [
      block.details([
        ["Scope", escapeHtml(p.scope)],
        ["Status", "Waiting for confirmation"],
      ]),
      block.note(`${strong("Didn't ask for this?")} Reply to this email within 72 hours and we'll keep your account.`),
    ],
    closing: "Deleting your account doesn't cancel a Google Play subscription. Cancel it in the Play Store.",
    reason: "You received this because this address was entered on vitalup.live/delete-account.",
  });
}
