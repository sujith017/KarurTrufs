import { env } from "../config/env";

export type OtpPurpose = "LOGIN" | "PHONE_VERIFICATION";

export interface OtpSender {
  send(data: {
    phone: string;
    code: string;
    purpose: OtpPurpose;
  }): Promise<void>;
}

// Development-only sender: prints the code to the server terminal.
class ConsoleOtpSender implements OtpSender {
  async send(data: {
    phone: string;
    code: string;
    purpose: OtpPurpose;
  }): Promise<void> {
    if (env.NODE_ENV === "production") {
      // Never log OTPs in production. A real provider must replace this.
      throw new Error("No OTP provider configured for production");
    }

    console.log(`[DEV OTP] ${data.purpose} code for ${data.phone}: ${data.code}`);
  }
}

export const otpSender: OtpSender = new ConsoleOtpSender();