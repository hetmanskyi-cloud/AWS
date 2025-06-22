/**
 * @fileoverview CloudFront Function to add essential security headers to every viewer response.
 *
 * @description
 * This function intercepts responses just before they are sent to the viewer (event type: viewer-response).
 * It injects several HTTP security headers to enhance protection against common web vulnerabilities
 * such as Cross-Site Scripting (XSS), clickjacking, and protocol downgrade attacks.
 * This ensures a consistent security posture across all content served by the CloudFront distribution.
 *
 * @param {object} event - The CloudFront event object containing request and response details.
 * @returns {object} The modified response object with added security headers.
 */
function handler(event) {
    // Get a reference to the response object.
    const response = event.response;
    const headers = response.headers;

    // --- Add/Overwrite Security Headers ---

    // Strict-Transport-Security (HSTS): Enforces HTTPS communication for 2 years.
    headers['strict-transport-security'] = { value: 'max-age=63072000; includeSubDomains; preload' };

    // X-Content-Type-Options: Prevents browsers from MIME-sniffing a response away from the declared content-type.
    headers['x-content-type-options'] = { value: 'nosniff' };

    // X-Frame-Options: Protects against clickjacking attacks by preventing the page from being rendered in a frame.
    headers['x-frame-options'] = { value: 'SAMEORIGIN' };

    // X-XSS-Protection: Enables the cross-site scripting (XSS) filter built into most recent web browsers.
    headers['x-xss-protection'] = { value: '1; mode=block' };

    // Content-Security-Policy (CSP): A powerful tool to control which resources a user agent is allowed to load.
    // This is a very strict example policy; it should be carefully tailored for a real application.
    headers['content-security-policy'] = { value: "default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self'; object-src 'none';" };

    // Return the modified response to CloudFront to be sent to the viewer.
    return response;
}
