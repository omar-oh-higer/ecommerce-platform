# Flutter architecture and security notes

## Structure
```
packages/shop_core/   shared by both apps: models, ApiClient, error mapping, repositories, shared cubits
mobile/               customer app: catalogue, cart, checkout, orders, notifications
dashboard/            admin app (Flutter Web): orders, products, categories, notifications
```
Screens never call HTTP. Flow: `Page -> Cubit -> Repository -> ApiClient (Dio)`.
State management is Bloc/Cubit; navigation is go_router with a redirect that depends on `AuthCubit`.

## Where to find things
| Topic | File |
|---|---|
| HTTP client, timeouts (10 s connect, 15 s receive) | `packages/shop_core/lib/src/network/api_client.dart` |
| Bearer token and single-flight refresh | `.../network/auth_interceptor.dart` |
| Backend error codes mapped to typed failures | `.../errors/failure_mapper.dart`, `app_failure.dart` |
| Login, register, restore session, logout | `.../auth/auth_repository.dart`, `auth_cubit.dart` |
| Money in integer cents (never `double`) | `.../models/money.dart` |
| Cart (20 lines, 100 per line, one cart per user) | `mobile/lib/features/cart/cart_cubit.dart` |
| Checkout and its failure screens | `mobile/lib/features/orders/checkout_cubit.dart`, `checkout_page.dart` |
| Notifications: polling behind an interface | `.../notifications/notification_source.dart` |
| Admin product form rules | `dashboard/lib/features/products/product_form.dart` |

## Security checklist
| Topic | What the apps do |
|---|---|
| Token storage | Mobile: Keychain/Keystore (`flutter_secure_storage`). Dashboard: `sessionStorage` (cleared when the tab closes, not shared between tabs). Never in SharedPreferences or localStorage |
| Token in logs | Never logged or printed (no logging interceptor) |
| Sign out | Calls `/auth/logout` (server invalidates the token), always clears the local token, resets notifications and the in-memory cart |
| Expired token | One shared refresh (the server invalidates the old token at once, so parallel refreshes would break each other), then the request is replayed once. If refresh fails: back to sign in |
| Roles | The dashboard refuses non-admin accounts after login. This is only convenience: the server enforces roles (customer token gets 403 on admin calls) |
| Other people's data | The client never asks for another user's data; the server returns only the user's own orders and answers 403 for someone else's order |
| Prices | Never sent by the client; the server computes totals. Shown from strings with integer math |
| Input | Forms validate like the server (email, password rules, price, stock, image type and size). The server validates again and its field errors are shown |
| Shared phone | Cart is stored per user id; the other user never sees it |
| Rate limits | 429 is shown with the wait time from `Retry-After` |
| Transport | Plain `http` only for local development (Android debug manifest, iOS `NSAllowsLocalNetworking`). A release build refuses an `API_BASE_URL` that is not `https://` or a private/local address |
| Image upload | Type and size checked before upload; SVG rejected |
| Failed requests | Every call has timeouts; 503 and network errors show a message and a retry, never an endless spinner; no partial state (cart kept when an order is refused) |

## Known limits of the backend
No endpoints to edit or delete a product or category, list users or get statistics. Notifications are
polled every 30 s; real-time delivery comes in a later requirement and only needs a new
`NotificationSource`. The browser cannot read `Retry-After` because the server does not expose it through CORS.
