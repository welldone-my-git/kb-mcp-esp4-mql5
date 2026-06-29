//+------------------------------------------------------------------+
//|                                              DailyTradeLimit.mqh |
//|                                   Copyright 2026, MetaQuotes Ltd.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| namespace DTL                                                   |
//+------------------------------------------------------------------+
namespace DTL
{
//--- enumeration for state
enum ENUM_DTL_STATE
  {
   STATE_ALLOWED = 0,   // Green
   STATE_CAUTION = 1,   // Amber
   STATE_LIMIT   = 2    // Red
  };

//--- default parameter values (used if globals not set)
const int    DEFAULT_LIMIT       = 5;
const string DEFAULT_START_TIME  = "00:00";
const int    DEFAULT_AMBER       = 1;
const int    REFRESH_INTERVAL    = 1;          // seconds (for normal Refresh)

//--- internal cache (static, per including program)
static datetime s_lastRefresh = 0;
static datetime s_dayStart    = 0;
static int      s_tradesToday = 0;
static ENUM_DTL_STATE s_state = STATE_ALLOWED;

//+------------------------------------------------------------------+
//| Convert "HH:MM" to integer (HHMM)                               |
//+------------------------------------------------------------------+
int TimeToInt(string timeStr)
  {
   string parts[];
   if(StringSplit(timeStr,':',parts)!=2)
      return 0;   // default to 00:00
   int h = (int)StringToInteger(parts[0]);
   int m = (int)StringToInteger(parts[1]);
   return h*100 + m;
  }

//+------------------------------------------------------------------+
//| Convert integer (HHMM) to "HH:MM"                               |
//+------------------------------------------------------------------+
string IntToTime(int value)
  {
   int h = value / 100;
   int m = value % 100;
   return StringFormat("%02d:%02d", h, m);
  }

//+------------------------------------------------------------------+
//| Read parameter from global variable or use default              |
//+------------------------------------------------------------------+
int GetParamLimit()
  {
   if(GlobalVariableCheck("DTL_LIMIT"))
      return (int)GlobalVariableGet("DTL_LIMIT");
   return DEFAULT_LIMIT;
  }

string GetParamStartTime()
  {
   if(GlobalVariableCheck("DTL_START_TIME"))
     {
      int t = (int)GlobalVariableGet("DTL_START_TIME");
      return IntToTime(t);
     }
   return DEFAULT_START_TIME;
  }

int GetParamAmber()
  {
   if(GlobalVariableCheck("DTL_AMBER"))
      return (int)GlobalVariableGet("DTL_AMBER");
   return DEFAULT_AMBER;
  }

//+------------------------------------------------------------------+
//| Parse time string "HH:MM"                                       |
//+------------------------------------------------------------------+
bool ParseTime(string txt,int &h,int &m)
  {
   string parts[];
   if(StringSplit(txt,':',parts)<2)
      return false;
   h = (int)StringToInteger(parts[0]);
   m = (int)StringToInteger(parts[1]);
   return (h>=0 && h<=23 && m>=0 && m<=59);
  }

//+------------------------------------------------------------------+
//| Calculate start of current trading day                          |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime now,string startTime)
  {
   int h=0,m=0;
   if(!ParseTime(startTime,h,m))
     {
      h=0;
      m=0;
     }
   MqlDateTime t;
   TimeToStruct(now,t);

// if current time is before today's start, use yesterday
   if(t.hour<h || (t.hour==h && t.min<m))
      now -= 86400;
   TimeToStruct(now,t);

   t.hour = h;
   t.min  = m;
   t.sec  = 0;
   return StructToTime(t);
  }

//+------------------------------------------------------------------+
//| Count trades (deals with DEAL_ENTRY_IN) since given time        |
//+------------------------------------------------------------------+
int CountTrades(datetime from)
  {
   datetime to = from + 86400;   // one day later
   if(!HistorySelect(from,to))
      return 0;

   int total = HistoryDealsTotal();
   int cnt = 0;
   for(int i=0;i<total;i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket>0 && HistoryDealGetInteger(ticket,DEAL_ENTRY)==DEAL_ENTRY_IN)
         cnt++;
     }
   return cnt;
  }

//+------------------------------------------------------------------+
//| Compute state from trades count and limit                       |
//+------------------------------------------------------------------+
ENUM_DTL_STATE CalcState(int trades,int limit,int amber)
  {
   if(trades>=limit)
      return STATE_LIMIT;
   if(limit-trades <= amber)
      return STATE_CAUTION;
   return STATE_ALLOWED;
  }

//+------------------------------------------------------------------+
//| Refresh internal cache – respects time caching                  |
//| Returns true if state changed                                    |
//+------------------------------------------------------------------+
bool Refresh()
  {
   datetime now = TimeCurrent();
   if(now - s_lastRefresh < REFRESH_INTERVAL)
      return false;                     // too soon, use cached values

   return ForceRefresh();                // do the actual recount
  }

//+------------------------------------------------------------------+
//| Force a full refresh – ignores time cache                       |
//| Returns true if state changed                                    |
//+------------------------------------------------------------------+
bool ForceRefresh()
  {
   datetime now = TimeCurrent();
   int   limit = GetParamLimit();
   string st   = GetParamStartTime();
   int   amber = GetParamAmber();

   datetime newDayStart = GetDayStart(now,st);
   int newTrades = 0;

   if(newDayStart != s_dayStart)
     {
      s_dayStart = newDayStart;
      newTrades = CountTrades(s_dayStart);
     }
   else
     {
      newTrades = CountTrades(s_dayStart);
     }

   ENUM_DTL_STATE newState = CalcState(newTrades,limit,amber);
   bool changed = (newState != s_state) || (newTrades != s_tradesToday);

   s_tradesToday = newTrades;
   s_state = newState;
   s_lastRefresh = now;

   return changed;
  }

//+------------------------------------------------------------------+
//| Getters                                                         |
//+------------------------------------------------------------------+
int TradesToday() { return s_tradesToday; }
int Remaining()   { int limit = GetParamLimit(); return (limit - s_tradesToday > 0) ? limit - s_tradesToday : 0; }
bool IsTradingAllowed() { return (s_state != STATE_LIMIT); }
ENUM_DTL_STATE GetState() { return s_state; }

string StateToString(ENUM_DTL_STATE st)
  {
   switch(st)
     {
      case STATE_ALLOWED:
         return "TRADING ALLOWED";
      case STATE_CAUTION:
         return "CAUTION (LIMIT NEAR)";
      case STATE_LIMIT:
         return "TRADING LIMIT REACHED";
     }
   return "";
  }

datetime GetDayStart() { return s_dayStart; }

//+------------------------------------------------------------------+
//| Set parameters (store in terminal global variables)             |
//+------------------------------------------------------------------+
bool SetParameters(int limit,string startTime,int amber)
  {
   if(!GlobalVariableSet("DTL_LIMIT",limit))
      return false;
   int t = TimeToInt(startTime);
   if(!GlobalVariableSet("DTL_START_TIME",t))
      return false;
   if(!GlobalVariableSet("DTL_AMBER",amber))
      return false;
   s_lastRefresh = 0;   // force refresh on next call
   return true;
  }

} // namespace
//+------------------------------------------------------------------+
