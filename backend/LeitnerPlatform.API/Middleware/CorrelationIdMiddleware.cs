using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Primitives;
using Serilog.Context;
using System;
using System.Threading.Tasks;

namespace LeitnerPlatform.API.Middleware
{
    public class CorrelationIdMiddleware
    {
        private readonly RequestDelegate _next;
        public const string CorrelationIdHeaderKey = "X-Correlation-ID";

        public CorrelationIdMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            if (!context.Request.Headers.TryGetValue(CorrelationIdHeaderKey, out StringValues correlationId) || string.IsNullOrEmpty(correlationId))
            {
                correlationId = Guid.NewGuid().ToString();
            }

            // Put it in HttpContext.Items for access elsewhere in the API if needed
            context.Items[CorrelationIdHeaderKey] = correlationId.ToString();

            // Set the correlation ID in the response headers before starting to send the body
            context.Response.OnStarting(() =>
            {
                if (!context.Response.Headers.ContainsKey(CorrelationIdHeaderKey))
                {
                    context.Response.Headers.Append(CorrelationIdHeaderKey, correlationId);
                }
                return Task.CompletedTask;
            });

            // Push to Serilog LogContext so all logs within this request request scope have the CorrelationId property
            using (LogContext.PushProperty("CorrelationId", correlationId.ToString()))
            {
                await _next(context);
            }
        }
    }
}
