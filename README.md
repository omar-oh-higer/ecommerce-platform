# Distributed Real-Time E-Commerce Platform

مشروع مادة تطبيقات الإنترنت، جامعة دمشق 2026.

| الخدمة | التقنية | المسار |
|---|---|---|
| التطبيق الأساسي | Laravel | `services/core-api` |
| خدمة المستودع | .NET (gRPC) | `services/inventory-service` |
| الواجهة | Flutter | `mobile` |

## Quick start (Docker)

```bash
git clone https://github.com/omar-oh-higer/ecommerce-platform.git
cd ecommerce-platform
docker compose up -d --build
curl http://localhost:8000/api/v1
```

The first run takes 10–20 minutes (building the PHP image and installing dependencies).

- Full guide: [docs/frontend-guide/00-run-with-docker.md](docs/frontend-guide/00-run-with-docker.md)
- API guide with Postman-ready curl: [docs/frontend-guide](docs/frontend-guide/README.md)
- Architecture: [docs/architecture.md](docs/architecture.md)
