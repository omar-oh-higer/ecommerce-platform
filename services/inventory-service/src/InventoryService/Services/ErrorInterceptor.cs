using Grpc.Core;
using Grpc.Core.Interceptors;
using Npgsql;

namespace InventoryService.Services;

/// <summary>
/// Turns infrastructure failures into clear gRPC status codes instead of a generic UNKNOWN:
///  - database unreachable  → UNAVAILABLE (the caller may retry later)
///  - client deadline passed → DEADLINE_EXCEEDED, client hung up → CANCELLED
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
        catch (Exception e) when (e is OperationCanceledException || context.CancellationToken.IsCancellationRequested)
        {
            // Whatever failed once the call was cancelled is a consequence of the cancellation.
            // The call's token fires for two reasons: the client hung up (the HTTP request was
            // aborted) or the client's deadline passed. No request abort means it was the deadline.
            var code = ClientHungUp(context) ? StatusCode.Cancelled : StatusCode.DeadlineExceeded;

            logger.LogWarning("{Method} stopped: {Code} ({Exception})", context.Method, code, e.GetType().Name);
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

    private static bool ClientHungUp(ServerCallContext context)
    {
        try
        {
            return context.GetHttpContext().RequestAborted.IsCancellationRequested;
        }
        catch (ObjectDisposedException)
        {
            return true; // the request is already gone
        }
    }
}
