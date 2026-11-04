using Grpc.Core;
using Grpc.Core.Interceptors;
using Npgsql;

namespace InventoryService.Services;

/// <summary>
/// Turns infrastructure failures into clear gRPC status codes instead of a generic UNKNOWN:
///  - database unreachable  → UNAVAILABLE (the caller may retry later)
///  - client deadline/cancel → CANCELLED / DEADLINE_EXCEEDED
/// Internal details are logged, never sent to the client.
/// </summary>
public sealed class ErrorInterceptor(ILogger<ErrorInterceptor> logger) : Interceptor
{
    public override async Task<TResponse> UnaryServerHandler<TRequest, TResponse>(
        TRequest request,
        ServerCallContext context,
        UnaryServerMethod<TRequest, TResponse> continuation)
    {
        try
        {
            return await continuation(request, context);
        }
        catch (RpcException)
        {
            throw;
        }
        catch (OperationCanceledException) when (context.CancellationToken.IsCancellationRequested)
        {
            var code = context.Deadline <= DateTime.UtcNow ? StatusCode.DeadlineExceeded : StatusCode.Cancelled;
            logger.LogWarning("{Method} stopped: {Code}", context.Method, code);
            throw new RpcException(new Status(code, "The call was cancelled or its deadline expired."));
        }
        catch (Exception e) when (e is NpgsqlException || e.InnerException is NpgsqlException)
        {
            logger.LogError(e, "{Method} failed: database unavailable", context.Method);
            throw new RpcException(new Status(StatusCode.Unavailable, "The inventory database is not available."));
        }
        catch (Exception e)
        {
            logger.LogError(e, "{Method} failed", context.Method);
            throw new RpcException(new Status(StatusCode.Internal, "Unexpected inventory error."));
        }
    }
}
