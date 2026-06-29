//+------------------------------------------------------------------+
//|                                     TradingHoursNewsEnforcer.mq5 |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict
#property description "Blocks trades outside allowed sessions or near news events."

#include <TradingDiscipline/TradingHoursNews.mqh>

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("TradingHoursNewsEnforcer started. AutoTrading must be enabled.");
   THN::Refresh();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   Print("TradingHoursNewsEnforcer stopped.");
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   THN::Refresh();
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| OnTradeTransaction                                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   THN::Refresh();
   if(THN::IsAllowedNow())
      return;

   string symbol = "";
   ulong  ticket = 0;
   bool   isManual = false;

   if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
     {
      ticket = trans.order;
      if(ticket == 0)
         return;
      if(!OrderSelect(ticket))
        {
         Print("Failed to select order ",ticket);
         return;
        }
      symbol   = OrderGetString(ORDER_SYMBOL);
      isManual = (OrderGetInteger(ORDER_MAGIC) == 0);
     }
   else
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
        {
         ticket = trans.deal;
         if(ticket == 0)
            return;
         if(HistoryDealSelect(ticket))
           {
            symbol   = HistoryDealGetString(ticket,DEAL_SYMBOL);
            long magic = HistoryDealGetInteger(ticket,DEAL_MAGIC);
            isManual = (magic == 0);
           }
        }
      else
         return;

   if(symbol == "")
      return;

   string reason = "";
   if(!THN::IsWithinAllowedSessions(TimeCurrent()))
      reason = "outside session";
   else
      if(THN::IsNewsBlackout(TimeCurrent()))
         reason = "news blackout";
      else
         return;

   string source = isManual ? "manual" : "EA";
   THN::LogBlockedAttempt(TimeCurrent(),symbol,reason,source);

   Print("Blocking ",source," trade on ",symbol," due to ",reason);

   if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
     {
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action  = TRADE_ACTION_REMOVE;
      req.order   = ticket;
      req.comment = "Blocked: "+reason;
      if(!OrderSend(req,res))
         Print("Failed to cancel order ",ticket,": ",res.comment);
     }
   else
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
        {
         ulong posTicket = HistoryDealGetInteger(ticket,DEAL_POSITION_ID);
         if(posTicket == 0)
            return;
         if(!PositionSelectByTicket(posTicket))
           {
            Print("Position ",posTicket," not found.");
            return;
           }

         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action    = TRADE_ACTION_DEAL;
         req.position  = posTicket;
         req.symbol    = symbol;
         req.volume    = PositionGetDouble(POSITION_VOLUME);
         req.deviation = 5;
         req.comment   = "Blocked: "+reason;

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            req.price = SymbolInfoDouble(symbol,SYMBOL_BID);
            req.type  = ORDER_TYPE_SELL;
           }
         else
           {
            req.price = SymbolInfoDouble(symbol,SYMBOL_ASK);
            req.type  = ORDER_TYPE_BUY;
           }

         if(!OrderSend(req,res))
            Print("Failed to close position ",posTicket,": ",res.comment);
        }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| IsTradingAllowed (for other EAs to call)                         |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
  {
   THN::Refresh();
   return(THN::IsAllowedNow());
  }
//+------------------------------------------------------------------+
