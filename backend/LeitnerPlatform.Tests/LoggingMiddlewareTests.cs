using Xunit;
using Moq;
using Microsoft.AspNetCore.Http;
using System;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using LeitnerPlatform.API.Middleware;
using Microsoft.Extensions.Logging;

namespace LeitnerPlatform.Tests
{
    public class LoggingMiddlewareTests
    {
        [Fact]
        public async Task CorrelationIdMiddleware_GeneratesNewId_WhenHeaderIsMissing()
        {
            // Arrange
            var context = new DefaultHttpContext();
            RequestDelegate next = (ctx) => Task.CompletedTask;
            var middleware = new CorrelationIdMiddleware(next);

            // Act
            await middleware.InvokeAsync(context);

            // Assert
            Assert.True(context.Items.ContainsKey(CorrelationIdMiddleware.CorrelationIdHeaderKey));
            var generatedId = context.Items[CorrelationIdMiddleware.CorrelationIdHeaderKey]?.ToString();
            Assert.False(string.IsNullOrEmpty(generatedId));
            
            // Check if Guid is valid
            Assert.True(Guid.TryParse(generatedId, out _));
        }

        [Fact]
        public async Task CorrelationIdMiddleware_PreservesId_WhenHeaderExists()
        {
            // Arrange
            var context = new DefaultHttpContext();
            var testId = Guid.NewGuid().ToString();
            context.Request.Headers[CorrelationIdMiddleware.CorrelationIdHeaderKey] = testId;

            RequestDelegate next = (ctx) => Task.CompletedTask;
            var middleware = new CorrelationIdMiddleware(next);

            // Act
            await middleware.InvokeAsync(context);

            // Assert
            Assert.True(context.Items.ContainsKey(CorrelationIdMiddleware.CorrelationIdHeaderKey));
            Assert.Equal(testId, context.Items[CorrelationIdMiddleware.CorrelationIdHeaderKey]?.ToString());
        }

        [Fact]
        public async Task ExceptionHandlingMiddleware_Returns500AndJson_OnException()
        {
            // Arrange
            var context = new DefaultHttpContext();
            context.Items[CorrelationIdMiddleware.CorrelationIdHeaderKey] = "test-correlation-id";

            // Set up a response body stream so we can read the response
            var responseStream = new MemoryStream();
            context.Response.Body = responseStream;

            // Set up a mock logger
            var mockLogger = new Mock<ILogger<ExceptionHandlingMiddleware>>();

            // Setup a next delegate that throws an exception
            RequestDelegate next = (ctx) => throw new InvalidOperationException("Test Exception");

            var middleware = new ExceptionHandlingMiddleware(next, mockLogger.Object);

            // Act
            await middleware.InvokeAsync(context);

            // Assert
            Assert.Equal(500, context.Response.StatusCode);
            Assert.Equal("application/json", context.Response.ContentType);

            // Verify logger was called with Error level
            mockLogger.Verify(
                x => x.Log(
                    LogLevel.Error,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => true),
                    It.IsAny<Exception>(),
                    It.Is<Func<It.IsAnyType, Exception?, string>>((v, t) => true)),
                Times.Once);

            // Read and deserialize the JSON response
            responseStream.Position = 0;
            using var reader = new StreamReader(responseStream);
            var responseBody = await reader.ReadToEndAsync();
            
            var jsonDoc = JsonDocument.Parse(responseBody);
            var root = jsonDoc.RootElement;

            Assert.True(root.TryGetProperty("error", out var errorProp));
            Assert.Equal("An unexpected error occurred. Please contact support.", errorProp.GetString());

            Assert.True(root.TryGetProperty("correlation_id", out var corrProp));
            Assert.Equal("test-correlation-id", corrProp.GetString());
        }
    }
}
