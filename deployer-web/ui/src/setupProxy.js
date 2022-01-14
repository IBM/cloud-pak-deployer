const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = function(app) {
  app.use(
    '/api/v1/*',
    createProxyMiddleware({
      target: 'http://149.81.2.152:32080',
      changeOrigin: true,
    })
  );
};