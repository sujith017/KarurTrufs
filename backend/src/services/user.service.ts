import {
  findUserByEmail,
  findUserByPhone,
  createUser,
  isUniqueViolation,
} from "../repositories/user.repository";

import { hashPassword } from "../utils/password";
import { AppError } from "../utils/AppError";

export const registerUser = async (data: {
  fullName: string;
  email: string;
  phone: string;
  password: string;
}) => {
  const existingEmail = await findUserByEmail(data.email);

  if (existingEmail) {
    throw new AppError("Email is already registered", 409);
  }

  const existingPhone = await findUserByPhone(data.phone);

  if (existingPhone) {
    throw new AppError("Phone number is already registered", 409);
  }

  const passwordHash = await hashPassword(data.password);

  try {
    const user = await createUser({
      fullName: data.fullName,
      email: data.email,
      phone: data.phone,
      passwordHash,
    });

    return user;
  } catch (error) {
    if (isUniqueViolation(error)) {
  const databaseError = error as {
    code: string;
    constraint?: string;
  };

  switch (databaseError.constraint) {
    case "users_email_unique_idx":
      throw new AppError("Email is already registered", 409);

    case "users_phone_unique_idx":
      throw new AppError("Phone number is already registered", 409);

    default:
      throw new AppError("A unique value already exists", 409);
  }
}

throw error;
  }
};