using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading.Channels;
using System.Threading.Tasks;
using LeitnerPlatform.Core.Interfaces;

namespace LeitnerPlatform.API.Services
{
    public class ChannelEventBus : IEventBus
    {
        private readonly Channel<object> _channel;
        private readonly ConcurrentDictionary<Type, List<Func<object, Task>>> _handlers;

        public ChannelEventBus()
        {
            _channel = Channel.CreateUnbounded<object>(new UnboundedChannelOptions
            {
                SingleReader = true
            });
            _handlers = new ConcurrentDictionary<Type, List<Func<object, Task>>>();
        }

        public async Task PublishAsync<T>(T @event) where T : class
        {
            await _channel.Writer.WriteAsync(@event);
        }

        public void Subscribe<T>(Func<T, Task> handler) where T : class
        {
            _handlers.AddOrUpdate(typeof(T),
                _ => new List<Func<object, Task>> { e => handler((T)e) },
                (_, list) => {
                    list.Add(e => handler((T)e));
                    return list;
                });
        }

        public ChannelReader<object> Reader => _channel.Reader;

        public async Task DispatchAsync(object @event)
        {
            var eventType = @event.GetType();
            if (_handlers.TryGetValue(eventType, out var handlersList))
            {
                foreach (var handler in handlersList)
                {
                    try
                    {
                        await handler(@event);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Error executing handler for event {eventType.Name}: {ex.Message}");
                    }
                }
            }
        }
    }
}
