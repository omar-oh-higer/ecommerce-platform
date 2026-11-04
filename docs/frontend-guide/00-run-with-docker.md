# 00 — تشغيل الـ Backend كاملاً على Docker (Mac)

هذا الدليل يشغّل الـ Backend كاملاً على جهازك **بدون تثبيت PHP أو Composer أو MySQL**.
تحتاج فقط **Docker Desktop** و **Git**.

ما الذي سيعمل عندك:

| الحاوية | الوظيفة | العنوان |
|---|---|---|
| `nginx` | يستقبل الطلبات | `http://localhost:8000` |
| `core-api` | تطبيق Laravel (PHP 8.4) | داخلي |
| `queue-worker` | المهام في الخلفية (مثل إعادة محاولة إرجاع الكمية للمخزون) | داخلي |
| `mysql` | قاعدة البيانات | `localhost:3307` (اختياري لأدوات مثل TablePlus) |

---

## 1. التجهيز (مرة واحدة)

### Docker Desktop
1. نزّله من https://www.docker.com/products/docker-desktop/
   - اختر **Apple Silicon** إذا كان جهازك M1/M2/M3/M4، أو **Intel** للأجهزة الأقدم
     (من القائمة  ← About This Mac ← Chip).
2. ثبّته وافتحه، وانتظر حتى يظهر **Engine running** في أسفل نافذته.
3. تأكد من الـ Terminal:
   ```bash
   docker --version
   docker compose version
   ```

### Git
```bash
git --version
```
إذا لم يكن مثبتاً، سيعرض الماك تثبيت **Command Line Developer Tools** — وافق وانتظر.

---

## 2. تنزيل المشروع

```bash
cd ~/Desktop
git clone https://github.com/omar-oh-higer/ecommerce-platform.git
cd ecommerce-platform
```

---

## 3. التشغيل (أمر واحد)

```bash
docker compose up -d --build
```

> ⏳ **أول مرة فقط تأخذ 10–20 دقيقة**: Docker يبني صورة PHP ويثبّت مكتبات Laravel.
> المرات التالية تعمل خلال ثوانٍ.

تابع التجهيز حتى تظهر رسالة `Ready`:

```bash
docker compose logs -f core-api
```

ستظهر رسائل مثل:
```
[core-api] Installing Composer dependencies (first run takes a few minutes)...
[core-api] Waiting for the database at mysql:3306...
[core-api] Ready: http://localhost:8000/api/v1
```
اضغط `Ctrl + C` للخروج من السجلات (الحاويات تبقى تعمل).

تأكد أن الحاويات الثلاث تعمل:
```bash
docker compose ps
```
يجب أن ترى `nginx` و `core-api` و `queue-worker` و `mysql` بحالة `Up` (و `healthy`).

---

## 4. التأكد أن كل شيء يعمل

```bash
curl http://localhost:8000/api/v1
```
الرد المتوقع:
```json
{"name":"Laravel","version":"v1","status":"ok"}
```

جرّب الدخول:
```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"email":"customer@store.test","password":"password"}'
```
إذا رجع `access_token` فالـ Backend وقاعدة البيانات والمصادقة كلها تعمل ✅

### الحسابات الجاهزة

| الدور | البريد | كلمة المرور |
|---|---|---|
| مسؤول (admin) | `admin@store.test` | `Admin@12345` |
| زبون (customer) | `customer@store.test` | `password` |

---

## 5. Postman و Flutter

- اتبع [README.md](README.md) لتجهيز Postman، ثم ملفات الشرح لكل جزء:
  [01-api-basics.md](01-api-basics.md) ، [02-auth.md](02-auth.md).
- العنوان الأساسي في Flutter:

| أين يعمل التطبيق | `baseUrl` |
|---|---|
| iOS Simulator | `http://localhost:8000/api/v1` |
| Android Emulator | `http://10.0.2.2:8000/api/v1` |
| جهاز حقيقي على نفس الشبكة | `http://<IP-الماك>:8000/api/v1` |

لمعرفة IP الماك: `ipconfig getifaddr en0`

> iOS يمنع `http` افتراضياً. للتطوير أضف في `ios/Runner/Info.plist`:
> ```xml
> <key>NSAppTransportSecurity</key>
> <dict>
>     <key>NSAllowsLocalNetworking</key>
>     <true/>
> </dict>
> ```

---

## 6. أوامر الاستخدام اليومي

نفّذها من داخل مجلد `ecommerce-platform`.

| أريد أن... | الأمر |
|---|---|
| أشغّل المشروع | `docker compose up -d` |
| أوقف المشروع (البيانات تبقى) | `docker compose down` |
| أرى السجلات والأخطاء | `docker compose logs -f core-api` |
| **أحدّث بعد تعديلات زميلي** | `git pull` ثم `docker compose up -d --build --force-recreate core-api queue-worker` |
| أرجع القاعدة للحالة الأولى (تُحذف كل البيانات) | `docker compose down -v` ثم `docker compose up -d` |
| أشغّل اختبارات الـ Backend | `docker compose exec core-api php artisan test` |
| أنفّذ أمر Laravel | `docker compose exec core-api php artisan <command>` |

### بعد كل `git pull`
```bash
git pull
docker compose up -d --build --force-recreate core-api queue-worker
```
حاوية `core-api` تطبّق الجداول الجديدة (migrations) والمكتبات الجديدة **عند بدء تشغيلها فقط**.
`--force-recreate` يضمن إعادة تشغيلها حتى لو لم تتغير الصورة، وإعادة تشغيل `queue-worker` حتى يقرأ الكود الجديد.
بدونه قد ترى خطأ مثل `Table '...' doesn't exist`. قاعدة البيانات لا تتأثر (بياناتك تبقى).

---

## 7. حل المشاكل الشائعة

**`Cannot connect to the Docker daemon`**
Docker Desktop غير مفتوح. افتحه وانتظر `Engine running`.

**`port is already allocated` أو `address already in use` على 8000**
برنامج آخر يستخدم المنفذ. شغّل على منفذ آخر:
```bash
APP_PORT=8080 docker compose up -d
```
وغيّر `base_url` في Postman إلى `http://localhost:8080/api/v1`.

**نفس الخطأ على 3307 (MySQL)**
```bash
DB_FORWARD_PORT=3308 docker compose up -d
```

**`curl` يرجع `502 Bad Gateway` أو لا يرد**
التجهيز لم ينتهِ بعد (خاصة أول مرة). انتظر رسالة `Ready` في:
```bash
docker compose logs -f core-api
```

**`core-api` يتوقف ويعيد التشغيل باستمرار**
اعرض آخر الأخطاء وأرسلها لفريق الـ Backend:
```bash
docker compose logs --tail=50 core-api
```

**أريد البدء من الصفر تماماً**
```bash
docker compose down -v
rm -rf services/core-api/vendor services/core-api/.env
docker compose up -d --build
```

**البناء بطيء جداً على Mac**
في Docker Desktop ← Settings ← Resources: اجعل الذاكرة 4GB على الأقل.
