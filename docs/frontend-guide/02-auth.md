# 02 — المصادقة (Auth)

المصادقة بـ **JWT**: بعد التسجيل أو الدخول تحصل على `access_token`، وترسله في كل طلب محمي:

```
Authorization: Bearer <access_token>
```

| الطلب | محمي؟ | الوصف |
|---|---|---|
| `POST /auth/register` | لا | إنشاء حساب زبون |
| `POST /auth/login` | لا | الدخول |
| `GET /auth/me` | نعم | بيانات المستخدم الحالي |
| `POST /auth/refresh` | نعم | توكن جديد بدل الحالي |
| `POST /auth/logout` | نعم | الخروج وإلغاء التوكن |

## شكل رد التوكن
`register` و `login` و `refresh` ترجع نفس الشكل:

```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": 3,
    "name": "Omar",
    "email": "omar@example.com",
    "role": "customer",
    "created_at": "2026-11-04T10:15:00+00:00"
  }
}
```

| الحقل | الوصف |
|---|---|
| `access_token` | التوكن؛ احفظه في `flutter_secure_storage` (ليس `SharedPreferences`) |
| `expires_in` | صلاحية التوكن بالثواني (ساعة) |
| `user.role` | `customer` أو `admin`؛ استخدمه لإظهار/إخفاء شاشات المسؤول |

---

## 1. التسجيل

```bash
curl --location '{{base_url}}/auth/register' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "Omar",
    "email": "omar@example.com",
    "password": "Secret123",
    "password_confirmation": "Secret123"
}'
```

| الحقل | الشروط |
|---|---|
| `name` | مطلوب، حتى 255 حرفاً |
| `email` | مطلوب، بريد صحيح، غير مستخدم من قبل |
| `password` | مطلوب، 8 أحرف على الأقل، فيها حروف وأرقام |
| `password_confirmation` | يطابق `password` |

- **201** رد التوكن (الحساب دائماً `customer`؛ إرسال `"role": "admin"` يُتجاهل).
- **422** `VALIDATION_FAILED` مع أخطاء الحقول.
- **429** أكثر من 10 تسجيلات في الدقيقة من نفس الجهاز.

## 2. الدخول

```bash
curl --location '{{base_url}}/auth/login' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--data-raw '{
    "email": "customer@store.test",
    "password": "password"
}'
```

دخول كمسؤول:

```bash
curl --location '{{base_url}}/auth/login' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--data-raw '{
    "email": "admin@store.test",
    "password": "Admin@12345"
}'
```

- **200** رد التوكن.
- **401** `INVALID_CREDENTIALS` — نفس الرسالة سواء كان البريد خاطئاً أو كلمة المرور (لأسباب أمنية).
- **429** `TOO_MANY_REQUESTS` — بعد **5 محاولات خلال دقيقة** لنفس البريد. انتظر عدد الثواني في ترويسة `Retry-After` واعرض عداداً للمستخدم.

```json
{
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "The email or password is incorrect.",
    "details": {}
  }
}
```

> في Postman: أضف سكربت حفظ التوكن (من [README.md](README.md)) لهذا الطلب.

## 3. بيانات المستخدم الحالي

```bash
curl --location '{{base_url}}/auth/me' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

- **200**
```json
{
  "data": {
    "id": 2,
    "name": "Test Customer",
    "email": "customer@store.test",
    "role": "customer",
    "created_at": "2026-11-04T10:00:00+00:00"
  }
}
```
- **401** بدون توكن (`UNAUTHENTICATED`) أو بتوكن منتهٍ/مزوّر/ملغى.

> لاحظ: بيانات المستخدم هنا داخل `data`، أما في رد التوكن فهي داخل `user`.

## 4. تجديد التوكن

```bash
curl --location --request POST '{{base_url}}/auth/refresh' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

- **200** رد توكن جديد. **التوكن القديم يتوقف عن العمل فوراً**، فاستبدله في التخزين.
- **401** التوكن غير صالح ← انتقل لشاشة الدخول.

> أضف سكربت حفظ التوكن لهذا الطلب أيضاً.

## 5. الخروج

```bash
curl --location --request POST '{{base_url}}/auth/logout' \
--header 'Accept: application/json' \
--header 'Authorization: Bearer {{token}}'
```

- **204** بدون محتوى. التوكن أُلغي على الخادم؛ احذفه من التخزين.
- استخدام نفس التوكن بعدها يرجع **401**.

---

## التدفق المقترح في Flutter

```
تشغيل التطبيق
  └─ يوجد توكن محفوظ؟
       ├─ لا  → شاشة الدخول
       └─ نعم → GET /auth/me
                 ├─ 200 → الشاشة الرئيسية (حسب user.role)
                 └─ 401 → POST /auth/refresh
                           ├─ 200 → احفظ التوكن الجديد وأعد الطلب
                           └─ 401 → احذف التوكن → شاشة الدخول
```

نصيحة: ضع هذا المنطق في **Interceptor** واحد (مثلاً في `dio`) يضيف الترويسة لكل طلب، ويجرّب `refresh` مرة واحدة عند أي `401` قبل تحويل المستخدم لشاشة الدخول.

## سيناريوهات اختبار سريعة في Postman

| السيناريو | المتوقع |
|---|---|
| `register` بنفس البريد مرتين | الثانية 422 |
| `register` مع `"role": "admin"` | 201 و `role: customer` |
| `login` بكلمة مرور خاطئة 6 مرات | السادسة 429 |
| `me` بدون ترويسة Authorization | 401 |
| `logout` ثم `me` بنفس التوكن | 401 |
| `refresh` ثم `me` بالتوكن القديم | 401 |
