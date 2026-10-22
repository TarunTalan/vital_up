// delete-account's emails (layout in ../_shared/email.ts). Pure, so they
// can be previewed outside Deno.

import {
  block,
  escapeHtml,
  formatEmailDate,
  link,
  PRIVACY_EMAIL,
  renderEmail,
  strong,
} from "../_shared/email.ts";

export interface UserDeletionDetails {
  userId: string;
  userEmail: string;
  userName?: string;
  username?: string;
  provider?: string;
  phone?: string;
  createdAt?: string;
  lastSignInAt?: string;
}

/** Audit note for the privacy and support desks. */
export function renderAdminDeletionNotice(d: UserDeletionDetails, deletedAt: Date): { html: string; text: string } {
  const email = escapeHtml(d.userEmail);
  const optional = (value?: string) => escapeHtml(value || "None");
  const date = (value?: string) => (value ? formatEmailDate(value) : "Unknown");
  return renderEmail({
    preheader: `${d.userEmail} deleted their account in the app.`,
    eyebrow: "Audit · Account deleted",
    tone: "danger",
    heading: "Account deleted in the app",
    intro: `${strong(email)} deleted their account. Their database rows, storage files and purchase history were removed, and they were sent a confirmation.`,
    blocks: [
      block.details([
        ["Email", link(d.userEmail, `mailto:${email}`)],
        ["Name", optional(d.userName)],
        ["Username", optional(d.username)],
        ["User ID", escapeHtml(d.userId)],
        ["Sign-in", escapeHtml(d.provider || "email")],
        ["Phone", optional(d.phone)],
        ["Joined", date(d.createdAt)],
        ["Last sign-in", date(d.lastSignInAt)],
        ["Deleted", formatEmailDate(deletedAt)],
      ]),
    ],
    reason: "Sent to the VitalUp privacy and support desks.",
  });
}

/** Confirmation for the person whose account was deleted. */
export function renderDeletionConfirmed(d: UserDeletionDetails, deletedAt: Date): { html: string; text: string } {
  const name = d.userName ? `, ${escapeHtml(d.userName)}` : "";
  return renderEmail({
    preheader: "Your VitalUp account and its data were permanently deleted.",
    eyebrow: "Account deleted",
    heading: "Your account has been deleted",
    intro: `As you asked${name}, we permanently deleted the VitalUp account for ${strong(escapeHtml(d.userEmail))} on ${formatEmailDate(deletedAt)}.`,
    blocks: [
      block.list([
        "Profile and sign-in details",
        "Water, sleep, meal, weight and mood logs",
        "Workouts and GPS routes",
        "Vita chats, diet plans and Arena progress",
        "Photos and other uploaded files",
      ], "What we deleted"),
      block.note(`${strong("Have a subscription?")} Deleting your account doesn't cancel it. Cancel it in the Play Store.`),
    ],
    closing: `Didn't do this? Write to ${link(PRIVACY_EMAIL, `mailto:${PRIVACY_EMAIL}`)} right away.`,
    reason: "You received this because your VitalUp account was deleted.",
  });
}
