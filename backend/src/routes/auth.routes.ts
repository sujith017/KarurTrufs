import { Router } from "express";
import { loginUserSchema } from "../validators/user.validator";
import { validate } from "../middleware/validate";
import {
  loginController,
  refreshController,
  logoutAllController,
  logoutController,
  sendPhoneOtpController,
  verifyPhoneOtpController
} from "../controllers/auth.controller";
import { authenticate } from "../middleware/authenticate";
import { refreshTokenSchema ,verifyOtpSchema} from "../validators/auth.validator";
import {
  loginLimiter,
  refreshLimiter,
  otpSendLimiter,
  otpVerifyLimiter
} from "../middleware/rateLimiters";

const router = Router();

router.post("/login", loginLimiter, validate(loginUserSchema), loginController);
router.post("/refresh", refreshLimiter, validate(refreshTokenSchema), refreshController);

router.get("/me", authenticate, (req, res) => {
  res.status(200).json({ success: true, data: req.auth });
});

router.post("/logout", authenticate, logoutController);
router.post("/logout-all", authenticate, logoutAllController);

router.post(
  "/phone/send-otp",
  authenticate,
  otpSendLimiter,
  sendPhoneOtpController
);
router.post(
  "/phone/verify-otp",
  authenticate,
  otpVerifyLimiter,
  validate(verifyOtpSchema),
  verifyPhoneOtpController
);
export default router;