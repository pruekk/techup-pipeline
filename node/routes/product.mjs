import express from "express";
const router = express.Router();

router.get("/view", (req, res) => {
  // Example response, replace with real product logic as needed
  res.json({ message: "Product view endpoint" });
});

export default router;
