# 03 — المنتجات والتصنيفات (Products & Categories)

| الطلب | من يستطيع | الوصف |
|---|---|---|
| `GET /categories` | الجميع | قائمة التصنيفات |
| `GET /products` | الجميع | قائمة المنتجات مع تقسيم الصفحات والتصفية |
| `GET /products/{id}` | الجميع | تفاصيل منتج مع الكمية المتوفرة |
| `POST /categories` | المسؤول فقط | إضافة تصنيف |
| `POST /products` | المسؤول فقط | إضافة منتج مع صورته وكميته |
| `PATCH /products/{id}/stock` | المسؤول فقط | تعديل الكمية في المخزون |

> الكمية المتوفرة لا تُخزَّن مع المنتج: التطبيق يسألها من **خدمة المستودع** في كل عرض.
> لذلك قد تكون "غير متاحة مؤقتاً" إذا كانت خدمة المستودع متوقفة (انظر `stock.status`).

---

## شكل المنتج

```json
{
  "id": 8,
  "name": "Gaming Mouse",
  "description": "RGB mouse",
  "price": "25.50",
  "image_url": "http://localhost:8000/storage/products/SizurDJW4OgLiAJsDCvmDcSQbpIPE0mdLif8Yjlh.png",
  "category": { "id": 1, "name": "Electronics", "slug": "electronics" },
  "stock": { "quantity": 5, "status": "in_stock" },
  "created_at": "2026-11-04T19:51:54+00:00"
}
```

| الحقل | ملاحظات لـ Flutter |
|---|---|
| `price` | **نص** وليس رقماً (`"25.50"`) حتى لا تضيع الكسور. للحساب: `double.parse(price)` أو استخدم `Decimal` |
| `image_url` | رابط كامل جاهز لـ `Image.network`. قد يكون `null` (منتجات البيانات التجريبية بلا صور) ← اعرض صورة بديلة |
| `stock.quantity` | عدد القطع المتوفرة، أو `null` إذا تعذّر سؤال المستودع |
| `stock.status` | `in_stock` / `out_of_stock` / `unavailable` |

### `stock.status`

| القيمة | المعنى | ماذا يعرض التطبيق |
|---|---|---|
| `in_stock` | `quantity > 0` | "متوفر (5)" وزر الشراء مفعّل |
| `out_of_stock` | `quantity = 0` | "نفدت الكمية" وزر الشراء معطّل |
| `unavailable` | خدمة المستودع متوقفة الآن، `quantity = null` | المنتج يظهر عادياً مع "الكمية غير متاحة حالياً" |

> ⚠️ في محاكي Android استبدل `localhost` في `image_url` بـ `10.0.2.2` (أو استخدم نفس `baseUrl` الذي تعمل عليه).

---

## 1. التصنيفات

```bash
curl --location '{{base_url}}/categories' \
--header 'Accept: application/json'
```

```json
{
  "data": [
    { "id": 2, "name": "Books", "slug": "books", "products_count": 2 },
    { "id": 3, "name": "Clothing", "slug": "clothing", "products_count": 2 },
    { "id": 1, "name": "Electronics", "slug": "electronics", "products_count": 3 }
  ]
}
```

## 2. قائمة المنتجات

```bash
curl --location '{{base_url}}/products?page=1&per_page=10' \
--header 'Accept: application/json'
```

| Parameter | اختياري | الوصف |
|---|---|---|
| `page` | نعم | رقم الصفحة (افتراضي 1) |
| `per_page` | نعم | عدد المنتجات في الصفحة، من 1 إلى 50 (افتراضي 15) |
| `category_id` | نعم | التصفية حسب التصنيف (من `GET /categories`) |
| `search` | نعم | البحث في اسم المنتج |

تصفية حسب التصنيف:
```bash
curl --location '{{base_url}}/products?category_id=1' \
--header 'Accept: application/json'
```

بحث:
```bash
curl --location '{{base_url}}/products?search=jacket' \
--header 'Accept: application/json'
```

الرد `200` (مختصر):
```json
{
  "data": [ { "id": 7, "name": "Winter Jacket", "price": "89.00", "stock": { "quantity": 8, "status": "in_stock" }, "...": "..." } ],
  "links": {
    "first": "http://localhost:8000/api/v1/products?per_page=2&page=1",
    "last": "http://localhost:8000/api/v1/products?per_page=2&page=4",
    "prev": null,
    "next": "http://localhost:8000/api/v1/products?per_page=2&page=2"
  },
  "meta": { "current_page": 1, "from": 1, "last_page": 4, "per_page": 2, "to": 2, "total": 8 }
}
```

**تقسيم الصفحات في Flutter (Infinite scroll):** اطلب الصفحة التالية عندما يصل المستخدم لآخر القائمة، وتوقّف عندما يكون `links.next == null` (أو `meta.current_page == meta.last_page`).

أخطاء:
- **422** `VALIDATION_FAILED` إذا كان `per_page` أكبر من 50، أو `category_id` غير موجود.

## 3. تفاصيل منتج

```bash
curl --location '{{base_url}}/products/1' \
--header 'Accept: application/json'
```

- **200** المنتج داخل `data` (الكمية مأخوذة من خدمة المستودع لحظة الطلب).
- **404**:
```json
{ "error": { "code": "NOT_FOUND", "message": "Product not found.", "details": {} } }
```

---

## 4. إضافة تصنيف (مسؤول)

```bash
curl --location '{{base_url}}/categories' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer {{token}}' \
--data-raw '{
    "name": "Toys & Games"
}'
```

- **201** `{"data": {"id": 4, "name": "Toys & Games", "slug": "toys-games"}}`
- **422** الاسم موجود من قبل.
- **403** إذا كان التوكن لزبون، **401** بدون توكن.

## 5. إضافة منتج مع صورة (مسؤول)

الطلب من نوع **`multipart/form-data`** (ليس JSON) لأنه يحمل ملفاً.

```bash
curl --location '{{base_url}}/products' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}' \
--form 'category_id="1"' \
--form 'name="Gaming Mouse"' \
--form 'description="RGB mouse"' \
--form 'price="25.50"' \
--form 'quantity="5"' \
--form 'image=@"/path/to/mouse.jpg"'
```

> **في Postman:** بعد الاستيراد افتح تبويب **Body → form-data**، وفي صف `image` اضغط **Select Files** واختر صورة من جهازك (المسار في الأمر مثال فقط).

| الحقل | الشروط |
|---|---|
| `category_id` | مطلوب، تصنيف موجود |
| `name` | مطلوب، حتى 255 حرفاً |
| `description` | اختياري، حتى 5000 حرف |
| `price` | مطلوب، أكبر من 0، حتى رقمين بعد الفاصلة |
| `quantity` | مطلوب، الكمية الأولية في المخزون (0 أو أكثر) |
| `image` | مطلوب، صورة **jpg / jpeg / png / webp** حتى **2 MB** (SVG مرفوض لأسباب أمنية) |

- **201** المنتج الجديد مع `image_url` و `stock.quantity`.
- **422** `VALIDATION_FAILED` (ملف ليس صورة، سعر سالب، ...).
- **503** `INVENTORY_UNAVAILABLE` — خدمة المستودع متوقفة: **لا يُحفظ المنتج ولا الصورة**. أعد المحاولة لاحقاً.

في Flutter (`dio`):
```dart
final form = FormData.fromMap({
  'category_id': 1,
  'name': 'Gaming Mouse',
  'description': 'RGB mouse',
  'price': '25.50',
  'quantity': 5,
  'image': await MultipartFile.fromFile(file.path, filename: 'mouse.jpg'),
});
await dio.post('/products', data: form);
```

## 6. تعديل الكمية (مسؤول)

```bash
curl --location --request PATCH '{{base_url}}/products/1/stock' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer {{token}}' \
--data-raw '{
    "quantity": 20
}'
```

- **200** المنتج مع `stock.quantity` الجديدة.
- **503** `INVENTORY_UNAVAILABLE` إذا كانت خدمة المستودع متوقفة.

```json
{
  "error": {
    "code": "INVENTORY_UNAVAILABLE",
    "message": "The inventory service is not available right now. Please try again later.",
    "details": {}
  }
}
```

---

## البيانات التجريبية الجاهزة
بعد التشغيل يوجد 3 تصنيفات و 7 منتجات (بدون صور)، منها:

| المنتج | الكمية | لاختبار |
|---|---|---|
| Smart Watch | 1 | آخر قطعة (مفيد لاحقاً لاختبار الطلبات المتزامنة) |
| Designing Data-Intensive Applications | 0 | `out_of_stock` |
| Cotton T-Shirt | 100 | `in_stock` |

## تجربة "خدمة المستودع متوقفة"
لترى كيف يتصرف التطبيق عندما تتوقف خدمة المستودع:

```bash
docker compose stop inventory-service
```
- عرض المنتجات يعمل، و `stock.status` = `unavailable`.
- إضافة منتج أو تعديل الكمية ← **503** خلال ثانيتين على الأكثر (مهلة النداء).

للعودة للوضع الطبيعي:
```bash
docker compose start inventory-service
```

وللتجربة مع مستودع **بطيء** (يرد بعد 5 ثوانٍ، والمهلة ثانيتان):
```bash
INVENTORY_SIMULATED_DELAY_MS=5000 docker compose up -d inventory-service
# ... جرّب، ثم أعده طبيعياً:
docker compose up -d inventory-service
```

لإرجاع كميات المنتجات التجريبية لقيمها الأولى (مثلاً قبل عرض):
```bash
docker compose exec core-api php artisan inventory:seed-sample
```

## سيناريوهات اختبار سريعة في Postman

| السيناريو | المتوقع |
|---|---|
| `GET /products?per_page=2` ثم اتبع `links.next` | صفحات متتالية حتى `next = null` |
| `GET /products?category_id=2` | منتجات Books فقط |
| `GET /products?per_page=500` | 422 |
| `GET /products/99999` | 404 `Product not found.` |
| `POST /products` بتوكن زبون | 403 |
| `POST /products` بملف PDF بدل صورة | 422 على `image` |
| `POST /products` بصورة صحيحة (مسؤول) | 201، وافتح `image_url` في المتصفح |
| `PATCH /products/{id}/stock` بـ `quantity: 0` | `stock.status = out_of_stock` |
