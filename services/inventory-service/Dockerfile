# Inventory service (.NET 10, gRPC).
# Build context is the repository root (see docker-compose.yml) because the service
# compiles the shared contract in /proto/inventory.proto.
# Multi-arch: works on Apple Silicon (arm64) and amd64.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /repo

# Restore first (cached while only code changes).
COPY services/inventory-service/src/InventoryService/InventoryService.csproj services/inventory-service/src/InventoryService/
RUN dotnet restore services/inventory-service/src/InventoryService/InventoryService.csproj

COPY proto/ proto/
COPY services/inventory-service/src/ services/inventory-service/src/
RUN dotnet publish services/inventory-service/src/InventoryService/InventoryService.csproj \
    -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime

# curl is only used by the Docker health check.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app .

# 5001: gRPC (HTTP/2) — 8080: health check (HTTP/1.1)
EXPOSE 5001 8080

# Run as the non-root user that ships with the image.
USER $APP_UID

ENTRYPOINT ["dotnet", "InventoryService.dll"]
