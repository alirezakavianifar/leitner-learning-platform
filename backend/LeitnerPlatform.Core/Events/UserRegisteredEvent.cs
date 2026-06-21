using System;
using LeitnerPlatform.Core.Entities;

namespace LeitnerPlatform.Core.Events
{
    public class UserRegisteredEvent
    {
        public User User { get; }
        public UserRegisteredEvent(User user)
        {
            User = user;
        }
    }
}
