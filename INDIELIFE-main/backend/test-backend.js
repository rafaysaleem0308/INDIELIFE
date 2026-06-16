const http = require("http");

function makeRequest(method, path, headers = {}, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "localhost",
      port: 3000,
      path: path,
      method: method,
      headers: {
        "Content-Type": "application/json",
        ...headers,
      },
    };

    const req = http.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => {
        data += chunk;
      });
      res.on("end", () => {
        resolve({
          statusCode: res.statusCode,
          body: data,
          headers: res.headers,
        });
      });
    });

    req.on("error", reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function runTests() {
  console.log("\n============================================");
  console.log("  INDIELIFE BACKEND - ENDPOINT TESTS");
  console.log("============================================\n");

  try {
    // Test 1: Health Check
    console.log("🔍 Test 1: Health Check");
    let response = await makeRequest("GET", "/health");
    console.log(
      `   Status: ${response.statusCode === 200 ? "✅ OK" : "❌ FAILED"}`,
    );

    // Test 2: Admin Login
    console.log("\n🔍 Test 2: Admin Login");
    response = await makeRequest(
      "POST",
      "/api/admin/login",
      {},
      {
        email: "admin@indielife.com",
        password: "Admin@123",
      },
    );
    const loginData = JSON.parse(response.body);
    if (loginData.success) {
      console.log(`   Status: ✅ OK`);
      console.log(`   Token: ${loginData.accessToken.substring(0, 20)}...`);
      var adminToken = loginData.accessToken;
    } else {
      console.log(`   Status: ❌ FAILED - ${loginData.message}`);
    }

    // Test 3: Dashboard Stats
    console.log("\n🔍 Test 3: Dashboard Stats (requires auth)");
    response = await makeRequest("GET", "/api/admin/dashboard-stats", {
      Authorization: `Bearer ${adminToken}`,
    });
    if (response.statusCode === 200) {
      const data = JSON.parse(response.body);
      console.log(`   Status: ✅ OK`);
      console.log(`   - Total Users: ${data.stats.totalUsers}`);
      console.log(`   - Total Providers: ${data.stats.totalProviders}`);
      console.log(`   - Total Bookings: ${data.stats.totalBookings}`);
      console.log(`   - Total Revenue: $${data.stats.totalRevenue}`);
    } else {
      console.log(`   Status: ❌ FAILED (${response.statusCode})`);
    }

    // Test 4: Get Providers
    console.log("\n🔍 Test 4: Get Providers (requires auth)");
    response = await makeRequest("GET", "/api/admin/providers", {
      Authorization: `Bearer ${adminToken}`,
    });
    if (response.statusCode === 200) {
      const data = JSON.parse(response.body);
      console.log(`   Status: ✅ OK`);
      console.log(`   - Total Providers: ${data.providers.length}`);
    } else {
      console.log(`   Status: ❌ FAILED (${response.statusCode})`);
    }

    // Test 5: Get Users
    console.log("\n🔍 Test 5: Get Users (requires auth)");
    response = await makeRequest("GET", "/api/admin/users", {
      Authorization: `Bearer ${adminToken}`,
    });
    if (response.statusCode === 200) {
      const data = JSON.parse(response.body);
      console.log(`   Status: ✅ OK`);
      console.log(`   - Total Users: ${data.users.length}`);
    } else {
      console.log(`   Status: ❌ FAILED (${response.statusCode})`);
    }

    // Test 6: Get Services
    console.log("\n🔍 Test 6: Get Services (requires auth)");
    response = await makeRequest("GET", "/api/admin/services", {
      Authorization: `Bearer ${adminToken}`,
    });
    if (response.statusCode === 200) {
      const data = JSON.parse(response.body);
      console.log(`   Status: ✅ OK`);
      console.log(`   - Total Services: ${data.services.length}`);
    } else {
      console.log(`   Status: ❌ FAILED (${response.statusCode})`);
    }

    // Test 7: Get Bookings
    console.log("\n🔍 Test 7: Get Bookings (requires auth)");
    response = await makeRequest("GET", "/api/admin/bookings", {
      Authorization: `Bearer ${adminToken}`,
    });
    if (response.statusCode === 200) {
      const data = JSON.parse(response.body);
      console.log(`   Status: ✅ OK`);
      console.log(`   - Total Bookings: ${data.bookings.length}`);
    } else {
      console.log(`   Status: ❌ FAILED (${response.statusCode})`);
    }

    // Test 8: Get Housing
    console.log("\n🔍 Test 8: Get Housing (requires auth)");
    response = await makeRequest("GET", "/api/admin/housing", {
      Authorization: `Bearer ${adminToken}`,
    });
    if (response.statusCode === 200) {
      const data = JSON.parse(response.body);
      console.log(`   Status: ✅ OK`);
      console.log(`   - Total Properties: ${data.properties.length}`);
    } else {
      console.log(`   Status: ❌ FAILED (${response.statusCode})`);
    }

    // Test 9: Get Payments
    console.log("\n🔍 Test 9: Get Payments (requires auth)");
    response = await makeRequest("GET", "/api/admin/payments", {
      Authorization: `Bearer ${adminToken}`,
    });
    if (response.statusCode === 200) {
      const data = JSON.parse(response.body);
      console.log(`   Status: ✅ OK`);
      console.log(`   - Total Payments: ${data.payments.length}`);
    } else {
      console.log(`   Status: ❌ FAILED (${response.statusCode})`);
    }

    // Test 10: Get Settings
    console.log("\n🔍 Test 10: Get Settings (requires auth)");
    response = await makeRequest("GET", "/api/admin/settings", {
      Authorization: `Bearer ${adminToken}`,
    });
    if (response.statusCode === 200) {
      console.log(`   Status: ✅ OK`);
    } else {
      console.log(`   Status: ❌ FAILED (${response.statusCode})`);
    }

    console.log("\n============================================");
    console.log("  ✅ BACKEND TESTING COMPLETE");
    console.log("============================================\n");
    process.exit(0);
  } catch (error) {
    console.error("❌ Test Error:", error.message);
    process.exit(1);
  }
}

runTests();
