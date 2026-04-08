import nodemailer from "nodemailer";

const resendApiKey = String(process.env.RESEND_API_KEY || "").trim();
const resendFrom = String(process.env.RESEND_FROM || process.env.SMTP_FROM || "").trim();

function createSmtpTransporter() {
  const host = process.env.SMTP_HOST;
  const portValue = process.env.SMTP_PORT;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!host || !portValue || !user || !pass) {
    return null;
  }
  return nodemailer.createTransport({
    host,
    port: Number(portValue),
    secure: String(process.env.SMTP_SECURE || "false") === "true",
    auth: {
      user,
      pass
    }
  });
}

async function sendViaResend({ from, to, subject, text }) {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendApiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      from,
      to: Array.isArray(to) ? to : [to],
      subject,
      text
    })
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`RESEND_ERROR ${response.status}: ${body}`);
  }
}

export function createEmailProvider({ supportEmail }) {
  const smtpTransporter = createSmtpTransporter();
  const emailProvider = String(process.env.EMAIL_PROVIDER || "").trim().toLowerCase();
  const useResend = emailProvider === "resend" || (!emailProvider && Boolean(resendApiKey));
  const useSmtp = emailProvider === "smtp" || (!useResend && Boolean(smtpTransporter));
  const defaultFrom = resendFrom || process.env.SMTP_FROM || supportEmail;

  return {
    isConfigured() {
      if (useResend) {
        return Boolean(resendApiKey && defaultFrom);
      }
      if (useSmtp) {
        return Boolean(smtpTransporter);
      }
      return false;
    },
    getMode() {
      if (useResend) {
        return "resend";
      }
      if (useSmtp) {
        return "smtp";
      }
      return "none";
    },
    async sendRegistrationEmails({ displayName, email, location, code, requestedAt }) {
      if (!this.isConfigured()) {
        throw new Error("EMAIL_PROVIDER_NOT_CONFIGURED");
      }

      const supportMessage = [
        "New BackDoor Heroes registration request",
        "",
        `Display name: ${displayName}`,
        `Player email: ${email}`,
        `Location: ${location}`,
        `Verification code: ${code}`,
        `Requested at: ${requestedAt}`
      ].join("\n");

      const playerMessage = [
        `Hi ${displayName},`,
        "",
        "Use the following verification code inside Cell Defense: Core Immunity:",
        "",
        code,
        "",
        "This code expires in 15 minutes.",
        "",
        "If you did not request this registration, ignore this email."
      ].join("\n");

      if (useResend) {
        await sendViaResend({
          from: defaultFrom,
          to: supportEmail,
          subject: "Cell Defense BackDoor Heroes registration request",
          text: supportMessage
        });
        await sendViaResend({
          from: defaultFrom,
          to: email,
          subject: "BackDoor Heroes verification code",
          text: playerMessage
        });
        return;
      }

      await smtpTransporter.sendMail({
        from: defaultFrom,
        to: supportEmail,
        subject: "Cell Defense BackDoor Heroes registration request",
        text: supportMessage
      });

      await smtpTransporter.sendMail({
        from: defaultFrom,
        to: email,
        subject: "BackDoor Heroes verification code",
        text: playerMessage
      });
    }
  };
}
