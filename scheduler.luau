--!optimize 2
--!native
--!strict

-- // O(1) ECS scheduler implementation
-- // Inspired by Linux's O(1) scheduler
-- // Maintain a min-heap for fairness of each tasks run by it

local Yumina = require("@yumina")

type Yumina = Yumina.Yumina
