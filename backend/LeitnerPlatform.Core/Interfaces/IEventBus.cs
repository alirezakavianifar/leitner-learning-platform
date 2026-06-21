using System;
using System.Threading.Tasks;

namespace LeitnerPlatform.Core.Interfaces
{
    public interface IEventBus
    {
        Task PublishAsync<T>(T @event) where T : class;
        void Subscribe<T>(Func<T, Task> handler) where T : class;
    }
}
