# 08 — ربط Laravel بخدمة المستودع (gRPC)

من هذه الخطوة كل الكميات في التطبيق حقيقية وقادمة من خدمة .NET:

```
Flutter ──REST──► Laravel ──gRPC (مهلة 2 ثانية)──► inventory-service (.NET) ──► PostgreSQL
```

**لا شيء تغيّر في الـ API الذي يستخدمه Flutter**: نفس الروابط ونفس الردود. ما تغيّر هو مصدر الكمية فقط.

## أين يحدث النداء؟

| ما يفعله المستخدم | النداء من Laravel إلى المستودع |
|---|---|
| يفتح قائمة المنتجات | `GetStockBatch` — **نداء واحد للصفحة كلها** |
| يفتح تفاصيل منتج | `GetStock` |
| ينشئ طلباً | `ReserveStock` — **نداء واحد لكل منتجات الطلب** |
| فشل حفظ الطلب بعد الحجز | `ReleaseStock` (وإن فشل يُعاد في الخلفية) |
| المسؤول يلغي طلباً | `ReleaseStock` |
| المسؤول يضيف منتجاً أو يعدّل الكمية | `SetStock` |

## ماذا يرى المستخدم عندما لا يسير كل شيء كما نريد؟

| الحالة | الرد للتطبيق |
|---|---|
| الكمية غير كافية | **409** `INSUFFICIENT_STOCK` مع `requested` و `available` لكل منتج — ولا يُنشأ الطلب |
| خدمة المستودع **متوقفة** | **503** `INVENTORY_UNAVAILABLE` (إنشاء طلب، إضافة منتج، تعديل كمية) |
| خدمة المستودع **بطيئة** | بعد **ثانيتين** بالضبط: **503** `INVENTORY_UNAVAILABLE` — المستخدم لا ينتظر بلا نهاية |
| عرض المنتجات والمستودع متوقف/بطيء | **200** والمنتجات تظهر، مع `stock: {"quantity": null, "status": "unavailable"}` |
| فشل الحفظ بعد الحجز | **500**، والكمية المحجوزة تُرجع للمستودع تلقائياً |

رسالة 503:
```json
{
  "error": {
    "code": "INVENTORY_UNAVAILABLE",
    "message": "The inventory service is not available right now. Please try again later.",
    "details": {}
  }
}
```
في Flutter: اعرض "تعذّر إتمام العملية الآن، حاول بعد قليل" مع زر **إعادة المحاولة**، ولا تعرض الطلب كأنه تم.

---

## جرّب بنفسك

### 1. المستودع متوقف
```bash
docker compose stop inventory-service
```
- `GET /products/1` ← 200 مع `"status": "unavailable"`.
- `POST /orders` ← **503** خلال أقل من ثانيتين.

```bash
docker compose start inventory-service
```

### 2. المستودع بطيء (يرد بعد 5 ثوانٍ، والمهلة ثانيتان)
```bash
INVENTORY_SIMULATED_DELAY_MS=5000 docker compose up -d inventory-service
```
- `POST /orders` ← **503** بعد ثانيتين (وليس بعد 5).
- في Postman انظر وقت الرد أسفل النتيجة (≈ 2000 ms).

للعودة للوضع الطبيعي:
```bash
docker compose up -d inventory-service
```

### 3. عدة طلبات على آخر قطعة (Race Condition)
```bash
# أرجع "Smart Watch" إلى قطعة واحدة
docker compose exec core-api php artisan inventory:seed-sample
```
ثم أرسل عدة طلبات `POST /orders` في نفس اللحظة على `Smart Watch` (id 3) —
في Postman: **Runner** ← اختر طلب إنشاء الطلب ← Iterations 10 ← بدون Delay.
النتيجة: **طلب واحد 201** والباقي **409**، والكمية في `GET /products/3` تصبح 0.

### 4. إرجاع الكميات التجريبية
```bash
docker compose exec core-api php artisan inventory:seed-sample
```
يعيد كل المنتجات التجريبية لكمياتها الأولى (Smart Watch = 1، Cotton T-Shirt = 100، ...).

---

## بعد `git pull` لهذه الخطوة
```bash
git pull
docker compose up -d --build --force-recreate
docker compose exec core-api php artisan inventory:seed-sample
```

> ⏳ **البناء هذه المرة يأخذ وقتاً أطول (10–20 دقيقة)**: صورة PHP تبني إضافة `grpc` من المصدر. يحدث مرة واحدة فقط.
> إذا كان Docker Desktop بطيئاً جداً أو توقف أثناء البناء: Settings ← Resources ← اجعل الذاكرة **6 GB** على الأقل، ثم أعد الأمر.

الأمر الأخير مهم لمن كانت عنده بيانات قديمة: قاعدة المستودع الجديدة فارغة، فيضع فيها الكميات التجريبية.
