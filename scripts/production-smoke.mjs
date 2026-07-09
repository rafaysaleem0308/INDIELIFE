const BACKEND_URL = (process.env.BACKEND_URL || "https://indielife-backend.onrender.com").replace(/\/$/, "");
const AI_URL = (process.env.AI_URL || "https://indielife-ai-model.onrender.com").replace(/\/$/, "");
const ADMIN_URL = (process.env.ADMIN_URL || "https://indielife.vercel.app").replace(/\/$/, "");
const ADMIN_EMAIL = process.env.ADMIN_TEST_EMAIL;
const ADMIN_PASSWORD = process.env.ADMIN_TEST_PASSWORD;

const results = [];

async function check(name, request, validate) {
  try {
    const response = await request();
    const text = await response.text();
    let body = null;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      body = text;
    }
    const ok = validate ? validate(response, body) : response.ok;
    results.push({ name, ok, status: response.status, body });
  } catch (error) {
    results.push({ name, ok: false, status: "ERR", body: error.message });
  }
}

await check("backend health", () => fetch(`${BACKEND_URL}/health`), (res, body) => res.ok && body?.status === "ok");
await check("admin site", () => fetch(ADMIN_URL), (res, body) => res.ok && String(body).includes("admin-panel"));
await check("AI health", () => fetch(`${AI_URL}/api/health`), (res, body) => res.ok && body?.status === "ok");
await check("AI root alias", () => fetch(`${AI_URL}/`), (res, body) => res.ok && body?.status === "ok");

for (const [name, path] of [
  ["meal providers", "/api/services/meal-providers"],
  ["laundry providers", "/api/services/laundry-providers"],
  ["meals", "/api/services/meals"],
  ["featured services", "/api/services/recommendations/featured"],
  ["housing", "/api/housing"],
  ["community", "/api/community/posts"],
]) {
  await check(name, () => fetch(`${BACKEND_URL}${path}`), (res, body) => res.ok && body?.success === true);
}

await check(
  "protected services require auth",
  () => fetch(`${BACKEND_URL}/api/services`),
  (res) => res.status === 401,
);

await check(
  "invalid user login is clean",
  () =>
    fetch(`${BACKEND_URL}/signup/user/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: `missing-${Date.now()}@example.com`,
        password: "WrongPassword123!",
      }),
    }),
  (res, body) => res.status >= 400 && Boolean(body?.message || body?.error),
);

if (ADMIN_EMAIL && ADMIN_PASSWORD) {
  let adminToken = "";
  await check(
    "admin login",
    () =>
      fetch(`${BACKEND_URL}/api/admin/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: ADMIN_EMAIL, password: ADMIN_PASSWORD }),
      }),
    (res, body) => {
      adminToken = body?.accessToken || "";
      return res.ok && Boolean(adminToken);
    },
  );

  for (const [name, path] of [
    ["admin dashboard stats", "/api/admin/dashboard-stats"],
    ["admin users", "/api/admin/users"],
    ["admin providers", "/api/admin/providers?status=approved"],
    ["admin services", "/api/admin/services"],
    ["admin bookings", "/api/admin/bookings"],
    ["admin payments", "/api/admin/payments"],
    ["admin chats", "/api/admin/chats"],
    ["admin settings", "/api/admin/settings"],
  ]) {
    await check(
      name,
      () => fetch(`${BACKEND_URL}${path}`, { headers: { Authorization: `Bearer ${adminToken}` } }),
      (res) => res.ok,
    );
  }
} else {
  results.push({
    name: "admin authenticated checks",
    ok: true,
    status: "SKIP",
    body: "Set ADMIN_TEST_EMAIL and ADMIN_TEST_PASSWORD to enable.",
  });
}

const failures = results.filter((result) => !result.ok);
for (const result of results) {
  const status = result.ok ? "PASS" : "FAIL";
  console.log(`${status} ${result.name} (${result.status})`);
  if (!result.ok) {
    console.log(JSON.stringify(result.body).slice(0, 500));
  }
}

if (failures.length > 0) {
  process.exitCode = 1;
}
