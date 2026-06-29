//+------------------------------------------------------------------+
//|                                            CDisciplineEngine.mqh |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"

#include "DailyTradeLimit.mqh"
#include "SymbolWhitelist.mqh"
#include "TradingHoursNews.mqh"

//+------------------------------------------------------------------+
//| Unified trading gate (no position enforcement)                   |
//+------------------------------------------------------------------+
class CDisciplineEngine
  {
private:
   bool              m_initialized;

public:
                     CDisciplineEngine() { m_initialized = false; }

   //--- call once at start
   bool              Init()
     {
      DTL::ForceRefresh();
      THN::Refresh();
      m_initialized = true;
      Print("[ENGINE] Initialized.");
      return true;
     }

   //--- pre‑trade gate: whitelist + hours/news + daily limit
   bool              IsTradeAllowed(string symbol)
     {
      if(!m_initialized)
         return false;
      if(!SWL::IsSymbolAllowed(symbol))
         return false;
      THN::Refresh();
      if(!THN::IsAllowedNow())
         return false;
      DTL::Refresh();
      if(!DTL::IsTradingAllowed())
         return false;
      return true;
     }

   //--- call after a successful trade to increment daily counter
   void              RecordTrade() { DTL::ForceRefresh(); }

   //--- dashboard getters (no risk, no RR, no modes)
   bool              IsInitialized() const          { return m_initialized; }
   bool              IsSymbolAllowed(string s)      { return SWL::IsSymbolAllowed(s); }
   bool              IsTradingHoursAllowed()        { THN::Refresh(); return THN::IsAllowedNow(); }
   bool              IsDailyLimitAllowed()          { DTL::Refresh(); return DTL::IsTradingAllowed(); }
   int               GetTradesToday()               { DTL::Refresh(); return DTL::TradesToday(); }
   int               GetDailyLimit()                { return DTL::GetParamLimit(); }
   int               GetAmberZone()                 { return DTL::GetParamAmber(); }
   string            GetNextSession()               { THN::Refresh(); return THN::GetNextSession(); }
   string            GetNextNews()                  { THN::Refresh(); return THN::GetNextNews(); }
  };
//+------------------------------------------------------------------+
