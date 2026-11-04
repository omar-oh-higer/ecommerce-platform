# 07 — خدمة المستودع (Inventory Service — .NET gRPC)

> تطبيق Flutter **لا يتصل** بهذه الخدمة مباشرة. هو يكلّم Laravel فقط، و Laravel يكلّم خدمة المستودع.
> هذا الملف لتفهم الجزء الثاني من المشروع (قد تُسأل عنه في المقابلة)، ولتجربة الخدمة بنفسك.

```
Flutter ──REST──► Laravel (core-api) ──gRPC──► inventory-service (.NET 10) ──► PostgreSQL (inventory-db)
                        │
                        └──► MySQL (بيانات التطبيق)
```

| | |
|---|---|
| اللغة / الإطار | C# / .NET 10 (مختلف عن Laravel ← **Polyglot service**) |
| التواصل | **gRPC** على المنفذ `5001` |
| العقد المشترك | [`proto/inventory.proto`](../../proto/inventory.proto) |
| قاعدة البيانات | **PostgreSQL خاصة بها** (`inventory-db`) — Laravel لا يصل إليها أبداً |
| الكود | [`services/inventory-service`](../../services/inventory-service) |

## العمليات (من العقد)

| العملية | الوظيفة |
|---|---|
| `GetStock` / `GetStockBatch` | **معرفة الكمية**: كم بقي من هذا المنتج؟ |
| `ReserveStock` | **حجز الكمية**: كل منتجات الطلب في نداء واحد — الكل أو لا شيء |
| `ReleaseStock` | **إرجاع الكمية**: إذا فشل الطلب أو أُلغي |
| `SetStock` | تعديل الكمية من المسؤول |

## كيف يمنع الـ Race Condition؟
عدة طلبات في نفس اللحظة على آخر قطعة ← **ينجح طلب واحد فقط**.

كل خصم هو أمر SQL واحد بشرط:
```sql
UPDATE stock_items SET quantity = quantity - 1
WHERE product_id = 3 AND quantity >= 1;
```
- PostgreSQL يقفل الصف أثناء التحديث، والطلب التالي ينتظر ثم يعيد فحص الشرط على القيمة الجديدة.
- أول طلب يجعل الكمية 0؛ البقية لا يطابقون الشرط (0 صفوف) ← يُرفضون.
- الكمية لا تصبح سالبة أبداً (وعليها أيضاً قيد `CHECK (quantity >= 0)` في قاعدة البيانات).
- المنع في **قاعدة البيانات** وليس في الكود، لذلك يعمل حتى لو شغّلنا عدة نسخ من الخدمة.

قواعد إضافية:
- **كل الطلب أو لا شيء:** إذا نقص منتج واحد، يُلغى خصم الكل (transaction).
- **بدون deadlock:** الصفوف تُقفل دائماً بترتيب رقم المنتج.
- **Idempotent:** نفس `reservation_id` لا يحجز مرتين، والإرجاع مرتين لا يُرجع الكمية مرتين.

## حالات الفشل

| الحالة | رد الخدمة (gRPC status) |
|---|---|
| بيانات غير صحيحة (كمية سالبة، منتج مكرر...) | `INVALID_ARGUMENT` |
| الكمية غير كافية | `success: false` + `unavailable_items` |
| قاعدة بيانات المستودع متوقفة | `UNAVAILABLE` |
| انتهت مهلة النداء (deadline) | `DEADLINE_EXCEEDED` |

---

## جرّبها بنفسك

بعد `docker compose up -d` تعمل حاويتان جديدتان: `inventory-service` و `inventory-db`.

### بـ grpcurl (عبر Docker — لا تحتاج تثبيت شيء)

اختصار للأوامر التالية:
```bash
alias grpc='docker run --rm --network ecommerce-platform_default fullstorydev/grpcurl:v1.9.3 -plaintext'
```

```bash
# الخدمات المتاحة
grpc inventory-service:5001 list

# ضبط كمية منتج
grpc -d '{"product_id": 501, "quantity": 2}' inventory-service:5001 inventory.v1.Inventory/SetStock

# حجز أكثر من المتوفر ← رفض
grpc -d '{"reservation_id": "demo-1", "items": [{"product_id": 501, "quantity": 3}]}' \
  inventory-service:5001 inventory.v1.Inventory/ReserveStock

# حجز المتوفر ← نجاح
grpc -d '{"reservation_id": "demo-2", "items": [{"product_id": 501, "quantity": 2}]}' \
  inventory-service:5001 inventory.v1.Inventory/ReserveStock

# الكمية الآن
grpc -d '{"product_id": 501}' inventory-service:5001 inventory.v1.Inventory/GetStock

# إرجاع الحجز
grpc -d '{"reservation_id": "demo-2"}' inventory-service:5001 inventory.v1.Inventory/ReleaseStock
```

> في gRPC JSON الحقول ذات القيمة الافتراضية لا تظهر: `quantity: 0` و `success: false` يُحذفان من الرد.

### بـ Postman (gRPC)
1. **New → gRPC**، العنوان `localhost:5001`.
2. **Service definition → Use server reflection** (تظهر كل العمليات تلقائياً).
3. اختر `ReserveStock` واكتب الرسالة بصيغة JSON مثل الأمثلة أعلاه ← **Invoke**.

### تجربة "قاعدة بيانات المستودع متوقفة"
```bash
docker compose stop inventory-db
grpc -d '{"product_id": 501}' inventory-service:5001 inventory.v1.Inventory/GetStock
#  Code: Unavailable — Message: The inventory database is not available.
docker compose start inventory-db
```

## الاختبارات
13 اختباراً على **PostgreSQL حقيقية** (تُشغَّل تلقائياً في Docker عبر Testcontainers)، منها:
- 25 طلباً متزامناً على قطعة واحدة ← نجاح واحد فقط، والكمية 0.
- 30 طلباً متزامناً على 5 قطع ← 5 فقط تنجح.
- طلبات متزامنة على نفس المنتجين بترتيب معاكس ← بدون deadlock.
- إرجاع نفس الحجز 10 مرات في نفس اللحظة ← الكمية تُرجع مرة واحدة.

للتشغيل (يحتاج .NET 10 SDK و Docker):
```bash
cd services/inventory-service
dotnet test
```

---

> **حالياً** Laravel ما زال يستخدم نسخة وهمية من المستودع داخله.
> **الخطوة التالية** تربط Laravel بهذه الخدمة عبر gRPC، فتصبح كل الكميات في التطبيق قادمة منها.
