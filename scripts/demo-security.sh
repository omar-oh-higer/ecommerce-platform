#!/usr/bin/env bash
# =============================================================================
#  Security proof (slides 7-8): "a user only reaches what they are allowed to"
#
#  Usage (from the project folder, with Docker running):
#      bash scripts/demo-security.sh
#
#  What it does:
#    1. Signs in the order owner (customer) and the admin, registers a 2nd customer
#    2. The owner places a NEW order (so we know for sure who owns it)
#    3. Tries 4 things on that order and checks each answer:
#         owner     views it          -> 200 allowed
#         other     views it          -> 403 refused  (someone else's order)
#         owner     changes status    -> 403 refused  (only admins may)
#         admin     changes status    -> 200 allowed  (cancel = stock goes back)
# =============================================================================

API=http://localhost:8000/api/v1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# request METHOD PATH TOKEN [JSON]
#   Sends one API call. Sets two variables: CODE (HTTP status) and BODY (JSON).
request() {
    local args=(-s -X "$1" "$API$2"
                -H 'Accept: application/json'
                -H 'Content-Type: application/json'
                -w '\n%{http_code}')
    [ -n "$3" ] && args+=(-H "Authorization: Bearer $3")
    [ -n "$4" ] && args+=(-d "$4")

    local response
    response=$(curl "${args[@]}")
    CODE=${response##*$'\n'}     # last line  = status code
    BODY=${response%$'\n'*}      # the rest   = JSON body
}

# Pick a value out of the JSON body (no extra tools needed).
token_from_body() { sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p' <<< "$BODY"; }
order_id_from_body() { sed -n 's/.*"data":{"id":\([0-9]*\).*/\1/p' <<< "$BODY"; }
error_message() { sed -n 's/.*"message":"\([^"]*\)".*/\1/p' <<< "$BODY"; }

# check "description" EXPECTED_CODE
#   Prints ✅ when the API answered as expected, ❌ otherwise.
check() {
    if [ "$CODE" = "$2" ]; then mark="✅"; else mark="❌ (expected $2)"; fi
    printf '%-48s HTTP %s  %s  %s\n' "$1" "$CODE" "$mark" "$(error_message)"
}

# ---------------------------------------------------------------------------
# 1. Three users
# ---------------------------------------------------------------------------
echo "== 1. Users"

request POST /auth/login "" '{"email":"customer@store.test","password":"password"}'
OWNER=$(token_from_body)
check "Owner   (customer@store.test) signs in" 200

request POST /auth/login "" '{"email":"admin@store.test","password":"Admin@12345"}'
ADMIN=$(token_from_body)
check "Admin   (admin@store.test) signs in" 200

EMAIL="other$(date +%s)@store.test"
request POST /auth/register "" "{\"name\":\"Other\",\"email\":\"$EMAIL\",\"password\":\"Secret123\",\"password_confirmation\":\"Secret123\"}"
OTHER=$(token_from_body)
check "Other   ($EMAIL) registers" 201

# ---------------------------------------------------------------------------
# 2. The owner places an order (product 6 = Cotton T-Shirt)
# ---------------------------------------------------------------------------
echo
echo "== 2. Owner places an order"

request POST /orders "$OWNER" '{"items":[{"product_id":6,"quantity":1}]}'
ORDER=$(order_id_from_body)
check "Owner places order #$ORDER" 201

# ---------------------------------------------------------------------------
# 3. Who may do what with that order
# ---------------------------------------------------------------------------
echo
echo "== 3. Access to order #$ORDER"

request GET "/orders/$ORDER" "$OWNER"
check "Owner views their own order" 200

request GET "/orders/$ORDER" "$OTHER"
check "Other customer views it" 403

request PATCH "/orders/$ORDER/status" "$OWNER" '{"status":"delivered"}'
check "Owner tries to change its status" 403

request PATCH "/orders/$ORDER/status" "$ADMIN" '{"status":"cancelled"}'
check "Admin cancels it (stock goes back)" 200
