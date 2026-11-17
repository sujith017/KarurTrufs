import { pool } from "../config/db";

export const createSession = async (data: {
  userId: string;
  refreshTokenHash: string;
  deviceInfo: string | null;
  ipAddress: string | null;
  expiresAt: Date;
}) => {
  const result = await pool.query(
    `INSERT INTO user_sessions (
       user_id,
       refresh_token_hash,
       device_info,
       ip_address,
       expires_at
     )
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, expires_at, created_at`,
    [
      data.userId,
      data.refreshTokenHash,
      data.deviceInfo,
      data.ipAddress,
      data.expiresAt,
    ]
  );

  return result.rows[0];
};

export const findActiveSession = async (
  sessionId: string,
  userId: string
) => {
  const result = await pool.query(
    `SELECT s.id, s.user_id
     FROM user_sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.id = $1
       AND s.user_id = $2
       AND s.revoked_at IS NULL
       AND s.expires_at > NOW()
       AND u.is_active = true`,
    [sessionId, userId]
  );

  return result.rows[0] ?? null;
};

export type RotateResult =
  | { status: "rotated"; userId: string; sessionId: string }
  | { status: "reused"; userId: string }
  | { status: "invalid" };

export const rotateSession = async (data: {
  oldTokenHash: string;
  newTokenHash: string;
  expiresAt: Date;
  deviceInfo: string | null;
  ipAddress: string | null;
}): Promise<RotateResult> => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Claim the old session: only succeeds if it is active, unexpired,
    // and its user is still active.
    const claimed = await client.query(
      `UPDATE user_sessions s
       SET revoked_at = NOW(), last_used_at = NOW()
       FROM users u
       WHERE s.user_id = u.id
         AND u.is_active = true
         AND s.refresh_token_hash = $1
         AND s.revoked_at IS NULL
         AND s.expires_at > NOW()
       RETURNING s.user_id`,
      [data.oldTokenHash]
    );

    if (claimed.rows.length === 1) {
      const userId: string = claimed.rows[0].user_id;

      const inserted = await client.query(
        `INSERT INTO user_sessions (
           user_id, refresh_token_hash, device_info, ip_address, expires_at
         )
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id`,
        [
          userId,
          data.newTokenHash,
          data.deviceInfo,
          data.ipAddress,
          data.expiresAt,
        ]
      );

      await client.query("COMMIT");
      return { status: "rotated", userId, sessionId: inserted.rows[0].id };
    }

    // Not claimable. Was it a token we already retired? That means reuse.
    const existing = await client.query(
      `SELECT user_id, revoked_at
       FROM user_sessions
       WHERE refresh_token_hash = $1`,
      [data.oldTokenHash]
    );

    if (existing.rows.length === 1 && existing.rows[0].revoked_at !== null) {
      const userId: string = existing.rows[0].user_id;

      await client.query(
        `UPDATE user_sessions
         SET revoked_at = NOW()
         WHERE user_id = $1 AND revoked_at IS NULL`,
        [userId]
      );

      await client.query("COMMIT");
      return { status: "reused", userId };
    }

    await client.query("COMMIT");
    return { status: "invalid" };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};

export const revokeSession = async (sessionId: string, userId: string) => {
  const result = await pool.query(
    `UPDATE user_sessions
     SET revoked_at = NOW()
     WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL`,
    [sessionId, userId]
  );

  return result.rowCount ?? 0;
};

export const revokeAllUserSessions = async (userId: string) => {
  const result = await pool.query(
    `UPDATE user_sessions
     SET revoked_at = NOW()
     WHERE user_id = $1 AND revoked_at IS NULL`,
    [userId]
  );

  return result.rowCount ?? 0;
};