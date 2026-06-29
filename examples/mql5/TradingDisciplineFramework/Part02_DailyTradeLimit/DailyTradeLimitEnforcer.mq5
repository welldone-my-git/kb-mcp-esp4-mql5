//+------------------------------------------------------------------+
//|                                       DailyTradeLimitEnforcer.mq5|
//|                                   Copyright 2026, MetaQuotes Ltd.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict
#property description "Prevents new trades when daily limit is reached–does not close existing positions."

#include <DailyTradeLimit.mqh>

bool s_limitJustReached = false;   // flag to trigger pending order cleanup

//+------------------------------------------------------------------+
//| Cancel all pending orders (market orders are ignored)           |
//+------------------------------------------------------------------+
void CancelAllPendingOrders()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(!OrderSelect(ticket))
        {
         Print("Failed to select order ", ticket);
         continue;
        }

      // Only delete pending orders (ignore market orders)
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL)
         continue;   // market order – will be handled if filled

      // Delete the pending order
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action   = TRADE_ACTION_REMOVE;
      req.order    = ticket;
      req.comment  = "Daily limit reached – pending order cancelled";

      if(OrderSend(req, res))
         Print("Cancelled pending order ", ticket);
      else
         Print("Failed to cancel order ", ticket, ": ", res.comment);
     }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("DailyTradeLimitEnforcer started. AutoTrading must be enabled.");
   EventSetTimer(1);   // check state change every second
   DTL::ForceRefresh(); // initial read
   s_limitJustReached = (DTL::GetState() == DTL::STATE_LIMIT);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   Print("DailyTradeLimitEnforcer stopped.");
  }

//+------------------------------------------------------------------+
//| Timer – detect state change to LIMIT and clean pending orders   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   DTL::ForceRefresh();   // always get the latest count
   bool nowLimited = (DTL::GetState() == DTL::STATE_LIMIT);

// If we just entered the LIMIT state, cancel all pending orders
   if(nowLimited && !s_limitJustReached)
     {
      Print("Daily limit reached – cancelling all pending orders.");
      CancelAllPendingOrders();
     }

   s_limitJustReached = nowLimited;
  }

//+------------------------------------------------------------------+
//| Handle trade transactions – immediate reaction to new attempts  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
// Force a full refresh to catch the new trade immediately
   DTL::ForceRefresh();

// If trading is still allowed, do nothing
   if(DTL::IsTradingAllowed())
      return;

// --- Case 1: New pending order added ---
   if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
     {
      ulong orderTicket = trans.order;
      if(orderTicket == 0)
         return;

      if(!OrderSelect(orderTicket))
        {
         Print("Failed to select order ", orderTicket);
         return;
        }

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL)
         return;   // market order – will be handled by DEAL_ADD if filled

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action   = TRADE_ACTION_REMOVE;
      req.order    = orderTicket;
      req.comment  = "Daily limit reached – order cancelled immediately";

      if(OrderSend(req, res))
         Print("Immediately cancelled pending order ", orderTicket);
      else
         Print("Immediate cancel failed for order ", orderTicket, ": ", res.comment);
     }

// --- Case 2: New deal added (opening trade) ---
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong dealTicket = trans.deal;
      if(dealTicket == 0)
         return;

      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_IN)
         return;

      ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      if(posTicket == 0)
         return;

      if(!PositionSelectByTicket(posTicket))
        {
         Print("Position ", posTicket, " no longer open.");
         return;
        }

      // Close the newly opened position
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action    = TRADE_ACTION_DEAL;
      req.position  = posTicket;
      req.symbol    = PositionGetString(POSITION_SYMBOL);
      req.volume    = PositionGetDouble(POSITION_VOLUME);
      req.deviation = 5;
      req.comment   = "Daily limit reached – new position closed immediately";

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         req.price = SymbolInfoDouble(req.symbol, SYMBOL_BID);
         req.type  = ORDER_TYPE_SELL;
        }
      else
        {
         req.price = SymbolInfoDouble(req.symbol, SYMBOL_ASK);
         req.type  = ORDER_TYPE_BUY;
        }

      if(OrderSend(req, res))
         Print("Immediately closed new position ", posTicket);
      else
         Print("Immediate close failed for position ", posTicket, ": ", res.comment);
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
