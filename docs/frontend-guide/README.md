# دليل الواجهة الأمامية (Frontend Guide)

دليل لفريق Flutter لربط التطبيق مع الـ Backend (Laravel `core-api`).
كل خطوة من الـ Backend لها ملف هنا، وفيه أوامر `curl` جاهزة للاستيراد في Postman.

> **ابدأ من هنا:** [00-run-with-docker.md](00-run-with-docker.md) — تشغيل الـ Backend كاملاً بأمر واحد (يكفي Docker).

| الملف | المحتوى |
|---|---|
| [00-run-with-docker.md](00-run-with-docker.md) | تشغيل المشروع على Docker (Mac/Windows) |
| [01-api-basics.md](01-api-basics.md) | العنوان الأساسي، الترويسات، صيغة الأخطاء، رموز الحالة |
| [02-auth.md](02-auth.md) | التسجيل، الدخول، التوكن، الخروج، الأدوار |
| [03-products.md](03-products.md) | التصنيفات، المنتجات، الصور، التصفية، تقسيم الصفحات، المخزون |
| [04-orders.md](04-orders.md) | إنشاء الطلب، عرض الطلبات، تغيير الحالة، حالات الرفض |
| [05-notifications.md](05-notifications.md) | الإشعارات، عدد غير المقروء، تعليمها كمقروءة |

---

## تجهيز Postman (مرة واحدة)

### 1. أنشئ Environment
من **Environments → Create Environment** باسم `ecommerce-local`، وأضف المتغيرات:

| Variable | Initial value |
|---|---|
| `base_url` | `http://localhost:8000/api/v1` |
| `token` | (اتركه فارغاً، يُملأ تلقائياً بعد الدخول) |

ثم اختر هذا الـ Environment من القائمة أعلى يمين Postman.

### 2. استيراد أي أمر curl
1. انسخ أمر `curl` من أي ملف في هذا المجلد.
2. في Postman: **Import** ← الصق النص في خانة **Raw text** ← **Continue** ← **Import**.
3. يُنشأ الطلب جاهزاً، و `{{base_url}}` و `{{token}}` تُقرأ من الـ Environment.

### 3. حفظ التوكن تلقائياً
في طلب **Login** (وطلب **Register**) افتح تبويب **Scripts → Post-response** والصق:

```js
const body = pm.response.json();
if (body.access_token) {
    pm.environment.set("token", body.access_token);
}
```

بعدها كل الطلبات التي فيها `Authorization: Bearer {{token}}` تعمل مباشرة.

---

## تشغيل الـ Backend محلياً

### الطريقة الأساسية: Docker (لا تحتاج PHP)

```bash
docker compose up -d --build
```

التفاصيل الكاملة وحل المشاكل: [00-run-with-docker.md](00-run-with-docker.md).

### بديل: بدون Docker (لمن لديه PHP 8.4 و Composer)

```bash
cd services/core-api
composer install
cp .env.example .env
php artisan key:generate
php artisan jwt:secret
php artisan migrate --seed
php artisan serve
```

الحسابات الجاهزة بعد `--seed`:

| الدور | البريد | كلمة المرور |
|---|---|---|
| مسؤول (admin) | `admin@store.test` | `Admin@12345` |
| زبون (customer) | `customer@store.test` | `password` |

> ملاحظة لـ Flutter: من محاكي Android استخدم `http://10.0.2.2:8000/api/v1` بدل `localhost`.
