import { Router } from "express";
import { registerUserSchema } from "../validators/user.validator";
import { validate } from "../middleware/validate";
import { registerUserController } from "../controllers/user.controller";

const router = Router();

router.post(
  "/register",
  validate(registerUserSchema),
  registerUserController
);

export default router;