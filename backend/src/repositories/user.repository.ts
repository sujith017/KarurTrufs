import { pool } from "../config/db";

export const findUserByEmail = async (email: string) => {
  const result = await pool.query(
    `SELECT id, full_name, email, phone, password_hash
     FROM users
     WHERE email = $1`,
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