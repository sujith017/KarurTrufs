import { pool } from "../config/db";
import type { OtpPurpose } from "../providers/otp.provider";

export type CreateOtpResult =
  | { status: "created"; id: string; expiresAt: Date }
  | { status: "cooldown"; retryAfterSeconds: number }
  | { status: "hourly_limit" };

export const createOtp = async (data: {
  phone: string;
  purpose: OtpPurpose;
  otpHash: string;
  expiresAt: Date;
  cooldownSeconds: number;
  hourlyLimit: number;
}): Promise<CreateOtpResult> => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Serialize concurrent requests for the same phone + purpose
    await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
      `otp:${data.phone}:${data.purpose}`,
    ]);

    const recent = await client.query(
      `SELECT
         COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '1 hour')::int
           AS last_hour,
         EXTRACT(EPOCH FROM (NOW() - MAX(created_at)))::int
           AS seconds_since_last
       FROM otp_verifications
       WHERE phone = $1 AND purpose = $2`,
      [data.phone, data.purpose]
    );

    const { last_hour, seconds_since_last } = recent.rows[0];

    if (last_hour >= data.hourlyLimit) {
      await client.query("ROLLBACK");
      return { status: "hourly_limit" };
    }

    if (
      seconds_since_last !== null &&
      seconds_since_last < data.cooldownSeconds
    ) {
      await client.query("ROLLBACK");
      return {
        status: "cooldown",
        retryAfterSeconds: data.cooldownSeconds - seconds_since_last,
      };
    }

    // Only the newest code should work: expire older unused ones
    await client.query(
      `UPDATE otp_verifications
       SET expires_at = NOW()
       WHERE phone = $1
         AND purpose = $2
         AND verified_at IS NULL
         AND expires_at > NOW()`,
      [data.phone, data.purpose]
    );

    const inserted = await client.query(
      `INSERT INTO otp_verifications (phone, otp_hash, purpose, expires_at)
       VALUES ($1, $2, $3, $4)
       RETURNING id, expires_at`,
      [data.phone, data.otpHash, data.purpose, data.expiresAt]
    );

    await client.query("COMMIT");

    return {
      status: "created",
      id: inserted.rows[0].id,
      expiresAt: inserted.rows[0].expires_at,
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};

// Records one guess against the newest usable code and returns it.
// Returns null if there is no usable code (none, expired, used, or out of attempts).
export const registerOtpAttempt = async (data: {
  phone: string;
  purpose: OtpPurpose;
  maxAttempts: number;
}): Promise<{ id: string; otpHash: string } | null> => {
  const result = await pool.query(
    `UPDATE otp_verifications
     SET attempts = attempts + 1
     WHERE id = (
       SELECT id FROM otp_verifications
       WHERE phone = $1
         AND purpose = $2
         AND verified_at IS NULL
         AND expires_at > NOW()
       ORDER BY created_at DESC
       LIMIT 1
     )
     AND attempts < $3
     RETURNING id, otp_hash`,
    [data.phone, data.purpose, data.maxAttempts]
  );

  if (result.rowCount === 0) return null;

  return { id: result.rows[0].id, otpHash: result.rows[0].otp_hash };
};

// Marks a code as used. Returns false if someone else already used it
// or it expired in the meantime.
export const markOtpVerified = async (id: string): Promise<boolean> => {
  const result = await pool.query(
    `UPDATE otp_verifications
     SET verified_at = NOW()
     WHERE id = $1
       AND verified_at IS NULL
       AND expires_at > NOW()
     RETURNING id`,
    [id]
  );

  return result.rowCount === 1;
};