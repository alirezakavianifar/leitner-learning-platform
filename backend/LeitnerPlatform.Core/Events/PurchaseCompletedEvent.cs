using System;
using LeitnerPlatform.Core.Entities;

namespace LeitnerPlatform.Core.Events
{
    public class PurchaseCompletedEvent
    {
        public Purchase Purchase { get; }
        public PurchaseCompletedEvent(Purchase purchase)
        {
            Purchase = purchase;
        }
    }
}
