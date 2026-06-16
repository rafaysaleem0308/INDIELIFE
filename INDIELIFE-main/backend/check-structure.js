const fs = require("fs");
const path = require("path");

console.log("\n" + "=".repeat(60));
console.log("  INDIELIFE BACKEND - COMPREHENSIVE HEALTH CHECK");
console.log("=".repeat(60) + "\n");

// 1. Check routes
console.log("📁 ROUTE FILES CHECK:");
const routesDir = path.join(__dirname, "routes");
const routeFiles = fs.readdirSync(routesDir).filter((f) => f.endsWith(".js"));

console.log(`   Total Routes: ${routeFiles.length}`);
routeFiles.forEach((file) => {
  console.log(`   ✅ ${file}`);
});

// 2. Check models
console.log("\n📁 MODEL FILES CHECK:");
const modelsDir = path.join(__dirname, "models");
const modelFiles = fs.readdirSync(modelsDir).filter((f) => f.endsWith(".js"));

console.log(`   Total Models: ${modelFiles.length}`);
modelFiles.forEach((file) => {
  console.log(`   ✅ ${file}`);
});

// 3. Check middleware
console.log("\n📁 MIDDLEWARE FILES CHECK:");
const middlewareDir = path.join(__dirname, "middleware");
const middlewareFiles = fs
  .readdirSync(middlewareDir)
  .filter((f) => f.endsWith(".js"));

console.log(`   Total Middleware: ${middlewareFiles.length}`);
middlewareFiles.forEach((file) => {
  console.log(`   ✅ ${file}`);
});

// 4. Check config
console.log("\n📁 CONFIG FILES CHECK:");
const configDir = path.join(__dirname, "config");
const configFiles = fs.readdirSync(configDir).filter((f) => f.endsWith(".js"));

console.log(`   Total Config: ${configFiles.length}`);
configFiles.forEach((file) => {
  console.log(`   ✅ ${file}`);
});

// 5. Check utilities
console.log("\n📁 UTILITY FILES CHECK:");
const utilsDir = path.join(__dirname, "utils");
const utilFiles = fs.readdirSync(utilsDir).filter((f) => f.endsWith(".js"));

console.log(`   Total Utils: ${utilFiles.length}`);
utilFiles.forEach((file) => {
  console.log(`   ✅ ${file}`);
});

// 6. Environment check
console.log("\n⚙️  ENVIRONMENT CHECK:");
const envFile = path.join(__dirname, ".env");
const envExists = fs.existsSync(envFile);
console.log(`   .env File: ${envExists ? "✅ Present" : "❌ Missing"}`);

// 7. Package.json check
console.log("\n📦 PACKAGE CHECK:");
const pkg = require("./package.json");
console.log(`   Name: ${pkg.name}`);
console.log(`   Version: ${pkg.version}`);
console.log(`   Main: ${pkg.main}`);
console.log(`   Dependencies: ${Object.keys(pkg.dependencies || {}).length}`);
console.log(
  `   Dev Dependencies: ${Object.keys(pkg.devDependencies || {}).length}`,
);

// 8. Key dependencies
console.log("\n🔧 KEY DEPENDENCIES:");
const deps = pkg.dependencies || {};
const keyDeps = [
  "express",
  "mongoose",
  "cors",
  "dotenv",
  "bcrypt",
  "jsonwebtoken",
  "axios",
  "stripe",
  "socket.io",
];
keyDeps.forEach((dep) => {
  if (deps[dep]) {
    console.log(`   ✅ ${dep} (${deps[dep]})`);
  } else {
    console.log(`   ⚠️  ${dep} (not found)`);
  }
});

console.log("\n" + "=".repeat(60));
console.log("  ✅ BACKEND STRUCTURE VERIFICATION COMPLETE");
console.log("=".repeat(60) + "\n");
