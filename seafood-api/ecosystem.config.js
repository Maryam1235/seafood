// pm2 process definition for seafood-api.
// Start with:  pm2 start ecosystem.config.js
//
// cwd is pinned to this folder so the relative paths in .env
// (GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json) resolve correctly,
// and --env-file loads .env before the app boots.
module.exports = {
  apps: [
    {
      name: 'seafood-api',
      script: 'dist/main.js',
      cwd: __dirname,
      node_args: '--env-file=.env',
      instances: 1,
      autorestart: true,
      max_memory_restart: '300M',
      env: {
        NODE_ENV: 'production',
        PORT: 3001, // 3000 is taken by the existing Next.js site
      },
    },
  ],
};
