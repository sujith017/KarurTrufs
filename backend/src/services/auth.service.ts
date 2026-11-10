import { findUserByIdentifier } from "../repositories/user.repository";
import { comparePassword } from "../utils/password";
import { AppError } from "../utils/AppError";

export const loginUser = async (data: {
  identifier: string;
  password: string;
}) => {
  // 1. Find user by email or phone
  const user = await findUserByIdentifier(data.identifier);

  // 2. Check whether user exists
  if (!user) {
    throw new AppError("Invalid email/phone or password", 401);
  }

  // 3. Check whether account is active
  if (!user.is_active) {
    throw new AppError("Your account is inactive", 403);
  }

  // 4. Verify password
  const isPasswordValid = await comparePassword(
    data.password,
    user.password_hash
  );

  if (!isPasswordValid) {
    throw new AppError("Invalid email/phone or password", 401);
  }

  // 5. Return safe user information
  return {
    id: user.id,
    full_name: user.full_name,
    email: user.email,
    phone: user.phone,
  };
};