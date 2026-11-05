# Flutter demo script (Requirements 1 and 2)

Run the backend first (`docker compose up -d --build --force-recreate`, then once
`docker compose exec core-api php artisan inventory:seed-sample` on a fresh database).
Accounts: customer `customer@store.test` / `password`, admin `admin@store.test` / `Admin@12345`.

Apps:
```bash
cd mobile    && flutter run --dart-define=API_BASE_URL=http://localhost:8000      # Android emulator: http://10.0.2.2:8000
cd dashboard && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

## Required functions
| Function | Where to show it |
|---|---|
| User registration | Mobile: Sign in, Create an account |
| Add products with images and show them | Dashboard: Products, Add product (choose a JPG/PNG/WebP up to 2 MB); then the product with its image in the mobile product list |
| Create orders | Mobile: product, Add to cart, Cart, Checkout, Place order |
| Inventory management | Dashboard: Products, Edit stock; the new quantity shows in the mobile app |
| Order status tracking | Dashboard: Orders, open an order, press the status button; mobile: My orders shows the timeline and a notification arrives |

## Security (Requirement 1)
| # | Scenario | Steps | Expected |
|---|---|---|---|
| S1 | A user only sees their own orders | Register a second customer, place an order with each; open My orders on each | Each list has only their own orders |
| S2 | Opening someone else's order | With customer B's token call `GET /api/v1/orders/{id of A's order}` (Postman collection at `/docs/collection.json`) | 403 `FORBIDDEN` |
| S3 | Only the admin changes status | With a customer token call `PATCH /api/v1/orders/{id}/status` | 403 `FORBIDDEN`; the mobile app has no such button |
| S4 | Customers cannot enter the dashboard | Sign in to the dashboard as `customer@store.test` | Refused: "This area is for administrators only." |
| S5 | Login attempt limit | Mobile: sign in with a wrong password 6 times | 6th attempt: "Too many attempts ... try again in 60 s" |
| S6 | Expired or invalid token | Sign in, then in Postman invalidate the token with `POST /auth/logout`, then use the app | The app returns to the sign-in screen with "Your session has expired" |
| S7 | Admin only creates products | Customer token on `POST /api/v1/products` | 403 |
| S8 | Server rejects bad input even if the client is bypassed | `POST /products` with price `-1` and an SVG file | 422 with errors for `price` and `image` |

## Failure handling (Requirement 2)
| # | Scenario | Steps | Expected |
|---|---|---|---|
| F1 | Not enough stock | Add "Designing Data-Intensive Applications" (stock 0) via the API, or add 2 Smart Watches and have someone buy 1 first | Checkout shows the product with "requested / available" and "Update my cart"; no order and nothing reserved |
| F2 | Mixed order | Cart with an available product and a sold-out one | Whole order refused; the available product's stock is unchanged |
| F3 | The last item | Two emulators (or the app and Postman) order the last Smart Watch (stock 1) at the same time | Exactly one order succeeds, the other gets the stock message |
| F4 | Inventory service down | `docker compose stop inventory-service`. Open a product, then try to place an order | Product shows "Stock unavailable"; checkout shows "Cannot place the order right now ... Nothing was changed" within about 2 s, cart kept. `docker compose start inventory-service` and press Try again: it works |
| F5 | Inventory service slow | `INVENTORY_SIMULATED_DELAY_MS=5000 docker compose up -d inventory-service` then order | Same clear 503 message after the timeout (no endless spinner). Restore with the delay set to 0 |
| F6 | Double tap | Tap Place order twice quickly | One order only (button disabled while sending) |
| F7 | Backend unreachable | Stop the whole stack, open the app | "Cannot reach the server" with a Try again button |

## Reset test data
Cancel test orders from the dashboard to return their stock, or set quantities again with
`docker compose exec core-api php artisan inventory:seed-sample`.
