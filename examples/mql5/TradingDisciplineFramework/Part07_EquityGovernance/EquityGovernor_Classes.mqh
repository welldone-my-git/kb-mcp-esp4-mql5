//+------------------------------------------------------------------+
//|                                       EquityGovernor_Classes.mqh |
//|                              Copyright 2026, Christian Benjamin. |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"

#include <Trade\Trade.mqh>

//--- Visualizer constants
#define VIS_LINE_HEIGHT  14
#define VIS_PANEL_WIDTH   200
#define VIS_NUM_LINES     9

enum ENUM_GOV_STATE
  {
   GOV_NORMAL,
   GOV_CAUTION,
   GOV_RESTRICTED,
   GOV_LOCKDOWN
  };

enum ENUM_DD_PRESSURE
  {
   DD_NORMAL,
   DD_CAUTION,
   DD_RESTRICTED,
   DD_LOCKDOWN
  };

enum ENUM_AUTH_RESULT
  {
   AUTH_GRANTED,
   AUTH_DENIED_STATE,
   AUTH_DENIED_DRAWDOWN,
   AUTH_DENIED_DAILY_LOSS
  };

//+------------------------------------------------------------------+
//| Equity monitoring and daily balance tracking                     |
//+------------------------------------------------------------------+
class CEquityMonitor
  {
private:
   double            m_equity;
   double            m_peak;
   double            m_drawdownLow;
   double            m_dailyStart;
   int               m_lastDay;
public:
                     CEquityMonitor();
   void              Init();
   void              Update();
   //--- Returns the current account equity
   double            GetEquity() const
     {
      return m_equity;
     }
   //--- Returns the peak equity reached since initialization
   double            GetPeak() const
     {
      return m_peak;
     }
   double            GetDrawdownPercent() const;
   double            GetDailyLossPercent() const;
  };

//+------------------------------------------------------------------+
//| Initializes equity monitoring state                              |
//+------------------------------------------------------------------+
CEquityMonitor::CEquityMonitor()
  {
   m_equity      = 0;
   m_peak        = 0;
   m_drawdownLow = 0;
   m_dailyStart  = 0;
   m_lastDay     = -1;
  }

//+------------------------------------------------------------------+
//| Captures the initial equity reference values                     |
//+------------------------------------------------------------------+
void CEquityMonitor::Init()
  {
   Update();
   m_peak        = m_equity;
   m_drawdownLow = m_equity;
   m_dailyStart  = m_equity;
  }

//+------------------------------------------------------------------+
//| Updates current equity, peak equity, and daily reference         |
//+------------------------------------------------------------------+
void CEquityMonitor::Update()
  {
   m_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(m_equity > m_peak)
      m_peak = m_equity;
   if(m_equity < m_drawdownLow)
      m_drawdownLow = m_equity;

   MqlDateTime tm;
   TimeCurrent(tm);
   if(m_lastDay != tm.day)
     {
      m_lastDay    = tm.day;
      m_dailyStart = m_equity;
     }
  }

//+------------------------------------------------------------------+
//| Calculates drawdown as a percentage of peak equity               |
//+------------------------------------------------------------------+
double CEquityMonitor::GetDrawdownPercent() const
  {
   if(m_peak <= 0)
      return 0;
   return (m_peak - m_equity) / m_peak * 100.0;
  }

//+------------------------------------------------------------------+
//| Calculates today's loss as a percentage of daily start equity    |
//+------------------------------------------------------------------+
double CEquityMonitor::GetDailyLossPercent() const
  {
   if(m_dailyStart <= 0 || m_equity >= m_dailyStart)
      return 0;
   return (m_dailyStart - m_equity) / m_dailyStart * 100.0;
  }

//+------------------------------------------------------------------+
//| Analyzes drawdown pressure and rapid equity collapse             |
//+------------------------------------------------------------------+
class CDrawdownAnalyzer
  {
private:
   double            m_normalMax;
   double            m_cautionMax;
   double            m_restrictedMax;
   double            m_rapidPct;
   int               m_rapidSec;
   datetime          m_lastCheck;
   double            m_equityAtCheck;
public:
                     CDrawdownAnalyzer();
   void              SetThresholds(double n, double c, double r);
   ENUM_DD_PRESSURE  GetPressure(double dd) const;
   bool              IsRapidCollapse(CEquityMonitor &mon);
   static string     PressureToString(ENUM_DD_PRESSURE p);
  };

//+------------------------------------------------------------------+
//| Initializes drawdown thresholds and rapid-collapse settings      |
//+------------------------------------------------------------------+
CDrawdownAnalyzer::CDrawdownAnalyzer()
  {
   m_normalMax     = 2.0;
   m_cautionMax    = 4.0;
   m_restrictedMax = 6.0;
   m_rapidPct      = 3.0;
   m_rapidSec      = 10;
   m_lastCheck     = 0;
   m_equityAtCheck = 0;
  }

//+------------------------------------------------------------------+
//| Sets drawdown threshold levels                                   |
//+------------------------------------------------------------------+
void CDrawdownAnalyzer::SetThresholds(double n, double c, double r)
  {
   m_normalMax     = n;
   m_cautionMax    = c;
   m_restrictedMax = r;
  }

//+------------------------------------------------------------------+
//| Converts drawdown percentage into a pressure level               |
//+------------------------------------------------------------------+
ENUM_DD_PRESSURE CDrawdownAnalyzer::GetPressure(double dd) const
  {
   if(dd < m_normalMax)
      return DD_NORMAL;
   if(dd < m_cautionMax)
      return DD_CAUTION;
   if(dd < m_restrictedMax)
      return DD_RESTRICTED;
   return DD_LOCKDOWN;
  }

//+------------------------------------------------------------------+
//| Detects whether equity dropped sharply within a short interval   |
//+------------------------------------------------------------------+
bool CDrawdownAnalyzer::IsRapidCollapse(CEquityMonitor &mon)
  {
   datetime now = TimeCurrent();
   if(m_lastCheck == 0)
     {
      m_lastCheck     = now;
      m_equityAtCheck = mon.GetEquity();
      return false;
     }

   int elapsed = (int)(now - m_lastCheck);
   if(elapsed >= m_rapidSec)
     {
      m_lastCheck     = now;
      m_equityAtCheck = mon.GetEquity();
      return false;
     }

   if(m_equityAtCheck <= 0)
      return false;

   double decline = (m_equityAtCheck - mon.GetEquity()) / m_equityAtCheck * 100.0;
   if(decline >= m_rapidPct)
     {
      m_lastCheck     = now;
      m_equityAtCheck = mon.GetEquity();
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Converts pressure enum to a text label                           |
//+------------------------------------------------------------------+
string CDrawdownAnalyzer::PressureToString(ENUM_DD_PRESSURE p)
  {
   switch(p)
     {
      case DD_NORMAL:
         return "NORMAL";
      case DD_CAUTION:
         return "CAUTION";
      case DD_RESTRICTED:
         return "RESTRICTED";
      case DD_LOCKDOWN:
         return "LOCKDOWN";
      default:
         return "UNKNOWN";
     }
  }

//+------------------------------------------------------------------+
//| Manages cooldown timing and equity recovery checks               |
//+------------------------------------------------------------------+
class CRecoveryCooldown
  {
private:
   datetime          m_lockdownEnd;
   datetime          m_restrictedEnd;
   int               m_lockdownSec;
   int               m_restrictedSec;
   double            m_recoveryThreshold;
   CEquityMonitor    *m_mon;
public:
                     CRecoveryCooldown();
   void              Init(CEquityMonitor *mon);
   void              SetParams(int l, int r, double thr);
   void              StartLockdown();
   void              StartRestricted();
   //--- Checks whether lockdown cooldown has expired
   bool              LockdownExpired() const
     {
      return TimeCurrent() >= m_lockdownEnd;
     }
   //--- Checks whether restricted cooldown can be lifted
   bool              CanDowngradeFromRestricted();
   int               GetLockdownRem() const;
   void              ResetLockdown();
   void              ResetRestricted();
  };

//+------------------------------------------------------------------+
//| Initializes cooldown timers and recovery settings                |
//+------------------------------------------------------------------+
CRecoveryCooldown::CRecoveryCooldown()
  {
   m_lockdownEnd       = 0;
   m_restrictedEnd     = 0;
   m_lockdownSec       = 300;
   m_restrictedSec     = 180;
   m_recoveryThreshold = 0.99;
   m_mon               = NULL;
  }

//+------------------------------------------------------------------+
//| Stores the equity monitor reference                              |
//+------------------------------------------------------------------+
void CRecoveryCooldown::Init(CEquityMonitor *mon)
  {
   m_mon = mon;
  }

//+------------------------------------------------------------------+
//| Configures cooldown durations and recovery threshold             |
//+------------------------------------------------------------------+
void CRecoveryCooldown::SetParams(int l, int r, double thr)
  {
   m_lockdownSec       = l;
   m_restrictedSec     = r;
   m_recoveryThreshold = thr;
  }

//+------------------------------------------------------------------+
//| Starts the lockdown cooldown timer                               |
//+------------------------------------------------------------------+
void CRecoveryCooldown::StartLockdown()
  {
   m_lockdownEnd = TimeCurrent() + m_lockdownSec;
  }

//+------------------------------------------------------------------+
//| Starts the restricted cooldown timer                             |
//+------------------------------------------------------------------+
void CRecoveryCooldown::StartRestricted()
  {
   m_restrictedEnd = TimeCurrent() + m_restrictedSec;
  }

//+------------------------------------------------------------------+
//| Determines whether restricted mode can be downgraded             |
//+------------------------------------------------------------------+
bool CRecoveryCooldown::CanDowngradeFromRestricted()
  {
   if(TimeCurrent() < m_restrictedEnd)
      return false;
   if(m_mon == NULL)
      return true;

   double peak = m_mon->GetPeak();
   double cur  = m_mon->GetEquity();
   if(peak <= 0)
      return true;

   return (cur / peak) >= m_recoveryThreshold;
  }

//+------------------------------------------------------------------+
//| Returns remaining lockdown time in seconds                       |
//+------------------------------------------------------------------+
int CRecoveryCooldown::GetLockdownRem() const
  {
   if(TimeCurrent() < m_lockdownEnd)
      return (int)(m_lockdownEnd - TimeCurrent());
   return 0;
  }

//+------------------------------------------------------------------+
//| Clears the lockdown timer                                         |
//+------------------------------------------------------------------+
void CRecoveryCooldown::ResetLockdown()
  {
   m_lockdownEnd = 0;
  }

//+------------------------------------------------------------------+
//| Clears the restricted timer                                       |
//+------------------------------------------------------------------+
void CRecoveryCooldown::ResetRestricted()
  {
   m_restrictedEnd = 0;
  }

//+------------------------------------------------------------------+
//| Governs state transitions based on pressure and recovery logic   |
//+------------------------------------------------------------------+
class CGovernanceStateEngine
  {
private:
   ENUM_GOV_STATE    m_state;
   ENUM_GOV_STATE    m_prev;
   int               m_stableCount;
   CRecoveryCooldown *m_cd;
public:
                     CGovernanceStateEngine();
   void              Init(CRecoveryCooldown *cd);
   void              Update(ENUM_DD_PRESSURE pressure, bool rapid);
   //--- Returns the current governance state
   ENUM_GOV_STATE    Get() const
     {
      return m_state;
     }
   static string     ToString(ENUM_GOV_STATE s);
  };

//+------------------------------------------------------------------+
//| Initializes the governance state engine                          |
//+------------------------------------------------------------------+
CGovernanceStateEngine::CGovernanceStateEngine()
  {
   m_state       = GOV_NORMAL;
   m_prev        = GOV_NORMAL;
   m_stableCount = 0;
   m_cd          = NULL;
  }

//+------------------------------------------------------------------+
//| Attaches the cooldown manager and resets state                  |
//+------------------------------------------------------------------+
void CGovernanceStateEngine::Init(CRecoveryCooldown *cd)
  {
   m_cd          = cd;
   m_state       = GOV_NORMAL;
   m_prev        = GOV_NORMAL;
   m_stableCount = 0;
  }

//+------------------------------------------------------------------+
//| Updates the governance state machine                             |
//+------------------------------------------------------------------+
void CGovernanceStateEngine::Update(ENUM_DD_PRESSURE pressure, bool rapid)
  {
   ENUM_GOV_STATE newState = m_state;

   switch(m_state)
     {
      case GOV_NORMAL:
         if(pressure == DD_LOCKDOWN)
            newState = GOV_LOCKDOWN;
         else
            if(pressure >= DD_RESTRICTED)
               newState = GOV_RESTRICTED;
            else
               if(pressure >= DD_CAUTION || rapid)
                  newState = GOV_CAUTION;
         break;

      case GOV_CAUTION:
         if(pressure == DD_NORMAL)
           {
            m_stableCount++;
            if(m_stableCount >= 3)
               newState = GOV_NORMAL;
           }
         else
           {
            m_stableCount = 0;
            if(pressure >= DD_RESTRICTED || rapid)
               newState = GOV_RESTRICTED;
            if(pressure == DD_LOCKDOWN)
               newState = GOV_LOCKDOWN;
           }
         break;

      case GOV_RESTRICTED:
         if(rapid || pressure == DD_LOCKDOWN)
           {
            newState = GOV_LOCKDOWN;
            if(m_cd != NULL)
               m_cd->StartLockdown();
           }
         else
            if(pressure == DD_NORMAL && m_cd != NULL && m_cd->CanDowngradeFromRestricted())
              {
               newState = GOV_CAUTION;
               m_stableCount = 0;
               if(m_cd != NULL)
                  m_cd->ResetRestricted();
              }
         break;

      case GOV_LOCKDOWN:
         if(m_cd != NULL && m_cd->LockdownExpired() && pressure <= DD_NORMAL)
           {
            newState = GOV_RESTRICTED;
            if(m_cd != NULL)
               m_cd->StartRestricted();
           }
         break;
     }

   if(newState != m_state)
     {
      m_prev        = m_state;
      m_state       = newState;
      m_stableCount = 0;
     }
  }

//+------------------------------------------------------------------+
//| Converts governance state enum to a text label                  |
//+------------------------------------------------------------------+
string CGovernanceStateEngine::ToString(ENUM_GOV_STATE s)
  {
   switch(s)
     {
      case GOV_NORMAL:
         return "NORMAL";
      case GOV_CAUTION:
         return "CAUTION";
      case GOV_RESTRICTED:
         return "RESTRICTED";
      case GOV_LOCKDOWN:
         return "LOCKDOWN";
      default:
         return "UNKNOWN";
     }
  }

//+------------------------------------------------------------------+
//| Enforces trading restrictions in caution and lower states       |
//+------------------------------------------------------------------+
class CRestrictionEnforcer
  {
private:
   double            m_cautionLotMult;
   int               m_maxPositions;
   int               m_minSec;
   datetime          m_lastTrade;
public:
                     CRestrictionEnforcer();
   void              SetParams(double mult, int maxPos, int sec);
   double            GetLotMult(ENUM_GOV_STATE state) const;
   bool              IsTradeAllowed(ENUM_GOV_STATE state, int currentPositions);
   void              RecordTrade();
  };

//+------------------------------------------------------------------+
//| Initializes caution-mode restriction parameters                  |
//+------------------------------------------------------------------+
CRestrictionEnforcer::CRestrictionEnforcer()
  {
   m_cautionLotMult = 0.5;
   m_maxPositions   = 1;
   m_minSec         = 60;
   m_lastTrade      = 0;
  }

//+------------------------------------------------------------------+
//| Sets caution-mode lot multiplier and execution limits            |
//+------------------------------------------------------------------+
void CRestrictionEnforcer::SetParams(double mult, int maxPos, int sec)
  {
   m_cautionLotMult = mult;
   m_maxPositions   = maxPos;
   m_minSec         = sec;
  }

//+------------------------------------------------------------------+
//| Returns the lot multiplier for the current governance state      |
//+------------------------------------------------------------------+
double CRestrictionEnforcer::GetLotMult(ENUM_GOV_STATE state) const
  {
   if(state == GOV_NORMAL)
      return 1.0;
   if(state == GOV_CAUTION)
      return m_cautionLotMult;
   return 0.0;
  }

//+------------------------------------------------------------------+
//| Determines whether a new trade may be opened                     |
//+------------------------------------------------------------------+
bool CRestrictionEnforcer::IsTradeAllowed(ENUM_GOV_STATE state, int currentPositions)
  {
   if(state == GOV_NORMAL)
      return true;
   if(state == GOV_CAUTION)
     {
      if(currentPositions >= m_maxPositions)
         return false;
      if(m_lastTrade != 0)
        {
         if((TimeCurrent() - m_lastTrade) < m_minSec)
            return false;
        }
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Stores the time of the latest trade                              |
//+------------------------------------------------------------------+
void CRestrictionEnforcer::RecordTrade()
  {
   m_lastTrade = TimeCurrent();
  }

//+------------------------------------------------------------------+
//| Validates trades against state rules and hard equity limits      |
//+------------------------------------------------------------------+
class CTradeAuthorizer
  {
private:
   CGovernanceStateEngine  *m_state;
   CRestrictionEnforcer    *m_enforcer;
   CEquityMonitor          *m_mon;
   double                  m_maxDD;
   double                  m_maxDailyLoss;
public:
                     CTradeAuthorizer();
   void                    Init(CGovernanceStateEngine *s, CRestrictionEnforcer *e, CEquityMonitor *m);
   void                    SetLimits(double dd, double dl);
   ENUM_AUTH_RESULT        Authorize(double lot, string &reason, int positions);
   double                  GetLotMultiplier();
  };

//+------------------------------------------------------------------+
//| Initializes the trade authorization layer                        |
//+------------------------------------------------------------------+
CTradeAuthorizer::CTradeAuthorizer()
  {
   m_state        = NULL;
   m_enforcer     = NULL;
   m_mon          = NULL;
   m_maxDD        = 8.0;
   m_maxDailyLoss = 5.0;
  }

//+------------------------------------------------------------------+
//| Connects the state engine, restriction enforcer, and monitor     |
//+------------------------------------------------------------------+
void CTradeAuthorizer::Init(CGovernanceStateEngine *s, CRestrictionEnforcer *e, CEquityMonitor *m)
  {
   m_state    = s;
   m_enforcer = e;
   m_mon      = m;
  }

//+------------------------------------------------------------------+
//| Sets hard drawdown and daily loss limits                         |
//+------------------------------------------------------------------+
void CTradeAuthorizer::SetLimits(double dd, double dl)
  {
   m_maxDD        = dd;
   m_maxDailyLoss = dl;
  }

//+------------------------------------------------------------------+
//| Checks whether a trade request is authorized                     |
//+------------------------------------------------------------------+
ENUM_AUTH_RESULT CTradeAuthorizer::Authorize(double lot, string &reason, int positions)
  {
   if(m_state == NULL || m_enforcer == NULL || m_mon == NULL)
     {
      reason = "Init fail";
      return AUTH_DENIED_STATE;
     }

   ENUM_GOV_STATE state = m_state->Get();
   if(!m_enforcer->IsTradeAllowed(state, positions))
     {
      reason = "State " + CGovernanceStateEngine::ToString(state);
      return AUTH_DENIED_STATE;
     }

   if(m_mon->GetDrawdownPercent() >= m_maxDD)
     {
      reason = "DD limit";
      return AUTH_DENIED_DRAWDOWN;
     }

   if(m_mon->GetDailyLossPercent() >= m_maxDailyLoss)
     {
      reason = "Daily loss limit";
      return AUTH_DENIED_DAILY_LOSS;
     }

   reason = "";
   return AUTH_GRANTED;
  }

//+------------------------------------------------------------------+
//| Returns the current lot multiplier from the active state         |
//+------------------------------------------------------------------+
double CTradeAuthorizer::GetLotMultiplier()
  {
   if(m_enforcer == NULL || m_state == NULL)
      return 1.0;
   return m_enforcer->GetLotMult(m_state->Get());
  }

//+------------------------------------------------------------------+
//| Logs governance events to the Experts tab                        |
//+------------------------------------------------------------------+
class CEventLogger
  {
private:
   bool              m_toExperts;
public:
   //--- Initializes event logging to Experts tab
                     CEventLogger()
     {
      m_toExperts = true;
     }
   //--- Enables or disables logging to Experts tab
   void              SetToExperts(bool b)
     {
      m_toExperts = b;
     }
   void              Log(string msg);
   void              LogStateChange(ENUM_GOV_STATE from, ENUM_GOV_STATE to, double dd);
  };

//+------------------------------------------------------------------+
//| Prints a governance message                                      |
//+------------------------------------------------------------------+
void CEventLogger::Log(string msg)
  {
   if(m_toExperts)
      Print("[GOV] ", msg);
  }

//+------------------------------------------------------------------+
//| Prints a governance state transition message                     |
//+------------------------------------------------------------------+
void CEventLogger::LogStateChange(ENUM_GOV_STATE from, ENUM_GOV_STATE to, double dd)
  {
   Log(StringFormat("State: %s -> %s | DD=%.2f%%",
                    CGovernanceStateEngine::ToString(from),
                    CGovernanceStateEngine::ToString(to), dd));
  }

//+------------------------------------------------------------------+
//| Renders a dashboard for equity governance status                 |
//+------------------------------------------------------------------+
class CVisualizer
  {
private:
   CGovernanceStateEngine  *m_state;
   CEquityMonitor          *m_mon;
   CRecoveryCooldown       *m_cd;
   CRestrictionEnforcer    *m_enf;
   int                     m_corner;
   int                     m_x;
   int                     m_y;
   string                  m_prefix;
   bool                    m_visible;
   color                   m_bgColor;

   color                   StateColor(ENUM_GOV_STATE s);
   void                    Label(string name, string txt, int x, int y, color clr, int sz = 9);
   void                    UpdatePanel();
public:
                     CVisualizer();
   void                    Init(CGovernanceStateEngine *s, CEquityMonitor *m, CRecoveryCooldown *c, CRestrictionEnforcer *e);
   void                    SetPos(int corner, int x, int y);
   //--- Sets the dashboard background color
   void                    SetBackgroundColor(color clr)
     {
      m_bgColor = clr;
     }
   void                    Refresh();
   void                    Hide();
  };

//+------------------------------------------------------------------+
//| Initializes dashboard objects and layout defaults                |
//+------------------------------------------------------------------+
CVisualizer::CVisualizer()
  {
   m_state   = NULL;
   m_mon     = NULL;
   m_cd      = NULL;
   m_enf     = NULL;
   m_corner  = CORNER_LEFT_UPPER;
   m_x       = 10;
   m_y       = 30;
   m_prefix  = "GOV_";
   m_visible = true;
   m_bgColor = (color)0x80000000;
  }

//+------------------------------------------------------------------+
//| Attaches data sources to the dashboard                           |
//+------------------------------------------------------------------+
void CVisualizer::Init(CGovernanceStateEngine *s, CEquityMonitor *m, CRecoveryCooldown *c, CRestrictionEnforcer *e)
  {
   m_state = s;
   m_mon   = m;
   m_cd    = c;
   m_enf   = e;
  }

//+------------------------------------------------------------------+
//| Sets dashboard position on the chart                             |
//+------------------------------------------------------------------+
void CVisualizer::SetPos(int corner, int x, int y)
  {
   m_corner = corner;
   m_x      = x;
   m_y      = y;
  }

//+------------------------------------------------------------------+
//| Returns a display color for each governance state                |
//+------------------------------------------------------------------+
color CVisualizer::StateColor(ENUM_GOV_STATE s)
  {
   switch(s)
     {
      case GOV_NORMAL:
         return clrGreen;
      case GOV_CAUTION:
         return clrYellow;
      case GOV_RESTRICTED:
         return clrOrange;
      case GOV_LOCKDOWN:
         return clrRed;
      default:
         return clrWhite;
     }
  }

//+------------------------------------------------------------------+
//| Creates or updates a dashboard text label                        |
//+------------------------------------------------------------------+
void CVisualizer::Label(string name, string txt, int x, int y, color clr, int sz = 9)
  {
   string full = m_prefix + name;
   if(ObjectFind(0, full) < 0)
      ObjectCreate(0, full, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, full, OBJPROP_CORNER, m_corner);
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, full, OBJPROP_FONTSIZE, sz);
   ObjectSetInteger(0, full, OBJPROP_COLOR, clr);
   ObjectSetString(0, full, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, full, OBJPROP_HIDDEN, !m_visible);
  }

//+------------------------------------------------------------------+
//| Creates or updates the dashboard panel background                |
//+------------------------------------------------------------------+
void CVisualizer::UpdatePanel()
  {
   string pnlName = m_prefix + "panel";
   if(ObjectFind(0, pnlName) < 0)
      ObjectCreate(0, pnlName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   int panelWidth  = VIS_PANEL_WIDTH;
   int panelHeight = VIS_NUM_LINES * VIS_LINE_HEIGHT;

   ObjectSetInteger(0, pnlName, OBJPROP_CORNER, m_corner);
   ObjectSetInteger(0, pnlName, OBJPROP_XDISTANCE, m_x - 5);
   ObjectSetInteger(0, pnlName, OBJPROP_YDISTANCE, m_y - 5);
   ObjectSetInteger(0, pnlName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, pnlName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, pnlName, OBJPROP_BGCOLOR, m_bgColor);
   ObjectSetInteger(0, pnlName, OBJPROP_BORDER_COLOR, clrDarkGray);
   ObjectSetInteger(0, pnlName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, pnlName, OBJPROP_HIDDEN, !m_visible);
  }

//+------------------------------------------------------------------+
//| Refreshes dashboard values on the chart                          |
//+------------------------------------------------------------------+
void CVisualizer::Refresh()
  {
   if(m_state == NULL || m_mon == NULL)
      return;

   UpdatePanel();

   ENUM_GOV_STATE s = m_state->Get();
   color col = StateColor(s);
   double dd    = m_mon->GetDrawdownPercent();
   double eq    = m_mon->GetEquity();
   double peak  = m_mon->GetPeak();
   double daily = m_mon->GetDailyLossPercent();

   bool newTrades;
   if(m_enf != NULL)
      newTrades = m_enf->IsTradeAllowed(s, PositionsTotal());
   else
      newTrades = true;

   int cd = 0;
   if(m_cd != NULL)
      cd = m_cd->GetLockdownRem();
   string cdStr = "NONE";
   if(cd > 0)
      cdStr = StringFormat("%02d:%02d", cd / 60, cd % 60);

   int y = m_y;
   Label("head", "===============================", m_x, y, clrLightGray, 8);
   y += VIS_LINE_HEIGHT;
   Label("st",   "STATE : " + CGovernanceStateEngine::ToString(s), m_x, y, col, 10);
   y += VIS_LINE_HEIGHT;
   Label("dd",   "DD    : " + DoubleToString(dd, 2) + "%", m_x, y, clrWhite, 9);
   y += VIS_LINE_HEIGHT;
   Label("eq",   "Equity: " + DoubleToString(eq, 2), m_x, y, clrWhite, 9);
   y += VIS_LINE_HEIGHT;
   Label("pk",   "Peak  : " + DoubleToString(peak, 2), m_x, y, clrLightGray, 9);
   y += VIS_LINE_HEIGHT;
   Label("dl",   "DailyL: " + DoubleToString(daily, 2) + "%", m_x, y, (daily > 3) ? clrOrange : clrWhite, 9);
   y += VIS_LINE_HEIGHT;
   Label("tr",   "Trades: " + (newTrades ? "ALLOWED" : "BLOCKED"), m_x, y, newTrades ? clrLightGreen : clrRed, 9);
   y += VIS_LINE_HEIGHT;
   Label("cd",   "Cooldown: " + cdStr, m_x, y, clrYellow, 9);
   y += VIS_LINE_HEIGHT;
   Label("foot", "===============================", m_x, y, clrLightGray, 8);
  }

//+------------------------------------------------------------------+
//| Hides the dashboard and removes all related objects              |
//+------------------------------------------------------------------+
void CVisualizer::Hide()
  {
   ObjectsDeleteAll(0, 0, -1, m_prefix);
  }

//+------------------------------------------------------------------+
//| Demonstration trading engine using SMA crossover logic           |
//+------------------------------------------------------------------+
class CTestTradingEngine
  {
private:
   CTradeAuthorizer       *m_auth;
   CRestrictionEnforcer   *m_enf;
   double                 m_lot;
   int                    m_fastHandle;
   int                    m_slowHandle;
   int                    m_trendHandle;
   datetime               m_lastBar;
   bool                   m_indicatorsValid;

   double                 m_slPips;
   double                 m_tpPips;
   double                 m_trailPips;
   bool                   m_useTrendFilter;

   void                   ManageTrailingStop();
public:
                     CTestTradingEngine();
                    ~CTestTradingEngine();
   void                   Init(CTradeAuthorizer *auth, CRestrictionEnforcer *enf, double lot, bool useTrendFilter);
   void                   SetRiskParams(double slPips, double tpPips, double trailPips);
   void                   OnTick();
  };

//+------------------------------------------------------------------+
//| Initializes the demo trading engine                              |
//+------------------------------------------------------------------+
CTestTradingEngine::CTestTradingEngine()
  {
   m_auth            = NULL;
   m_enf             = NULL;
   m_lot             = 0.1;
   m_fastHandle      = INVALID_HANDLE;
   m_slowHandle      = INVALID_HANDLE;
   m_trendHandle     = INVALID_HANDLE;
   m_lastBar         = 0;
   m_indicatorsValid = false;
   m_slPips          = 40.0;
   m_tpPips          = 80.0;
   m_trailPips       = 30.0;
   m_useTrendFilter  = true;
  }

//+------------------------------------------------------------------+
//| Releases indicator handles                                       |
//+------------------------------------------------------------------+
CTestTradingEngine::~CTestTradingEngine()
  {
   if(m_fastHandle != INVALID_HANDLE)
      IndicatorRelease(m_fastHandle);
   if(m_slowHandle != INVALID_HANDLE)
      IndicatorRelease(m_slowHandle);
   if(m_trendHandle != INVALID_HANDLE)
      IndicatorRelease(m_trendHandle);
  }

//+------------------------------------------------------------------+
//| Creates indicators and stores engine references                  |
//+------------------------------------------------------------------+
void CTestTradingEngine::Init(CTradeAuthorizer *auth, CRestrictionEnforcer *enf, double lot, bool useTrendFilter)
  {
   m_auth           = auth;
   m_enf            = enf;
   m_lot            = lot;
   m_useTrendFilter = useTrendFilter;

   m_fastHandle = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
   m_slowHandle = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);
   if(m_useTrendFilter)
      m_trendHandle = iMA(_Symbol, _Period, 200, 0, MODE_SMA, PRICE_CLOSE);
   else
      m_trendHandle = INVALID_HANDLE;

   if(m_fastHandle == INVALID_HANDLE || m_slowHandle == INVALID_HANDLE ||
      (m_useTrendFilter && m_trendHandle == INVALID_HANDLE))
     {
      Print("[GOV] Indicator creation failed. Test engine disabled.");
      m_indicatorsValid = false;
     }
   else
     {
      m_indicatorsValid = true;
     }
  }

//+------------------------------------------------------------------+
//| Sets risk parameters for stop loss, take profit, and trailing    |
//+------------------------------------------------------------------+
void CTestTradingEngine::SetRiskParams(double slPips, double tpPips, double trailPips)
  {
   m_slPips    = slPips;
   m_tpPips    = tpPips;
   m_trailPips = trailPips;
  }

//+------------------------------------------------------------------+
//| Manages trailing stop for the active position                    |
//+------------------------------------------------------------------+
void CTestTradingEngine::ManageTrailingStop()
  {
   if(!PositionSelect(_Symbol))
      return;

   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSl = PositionGetDouble(POSITION_SL);
   double currentTp = PositionGetDouble(POSITION_TP);
   long   posType   = PositionGetInteger(POSITION_TYPE);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double newSl     = 0;

   double trailDist = m_trailPips * point * 10;

   if(posType == POSITION_TYPE_BUY)
     {
      double trailPrice = bid - trailDist;
      if(trailPrice > openPrice && (currentSl == 0 || trailPrice > currentSl + point))
         newSl = trailPrice;
     }
   else
      if(posType == POSITION_TYPE_SELL)
        {
         double trailPrice = ask + trailDist;
         if(trailPrice < openPrice && (currentSl == 0 || trailPrice < currentSl - point))
            newSl = trailPrice;
        }

   if(newSl != 0)
     {
      CTrade trade;
      trade.PositionModify(_Symbol, newSl, currentTp);
     }
  }

//+------------------------------------------------------------------+
//| Executes the SMA crossover trading logic                         |
//+------------------------------------------------------------------+
void CTestTradingEngine::OnTick()
  {
   if(m_auth == NULL || !m_indicatorsValid)
      return;

   ManageTrailingStop();

   datetime bar = iTime(_Symbol, _Period, 0);
   if(bar == m_lastBar)
      return;
   m_lastBar = bar;

   double fast[2], slow[2];
   if(CopyBuffer(m_fastHandle, 0, 1, 2, fast) != 2)
      return;
   if(CopyBuffer(m_slowHandle, 0, 1, 2, slow) != 2)
      return;

   bool trendUp = true, trendDown = false;
   if(m_useTrendFilter)
     {
      double trend[1];
      if(CopyBuffer(m_trendHandle, 0, 0, 1, trend) != 1)
         return;
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;
      trendUp   = (currentPrice > trend[0]);
      trendDown = (currentPrice < trend[0]);
     }

   bool wasAbove = (fast[1] > slow[1]);
   bool nowAbove = (fast[0] > slow[0]);
   int  signal   = 0;

   if(!wasAbove && nowAbove && trendUp)
      signal = 1;
   else
      if(wasAbove && !nowAbove && trendDown)
         signal = -1;
   if(signal == 0)
      return;

   string reason;
   int positions = PositionsTotal();
   ENUM_AUTH_RESULT ar = m_auth->Authorize(m_lot, reason, positions);
   if(ar != AUTH_GRANTED)
     {
      Print("[GOV] Trade blocked: ", reason);
      return;
     }

   double mult    = m_auth->GetLotMultiplier();
   double rawLot  = m_lot * mult;
   if(rawLot <= 0)
      return;

   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double finalLot = MathFloor(rawLot / lotStep) * lotStep;
   finalLot = MathMax(minLot, MathMin(maxLot, finalLot));
   if(finalLot <= 0)
      return;

   int orderType = (signal > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price  = (orderType == ORDER_TYPE_BUY)
                   ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDist  = m_slPips * point * 10;
   double tpDist  = m_tpPips * point * 10;
   double sl = 0, tp = 0;

   if(orderType == ORDER_TYPE_BUY)
     {
      sl = price - slDist;
      tp = price + tpDist;
     }
   else
     {
      sl = price + slDist;
      tp = price - tpDist;
     }

   long fillFlags = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   ENUM_ORDER_TYPE_FILLING fill = ORDER_FILLING_RETURN;
   if((fillFlags & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      fill = ORDER_FILLING_FOK;
   else
      if((fillFlags & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
         fill = ORDER_FILLING_IOC;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = _Symbol;
   req.volume       = finalLot;
   req.type         = (ENUM_ORDER_TYPE)orderType;
   req.price        = price;
   req.sl           = sl;
   req.tp           = tp;
   req.deviation    = 10;
   req.type_filling = fill;

   if(OrderSend(req, res))
     {
      if(m_enf != NULL)
         m_enf->RecordTrade();
     }
   else
     {
      Print("[GOV] Order failed: retcode=", res.retcode, " comment=", res.comment);
     }
  }
//+------------------------------------------------------------------+