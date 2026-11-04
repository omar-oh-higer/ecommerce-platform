# 04 — الطلبات (Orders)

| الطلب | من يستطيع | الوصف |
|---|---|---|
| `POST /orders` | أي مستخدم مسجّل | إنشاء طلب |
| `GET /orders` | أي مستخدم مسجّل | الزبون: طلباته فقط — المسؤول: كل الطلبات |
| `GET /orders/{id}` | صاحب الطلب أو المسؤول | تفاصيل طلب |
| `PATCH /orders/{id}/status` | **المسؤول فقط** | تغيير حالة الطلب |

كل هذه الطلبات تحتاج `Authorization: Bearer {{token}}`.

---

## دورة حياة الطلب

```
pending ──► confirmed ──► shipped ──► delivered
   │            │
   └──► cancelled ◄┘
```

| الحالة | المعنى | نص مقترح في التطبيق |
|---|---|---|
| `pending` | أُنشئ وحُجزت كميته | قيد المراجعة |
| `confirmed` | وافق عليه المسؤول | تم التأكيد |
| `shipped` | خرج للشحن | قيد التوصيل |
| `delivered` | وصل للزبون | تم التسليم |
| `cancelled` | أُلغي وأُرجعت الكمية للمخزون | ملغى |

## شكل الطلب

```json
{
  "id": 1,
  "status": "pending",
  "total": "53.50",
  "items": [
    { "product_id": 6, "name": "Cotton T-Shirt", "unit_price": "12.00", "quantity": 2, "line_total": "24.00" },
    { "product_id": 2, "name": "USB-C Charger 65W", "unit_price": "29.50", "quantity": 1, "line_total": "29.50" }
  ],
  "created_at": "2026-11-04T20:24:14+00:00",
  "updated_at": "2026-11-04T20:24:14+00:00"
}
```

| الحقل | ملاحظات |
|---|---|
| `total`, `unit_price`, `line_total` | **نص** مثل الأسعار في المنتجات |
| `items[].name`, `unit_price` | محفوظة لحظة الطلب: إذا تغيّر سعر المنتج لاحقاً لا يتغير الطلب القديم |
| `items` | يظهر في إنشاء الطلب وتفاصيله. في القائمة يظهر بدلاً منه `items_count` |
| `customer` | **للمسؤول فقط**: `{id, name, email}` |
| `next_statuses` | **للمسؤول فقط**: الحالات المسموح الانتقال إليها — اعرض أزرارها فقط |

---

## 1. إنشاء طلب

```bash
curl --location '{{base_url}}/orders' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer {{token}}' \
--data-raw '{
    "items": [
        { "product_id": 6, "quantity": 2 },
        { "product_id": 2, "quantity": 1 }
    ]
}'
```

| الحقل | الشروط |
|---|---|
| `items` | مطلوب، من 1 إلى 20 منتجاً |
| `items[].product_id` | منتج موجود، **بدون تكرار** (اجمع الكمية في سطر واحد) |
| `items[].quantity` | من 1 إلى 100 |

> لا ترسل السعر: الخادم يحسب السعر والمجموع من قاعدة البيانات دائماً (أي سعر يُرسل يُتجاهل).

### ماذا يحدث في الخادم
1. **نداء واحد** لخدمة المستودع يحجز كل المنتجات معاً (الكل أو لا شيء).
2. إذا وافق المستودع يُحفظ الطلب. إذا فشل الحفظ لأي سبب تُرجع الكمية المحجوزة تلقائياً.

### الردود

**201** الطلب الجديد (حالته `pending`).

**409 `INSUFFICIENT_STOCK`** — الكمية غير كافية لبعض المنتجات، **ولا يُنشأ الطلب** (ولا يُحجز أي منتج):
```json
{
  "error": {
    "code": "INSUFFICIENT_STOCK",
    "message": "Some products do not have enough stock.",
    "details": {
      "items": [
        { "product_id": 3, "name": "Smart Watch", "requested": 2, "available": 1 }
      ]
    }
  }
}
```
في Flutter: اعرض لكل منتج في `details.items` رسالة مثل "Smart Watch: المتوفر 1 فقط"، واقترح تعديل الكمية في السلة.

**503 `INVENTORY_UNAVAILABLE`** — خدمة المستودع متوقفة أو بطيئة. **لا يُنشأ الطلب.** اعرض "تعذّر إتمام الطلب الآن، حاول بعد قليل" مع زر إعادة المحاولة.

**422** بيانات غير صحيحة (منتج غير موجود، كمية 0، منتج مكرر):
```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "The given data was invalid.",
    "details": {
      "items.0.quantity": ["The items.0.quantity field must be at least 1."],
      "items.1.product_id": ["The selected items.1.product_id is invalid."]
    }
  }
}
```

**429** أكثر من 10 طلبات في الدقيقة لنفس المستخدم.

## 2. قائمة الطلبات

```bash
curl --location '{{base_url}}/orders?page=1&per_page=10' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

| Parameter | الوصف |
|---|---|
| `status` | اختياري: `pending` / `confirmed` / `shipped` / `delivered` / `cancelled` |
| `page`, `per_page` | تقسيم الصفحات (حتى 50) — نفس شكل `links` و `meta` في المنتجات |

- بتوكن **زبون**: طلباته فقط.
- بتوكن **مسؤول**: كل الطلبات، ومع كل طلب `customer` و `next_statuses`.

طلباتي الملغاة فقط:
```bash
curl --location '{{base_url}}/orders?status=cancelled' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

## 3. تفاصيل طلب

```bash
curl --location '{{base_url}}/orders/1' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

- **200** الطلب مع `items`.
- **403** الطلب لزبون آخر:
```json
{ "error": { "code": "FORBIDDEN", "message": "You are not allowed to view this order.", "details": {} } }
```
- **404** `Order not found.`

## 4. تغيير حالة الطلب (مسؤول)

```bash
curl --location --request PATCH '{{base_url}}/orders/1/status' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer {{token}}' \
--data-raw '{
    "status": "confirmed"
}'
```

- **200** الطلب بحالته الجديدة و `next_statuses` المحدّثة.
- **409 `INVALID_STATUS_TRANSITION`** انتقال غير مسموح (مثلاً `delivered` ← `cancelled`):
```json
{
  "error": {
    "code": "INVALID_STATUS_TRANSITION",
    "message": "An order cannot move from 'delivered' to 'cancelled'.",
    "details": { "current": "delivered", "allowed": [] }
  }
}
```
- **403** بتوكن زبون — حتى على طلبه هو:
```json
{ "error": { "code": "FORBIDDEN", "message": "This action is reserved for administrators.", "details": {} } }
```
- عند `cancelled` تُرجع كمية الطلب للمخزون تلقائياً (مرة واحدة فقط).

---

## سيناريوهات اختبار في Postman

استخدم الحسابات الجاهزة، وأنشئ زبوناً ثانياً من `POST /auth/register`.

| # | السيناريو | المتوقع |
|---|---|---|
| 1 | الزبون ينشئ طلباً على `Cotton T-Shirt` (id 6) | 201، والكمية في `GET /products/6` نقصت |
| 2 | طلب على `Designing Data-Intensive Applications` (id 5، كميته 0) | 409 `INSUFFICIENT_STOCK` |
| 3 | طلب على منتجين: أحدهما متوفر والآخر لا | 409، والمنتج المتوفر **لم تنقص** كميته |
| 4 | إرسال `price: 0.01` مع المنتج | يُتجاهل، والمجموع بالسعر الحقيقي |
| 5 | **الزبون الثاني يفتح طلب الزبون الأول** | **403** |
| 6 | **الزبون يغيّر حالة طلبه** | **403** |
| 7 | المسؤول: `confirmed` ← `shipped` ← `delivered` | 200 في كل خطوة |
| 8 | المسؤول يلغي طلباً `delivered` | 409 `INVALID_STATUS_TRANSITION` |
| 9 | المسؤول يلغي طلباً `pending` | 200، والكمية رجعت للمنتج |
| 10 | `docker compose stop inventory-service` ثم إنشاء طلب | 503 خلال ثانيتين، ولا يظهر الطلب في القائمة (أعدها بـ `docker compose start inventory-service`) |

> السيناريوهان 5 و 6 هما **الإثبات المطلوب في المتطلب الأول**: مستخدم يحاول الوصول إلى طلب غيره، أو تنفيذ عملية ليست من صلاحيته ← يُرفض.
