//+------------------------------------------------------------------+
//|                                      SymbolWhitelistEnforcer.mq5 |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.00"
#property strict
#property description "Blocks any trade on symbols not in the whitelist."

#include <SymbolWhitelist.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("SymbolWhitelistEnforcer started. AutoTrading must be enabled.");
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   Print("SymbolWhitelistEnforcer stopped.");
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Timer function (not strictly needed)                             |
//+------------------------------------------------------------------+
void OnTimer()
  {
//--- Nothing to do here
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trade transaction handler – blocks disallowed symbols            |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   string symbol = "";
   ulong ticket = 0;
   bool isManual = false;

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
      symbol = OrderGetString(ORDER_SYMBOL);
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
            symbol = HistoryDealGetString(ticket,DEAL_SYMBOL);
            long magic = HistoryDealGetInteger(ticket,DEAL_MAGIC);
            isManual = (magic == 0);
           }
        }
      else
         return;

   if(symbol == "")
      return;

   if(!SWL::IsSymbolAllowed(symbol))
     {
      string source = isManual ? "manual" : "EA";
      Print("Blocking ",source," trade on disallowed symbol: ",symbol);
      SWL::LogBlockedAttempt(TimeCurrent(),symbol,source);

      if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
        {
         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action   = TRADE_ACTION_REMOVE;
         req.order    = ticket;
         req.comment  = "Symbol not whitelisted";
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
            req.comment   = "Symbol not whitelisted";

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
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
