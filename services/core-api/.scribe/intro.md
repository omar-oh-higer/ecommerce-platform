# Introduction

REST API of the core application (Laravel). Damascus University — Internet Applications project 2026.

<aside>
    <strong>Base URL</strong>: <code>http://localhost:8000</code>
</aside>

    Every endpoint is served under `/api/v1` and returns JSON. Always send `Accept: application/json`.

    **Errors** always have the same shape:

    ```json
    {"error": {"code": "VALIDATION_FAILED", "message": "The given data was invalid.", "details": {}}}
    ```

    Rely on `error.code` (stable), not on `message`. Main codes: `UNAUTHENTICATED` / `INVALID_TOKEN` (401),
    `FORBIDDEN` (403), `NOT_FOUND` (404), `INSUFFICIENT_STOCK` / `INVALID_STATUS_TRANSITION` (409),
    `VALIDATION_FAILED` (422), `TOO_MANY_REQUESTS` (429), `INVENTORY_UNAVAILABLE` (503).

    **Lists** are paginated: `data`, `links` (`next` is `null` on the last page) and `meta` (`current_page`, `last_page`, `per_page`, `total`).

    <aside>Ready-made accounts after setup: admin <code>admin@store.test</code> / <code>Admin@12345</code>,
    customer <code>customer@store.test</code> / <code>password</code>.
    Use <b>Try it out</b> on <code>POST /auth/login</code>, copy <code>access_token</code>, then paste it in the auth field of any protected endpoint.</aside>

