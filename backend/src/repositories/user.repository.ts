import { pool } from "../config/db";

export const findUserByEmail = async (email: string) => {
  const result = await pool.query(
    `SELECT id, full_name, email, phone, password_hash
     FROM users
     WHERE LOWER(email) = LOWER($1)`,
    [email]
  );

  return result.rows[0] ?? null;
};

export const findUserByPhone = async (phone: string) => {
  const result = await pool.query(
    `SELECT id, full_name, email, phone, password_hash
     FROM users
     WHERE phone = $1`,
    [phone]
  );

  return result.rows[0] ?? null;
};

export const createUser = async (data: {
  fullName: string;
  email: string;
  phone: string;
  passwordHash: string;
}) => {
  const result = await pool.query(
    `INSERT INTO users (
      full_name,
      email,
      phone,
      password_hash
    )
    VALUES ($1, $2, $3, $4)
    RETURNING id, full_name, email, phone, created_at`,
    [
      data.fullName,
      data.email,
      data.phone,
      data.passwordHash,
    ]
  );

  return result.rows[0];
};

export const isUniqueViolation = (error: unknown): boolean => {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "23505"
  );
};

export const findUserByIdentifier = async (identifier: string) => {
  const result = await pool.query(
    `SELECT
       id,
       full_name,
       email,
       phone,
       password_hash,
       is_active
     FROM users
     WHERE LOWER(email) = LOWER($1)
        OR phone = $1
     LIMIT 1`,
    [identifier]
  );

  return result.rows[0] ?? null;
};

export const findUserById = async (id: string) => {
  const result = await pool.query(
    `SELECT id, phone, is_active, phone_verified_at
     FROM users
     WHERE id = $1`,
    [id]
  );

  return result.rows[0] ?? null;
};
// Marks the phone verified, but only if it is still the same number we verified
export const markPhoneVerified = async (
  userId: string,
  phone: string
): Promise<boolean> => {
  const result = await pool.query(
    `UPDATE users
     SET phone_verified_at = NOW(), updated_at = NOW()
     WHERE id = $1 AND phone = $2
     RETURNING id`,
    [userId, phone]
  );

  return result.rowCount === 1;
};