import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // Keep integration tests separate from unit tests
    include: ['src/**/*.integration.test.ts'],

    // CRITICAL: run sequentially, not in parallel
    // RLS tests depend on auth state
    sequence: {
      shuffle: false,
      concurrent: false,
    },
    fileParallelism: false,

    // Load environment variables from .env.test
    env: {
      // dotenv will load .env.test
    },

    // Longer timeout for network requests
    testTimeout: 15000,

    // Optional: setup file for test initialization
    setupFiles: ['./src/tests/integration-setup.ts'],
  },
})
