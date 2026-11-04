# Authenticating requests

To authenticate requests, include an **`Authorization`** header with the value **`"Bearer {YOUR_JWT_TOKEN}"`**.

All authenticated endpoints are marked with a `requires authentication` badge in the documentation below.

Get a JWT from <code>POST /api/v1/auth/login</code> (field <code>access_token</code>) and send it as <code>Authorization: Bearer {token}</code>. Tokens expire after 60 minutes; use <code>POST /api/v1/auth/refresh</code>.
