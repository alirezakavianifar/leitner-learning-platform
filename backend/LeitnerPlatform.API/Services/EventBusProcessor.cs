using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.API.Services
{
    public class EventBusProcessor : BackgroundService
    {
        private readonly ChannelEventBus _eventBus;

        public EventBusProcessor(IEventBus eventBus)
        {
            _eventBus = (ChannelEventBus)eventBus;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            Console.WriteLine("Event Bus Processor started.");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var @event = await _eventBus.Reader.ReadAsync(stoppingToken);
                    await _eventBus.DispatchAsync(@event);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error processing event bus queue: {ex.Message}");
                }
            }

            Console.WriteLine("Event Bus Processor stopped.");
        }
    }
}
