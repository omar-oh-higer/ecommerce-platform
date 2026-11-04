# 05 — الإشعارات (Notifications)

كل ما يُرسل للمستخدم يُحفظ كإشعار، ويقرؤه التطبيق من الـ API.

| الطلب | الوصف |
|---|---|
| `GET /notifications` | إشعاراتي (الأحدث أولاً) |
| `GET /notifications/unread-count` | عدد غير المقروء (لشارة أيقونة الجرس) |
| `PATCH /notifications/{id}/read` | تعليم إشعار كمقروء |
| `PATCH /notifications/read-all` | تعليم الكل كمقروء |

كلها تحتاج `Authorization: Bearer {{token}}`. كل مستخدم يرى **إشعاراته فقط**.

---

## متى يصل إشعار؟

| الحدث | من يستلم | `type` |
|---|---|---|
| زبون أنشأ طلباً | الزبون نفسه | `order.placed` |
| زبون أنشأ طلباً | **كل المسؤولين** | `order.new` |
| المسؤول غيّر حالة طلب | صاحب الطلب | `order.status_changed` |

- لا يُرسل إشعار إذا فشل إنشاء الطلب، أو رُفض تغيير الحالة.
- الإشعارات تُرسل في الخلفية (حاوية `queue-worker`)، لذلك قد يتأخر ظهورها ثانية أو اثنتين بعد الطلب.

## شكل الإشعار

```json
{
  "id": "cc7922f8-ea17-4c01-be34-d5838f904b94",
  "type": "order.status_changed",
  "title": "Order confirmed",
  "message": "Your order #4 has been confirmed.",
  "payload": { "order_id": 4, "status": "confirmed", "previous_status": "pending" },
  "read": false,
  "read_at": null,
  "created_at": "2026-11-04T20:40:53+00:00"
}
```

| الحقل | الوصف |
|---|---|
| `id` | نص (UUID) وليس رقماً |
| `type` | ثابت تعتمد عليه في الكود: لاختيار الأيقونة والنص والشاشة التي تُفتح عند الضغط |
| `title`, `message` | نص جاهز بالإنجليزية. للعربية ترجم حسب `type` و `payload` (انظر الجدول أدناه) |
| `payload` | بيانات إضافية حسب النوع |
| `read` | `true` / `false` |

### `payload` لكل نوع

| `type` | `payload` | نص عربي مقترح | عند الضغط |
|---|---|---|---|
| `order.placed` | `order_id`, `status`, `total` | "تم استلام طلبك #4 بقيمة 35.00" | تفاصيل الطلب |
| `order.status_changed` | `order_id`, `status`, `previous_status` | حسب `status`: "تم تأكيد طلبك #4" / "طلبك #4 في الطريق" / "تم تسليم طلبك #4" / "تم إلغاء طلبك #4" | تفاصيل الطلب |
| `order.new` (للمسؤول) | `order_id`, `status`, `total`, `customer_id` | "طلب جديد #4 بقيمة 35.00" | تفاصيل الطلب في شاشة المسؤول |

---

## 1. قائمة الإشعارات

```bash
curl --location '{{base_url}}/notifications?page=1&per_page=20' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

غير المقروءة فقط:
```bash
curl --location '{{base_url}}/notifications?unread=1' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

الرد `200`: نفس شكل تقسيم الصفحات (`data`, `links`, `meta`)، و `meta.unread_count` فيه عدد غير المقروء:
```json
{
  "data": [ { "id": "cc79...", "type": "order.status_changed", "...": "..." } ],
  "links": { "first": "...", "last": "...", "prev": null, "next": null },
  "meta": { "current_page": 1, "last_page": 1, "per_page": 20, "total": 2, "unread_count": 2 }
}
```

## 2. عدد غير المقروء

```bash
curl --location '{{base_url}}/notifications/unread-count' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

```json
{ "data": { "unread_count": 2 } }
```

> طلب خفيف: مناسب للتحديث الدوري لشارة الجرس (مثلاً كل 30 ثانية، أو عند فتح التطبيق).
> الإشعارات اللحظية (WebSocket) تأتي في متطلب لاحق.

## 3. تعليم إشعار كمقروء

```bash
curl --location --request PATCH '{{base_url}}/notifications/cc7922f8-ea17-4c01-be34-d5838f904b94/read' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

- **200** الإشعار داخل `data` و `read: true`.
- **404** الإشعار غير موجود **أو يخص مستخدماً آخر**.

## 4. تعليم الكل كمقروء

```bash
curl --location --request PATCH '{{base_url}}/notifications/read-all' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

```json
{ "data": { "marked_as_read": 2 } }
```

---

## سيناريوهات اختبار في Postman

| # | السيناريو | المتوقع |
|---|---|---|
| 1 | الزبون ينشئ طلباً، ثم `GET /notifications` | إشعار `order.placed` |
| 2 | المسؤول `GET /notifications` | إشعار `order.new` لنفس الطلب |
| 3 | المسؤول يؤكد الطلب، ثم الزبون `GET /notifications` | إشعار `order.status_changed` بـ `status: confirmed` في الأعلى |
| 4 | `GET /notifications/unread-count` | العدد الصحيح |
| 5 | `PATCH /notifications/{id}/read` ثم `unread-count` | نقص بواحد |
| 6 | **زبون ثانٍ** يعلّم إشعار الزبون الأول كمقروء | **404** |
| 7 | إنشاء طلب على منتج نفدت كميته (409) | لا يصل أي إشعار |
| 8 | بدون توكن | 401 |
