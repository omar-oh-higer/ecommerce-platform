# 06 — توثيق الـ API التفاعلي (Swagger و Postman)

بعد تشغيل المشروع (`docker compose up -d`) يتوفر التوثيق الكامل لكل الـ API بثلاث صيغ:

| الرابط | ما هو | متى تستخدمه |
|---|---|---|
| http://localhost:8000/docs/ | صفحة توثيق كاملة مع زر **Try it out** لكل طلب | لتقرأ وتجرّب أي طلب من المتصفح |
| http://localhost:8000/swagger/ | **Swagger UI** (نفس المحتوى بالشكل القياسي) | إذا تفضّل واجهة Swagger |
| http://localhost:8000/docs/collection.json | **Postman Collection** جاهزة (19 طلباً في 5 مجموعات) | للاستيراد في Postman بضغطة واحدة |
| http://localhost:8000/docs/openapi.yaml | ملف **OpenAPI 3** | لأدوات توليد الكود أو أي أداة تقرأ OpenAPI |

المجموعات: **Authentication**، **Catalogue**، **Orders**، **Notifications**، **Administration**.
لكل طلب: الوصف، من يستطيع استدعاءه، الحقول وشروطها، وأمثلة حقيقية للردود الناجحة **وللأخطاء** (403، 409، 422، 503...).

---

## 1. التجربة من المتصفح (`/docs`)

1. افتح http://localhost:8000/docs/
2. من **Authentication → Login** اضغط **Try it out**، اترك القيم الجاهزة (`customer@store.test` / `password`) واضغط **Send Request**.
3. انسخ قيمة `access_token` من الرد.
4. في أي طلب محمي (عليه علامة `requires authentication`) اضغط **Try it out** والصق التوكن في خانة `Authorization` بعد `Bearer `.

للتجربة كمسؤول: سجّل الدخول بـ `admin@store.test` / `Admin@12345`.

## 2. Swagger UI (`/swagger`)

1. افتح http://localhost:8000/swagger/
2. اضغط زر **Authorize** (أعلى اليمين) والصق التوكن (بدون كلمة `Bearer`) ← **Authorize**.
3. افتح أي طلب ← **Try it out** ← **Execute**.

التوكن يبقى محفوظاً بعد تحديث الصفحة.

## 3. استيراد الـ Postman Collection

**الطريقة الأسرع:**
1. في Postman: **Import** ← **Link** ← الصق `http://localhost:8000/docs/collection.json` ← **Import**.
2. تظهر Collection باسم **E-Commerce Platform API — v1** فيها كل الطلبات مرتبة في مجلدات.

**ضبط التوكن مرة واحدة للمجموعة كلها:**
1. اضغط على اسم الـ Collection ← تبويب **Authorization** ← النوع `Bearer Token`.
2. في خانة Token اكتب `{{token}}`.
3. في طلب **Login** ← تبويب **Scripts → Post-response** الصق:
   ```js
   const body = pm.response.json();
   if (body.access_token) {
       pm.collectionVariables.set("token", body.access_token);
   }
   ```
4. نفّذ **Login** مرة، وكل الطلبات الأخرى تعمل بعدها مباشرة.

> العنوان محفوظ في متغير الـ Collection `baseUrl` (`http://localhost:8000`). إذا شغّلت المشروع على منفذ آخر غيّره من تبويب **Variables**.

> طلب **Create a product** يرسل صورة: بعد الاستيراد افتح **Body → form-data** واختر ملف الصورة في صف `image`.

---

## الفرق عن ملفات الشرح `01`–`05`

| | ملفات `docs/frontend-guide/*.md` | `/docs` و `/swagger` و Postman Collection |
|---|---|---|
| اللغة | عربي | إنجليزي |
| المحتوى | شرح، نصائح لـ Flutter، سيناريوهات اختبار | مرجع تقني كامل لكل طلب |
| التجربة | نسخ أوامر curl | زر Try it out / استيراد مباشر |

استخدم ملفات الشرح لتفهم **لماذا وكيف**، والتوثيق التفاعلي كمرجع سريع **أثناء** البرمجة.

---

## لفريق الـ Backend: تحديث التوثيق
التوثيق يُولَّد من التعليقات (`@group`, `@bodyParam`, `@response`...) فوق كل دالة في
`services/core-api/app/Http/Controllers/Api/V1/`. بعد إضافة أو تعديل أي endpoint:

```bash
docker compose exec core-api php artisan scribe:generate
```
ثم أضف الملفات المحدَّثة في `services/core-api/public/docs/` إلى نفس الـ PR.
