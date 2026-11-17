import { Router } from "express";
import { loginUserSchema } from "../validators/user.validator";
import { validate } from "../middleware/validate";
import { loginController , refreshController , logoutAllController,logoutController} from "../controllers/auth.controller";
import { authenticate } from "../middleware/authenticate";
import { refreshTokenSchema } from "../validators/auth.validator";
import { loginLimiter , refreshLimiter } from "../middleware/rateLimiters";
const router = Router();

router.post("/login", validate(loginUserSchema), loginController);



router.get("/me", authenticate, (req, res) => {
    res.status(200).json({ success: true, data: req.auth });
});

router.post("/refresh", validate(refreshTokenSchema), refreshController);

router.post("/logout", authenticate, logoutController);
router.post("/logout-all", authenticate, logoutAllController);
router.post("/login", loginLimiter, validate(loginUserSchema), loginController);
router.post("/refresh", refreshLimiter, validate(refreshTokenSchema), refreshController);

export default router;