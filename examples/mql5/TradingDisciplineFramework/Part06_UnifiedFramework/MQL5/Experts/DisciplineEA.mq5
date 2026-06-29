//+------------------------------------------------------------------+
//|                                                TradeEnforcer.mq5 |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <DisciplineFramework/CDisciplineEngine.mqh>

//--- input
input int EnforceIntervalSec = 5;

CDisciplineEngine g_enforcer;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!g_enforcer.Init())
     {
      Print("[ENFORCER] Init failed.");
      return INIT_FAILED;
     }
   if(!EventSetTimer(EnforceIntervalSec))
     {
      Print("[ENFORCER] Timer failed.");
      return INIT_FAILED;
     }
   Print("[ENFORCER] Started. Monitoring all new trades.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//|deinitialization                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   Print("[ENFORCER] Stopped.");
  }

//+------------------------------------------------------------------+
//| Timer – periodic scan for any missed positions                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(!IsPositionValid(symbol))
        {
         Print("[ENFORCER] Periodic close of ", symbol, " ticket ", ticket);
         ClosePosition(ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//| OnTradeTransaction                                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
//--- correct constant: TRADE_TRANSACTION_DEAL_ADD
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong dealTicket = trans.deal;
      if(HistoryDealSelect(dealTicket))
        {
         long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(entryType == DEAL_ENTRY_IN)
           {
            string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            if(!IsPositionValid(symbol))
              {
               ulong positionTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
               if(positionTicket > 0 && PositionSelectByTicket(positionTicket))
                 {
                  Print("[ENFORCER] Violation detected. Closing new trade on ", symbol, " ticket ", positionTicket);
                  ClosePosition(positionTicket);
                 }
              }
            else
              {
               g_enforcer.RecordTrade();
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Check if a position is valid under all rules                     |
//+------------------------------------------------------------------+
bool IsPositionValid(string symbol)
  {
   if(!g_enforcer.IsSymbolAllowed(symbol))
      return false;
   if(!g_enforcer.IsTradingHoursAllowed())
      return false;
   int tradesNow = g_enforcer.GetTradesToday();
   int limit = g_enforcer.GetDailyLimit();
   if(tradesNow > limit)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//| Close a position                                                 |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
  {
   CTrade trade;
   trade.PositionClose(ticket);
   if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      Print("[ENFORCER] Closed position ", ticket);
   else
      Print("[ENFORCER] Failed to close ", ticket, " error ", trade.ResultRetcode());
  }

//+------------------------------------------------------------------+
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick() { }
//+------------------------------------------------------------------+
