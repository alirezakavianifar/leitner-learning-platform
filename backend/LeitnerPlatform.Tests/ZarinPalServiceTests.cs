using System;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Moq.Protected;
using Xunit;
using LeitnerPlatform.Data.Services;

namespace LeitnerPlatform.Tests
{
    public class ZarinPalServiceTests
    {
        [Fact]
        public async Task RequestPaymentAsync_ValidRequest_ReturnsSuccessAndAuthority()
        {
            // Arrange
            var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
            var responseContent = JsonSerializer.Serialize(new
            {
                data = new
                {
                    code = 100,
                    message = "Success",
                    authority = "A00000000000000000000000000000000000",
                    fee_type = "Merchant",
                    fee = 100
                },
                errors = new object[] { }
            });

            mockHttpMessageHandler.Protected()
                .Setup<Task<HttpResponseMessage>>(
                    "SendAsync",
                    ItExpr.IsAny<HttpRequestMessage>(),
                    ItExpr.IsAny<CancellationToken>()
                )
                .ReturnsAsync(new HttpResponseMessage
                {
                    StatusCode = HttpStatusCode.OK,
                    Content = new StringContent(responseContent)
                });

            var httpClient = new HttpClient(mockHttpMessageHandler.Object);
            var mockConfig = new Mock<IConfiguration>();
            mockConfig.Setup(c => c["ZarinPal:MerchantId"]).Returns("167ccd1b-f5d3-407d-85d1-a73c4f2ba3eb");
            mockConfig.Setup(c => c["ZarinPal:IsSandbox"]).Returns("false");

            var mockLogger = new Mock<ILogger<ZarinPalService>>();

            var zarinPalService = new ZarinPalService(httpClient, mockConfig.Object, mockLogger.Object);

            // Act
            var result = await zarinPalService.RequestPaymentAsync(
                amountInToman: 50000,
                description: "Test Course Purchase",
                callbackUrl: "https://example.com/callback",
                mobile: "09121234567"
            );

            // Assert
            Assert.True(result.IsSuccess);
            Assert.Equal(100, result.Code);
            Assert.Equal("A00000000000000000000000000000000000", result.Authority);
            Assert.Contains("https://www.zarinpal.com/pg/StartPay/A00000000000000000000000000000000000", result.PaymentUrl);
        }

        [Fact]
        public async Task VerifyPaymentAsync_ValidAuthority_ReturnsRefId()
        {
            // Arrange
            var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
            var responseContent = JsonSerializer.Serialize(new
            {
                data = new
                {
                    code = 100,
                    message = "Verified",
                    card_pan = "502229******1234",
                    ref_id = 987654321
                },
                errors = new object[] { }
            });

            mockHttpMessageHandler.Protected()
                .Setup<Task<HttpResponseMessage>>(
                    "SendAsync",
                    ItExpr.IsAny<HttpRequestMessage>(),
                    ItExpr.IsAny<CancellationToken>()
                )
                .ReturnsAsync(new HttpResponseMessage
                {
                    StatusCode = HttpStatusCode.OK,
                    Content = new StringContent(responseContent)
                });

            var httpClient = new HttpClient(mockHttpMessageHandler.Object);
            var mockConfig = new Mock<IConfiguration>();
            mockConfig.Setup(c => c["ZarinPal:MerchantId"]).Returns("167ccd1b-f5d3-407d-85d1-a73c4f2ba3eb");

            var mockLogger = new Mock<ILogger<ZarinPalService>>();

            var zarinPalService = new ZarinPalService(httpClient, mockConfig.Object, mockLogger.Object);

            // Act
            var result = await zarinPalService.VerifyPaymentAsync(50000, "A00000000000000000000000000000000000");

            // Assert
            Assert.True(result.IsSuccess);
            Assert.Equal(100, result.Code);
            Assert.Equal(987654321, result.RefId);
            Assert.Equal("502229******1234", result.CardPan);
        }
    }
}

