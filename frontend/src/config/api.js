// Runtime configuration
let API_CONFIG = {
  auth: process.env.REACT_APP_AUTH_API_URL || 'http://localhost:4001/api',
  event: process.env.REACT_APP_EVENT_API_URL || 'http://localhost:4002/api',
  booking: process.env.REACT_APP_BOOKING_API_URL || 'http://localhost:4003/api'
};

// Load configuration from config.json at runtime
// This allows the API URLs to be configured without rebuilding the Docker image
const loadRuntimeConfig = async () => {
  try {
    const response = await fetch('/config.json');
    if (response.ok) {
      const config = await response.json();
      // Update the config object
      if (config.auth) API_CONFIG.auth = config.auth;
      if (config.event) API_CONFIG.event = config.event;
      if (config.booking) API_CONFIG.booking = config.booking;
      console.log('Loaded runtime config:', API_CONFIG);
      return API_CONFIG;
    }
  } catch (error) {
    console.warn('Failed to load runtime config, using defaults:', error);
  }
  return API_CONFIG;
};

// Export the loader function so it can be called at app startup
export { loadRuntimeConfig };
export default API_CONFIG;
