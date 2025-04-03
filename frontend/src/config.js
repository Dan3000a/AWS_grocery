const getBackendUrl = () => {
    // Use the injected URL from the window object, or fall back to environment variable
    return window.REACT_APP_BACKEND_SERVER || process.env.REACT_APP_BACKEND_SERVER || 'http://grocerymate-alb-1936728233.eu-central-1.elb.amazonaws.com';
};

export const API_BASE_URL = getBackendUrl();