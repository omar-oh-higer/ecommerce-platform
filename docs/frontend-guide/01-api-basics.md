# 01 — أساسيات الـ API

## العنوان الأساسي
كل الطلبات تبدأ بـ:

```
{{base_url}} = http://localhost:8000/api/v1
```

الرقم `v1` هو إصدار الـ API. أي تغيير يكسر التوافق مستقبلاً يكون في `v2` دون أن يتأثر التطبيق الحالي.

## الترويسات المطلوبة في كل طلب

| Header | القيمة | لماذا |
|---|---|---|
| `Accept` | `application/json` | حتى ترجع كل الردود والأخطاء بصيغة JSON |
| `Content-Type` | `application/json` | عند إرسال body بصيغة JSON |
| `Authorization` | `Bearer <token>` | للمسارات المحمية فقط (انظر [02-auth.md](02-auth.md)) |

## فحص أن الخادم يعمل

```bash
curl --location '{{base_url}}' \
--header 'Accept: application/json'
```

الرد `200`:
```json
{
  "name": "Laravel",
  "version": "v1",
  "status": "ok"
}
```

---

## صيغة الأخطاء الموحدة
**كل** خطأ من الـ API يرجع بنفس الشكل، فيكفي كود واحد في Flutter لقراءة كل الأخطاء:

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "The given data was invalid.",
    "details": {}
  }
}
```

| الحقل | الوصف |
|---|---|
| `code` | رمز ثابت تعتمد عليه في الكود (لا تعتمد على `message`) |
| `message` | رسالة مقروءة للمطوّر |
| `details` | معلومات إضافية؛ في أخطاء التحقق تحتوي أخطاء كل حقل |

### مثال: خطأ تحقق (422)
```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "The given data was invalid.",
    "details": {
      "email": ["The email has already been taken."],
      "password": ["The password field must be at least 8 characters."]
    }
  }
}
```
في Flutter: اعرض `details[field][0]` تحت كل حقل في النموذج.

### جرّب خطأ 404

```bash
curl --location '{{base_url}}/does-not-exist' \
--header 'Accept: application/json'
```

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "The route api/v1/does-not-exist could not be found.",
    "details": {}
  }
}
```

---

## رموز الحالة

| Status | `error.code` | المعنى | ماذا يفعل التطبيق |
|---|---|---|---|
| 200 | — | نجاح | — |
| 201 | — | تم الإنشاء | — |
| 204 | — | نجاح بدون محتوى | — |
| 401 | `UNAUTHENTICATED` / `INVALID_TOKEN` | غير مسجل أو التوكن منتهٍ | جرّب `refresh` مرة، ثم انتقل لشاشة الدخول |
| 401 | `INVALID_CREDENTIALS` | بريد أو كلمة مرور خاطئة | رسالة تحت نموذج الدخول |
| 403 | `FORBIDDEN` | لا تملك صلاحية | رسالة "غير مسموح" |
| 404 | `NOT_FOUND` | غير موجود | شاشة "غير موجود" |
| 405 | `METHOD_NOT_ALLOWED` | نوع الطلب خاطئ | خطأ برمجي في التطبيق |
| 409 | حسب العملية (مثل `INSUFFICIENT_STOCK`) | تعارض في العمل | اعرض `message` و `details` |
| 422 | `VALIDATION_FAILED` | بيانات غير صحيحة | أخطاء الحقول من `details` |
| 429 | `TOO_MANY_REQUESTS` | طلبات كثيرة | انتظر عدد الثواني في ترويسة `Retry-After` |
| 500 | `SERVER_ERROR` | خطأ في الخادم | رسالة عامة "حدث خطأ" |
| 503 | `SERVICE_UNAVAILABLE` | خدمة غير متاحة مؤقتاً | "حاول لاحقاً" |

## حدود عدد الطلبات
- كل الـ API: 120 طلباً في الدقيقة لكل مستخدم (أو لكل IP قبل الدخول).
- كل رد يحمل الترويسات `X-RateLimit-Limit` و `X-RateLimit-Remaining`.
