import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    setupFiles: ["./test/setup.ts"],
    passWithNoTests: true,
  },
  coverage: {
    provider: "v8",
    reporter: ["text", "html", "json-summary"],
    reportsDirectory: "coverage",
    include: ["app/**/*.{ts,tsx}"],
    exclude: ["**/*.d.ts", "**/node_modules/**", ".next/**"],
  },
});
