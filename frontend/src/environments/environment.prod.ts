export const environment = {
  production: true,
  // In production, the frontend is served by nginx which proxies /api to the API service.
  // So we use a relative path.
  apiUrl: '/api',
};
