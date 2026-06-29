//+------------------------------------------------------------------+
//|                                               EquityGovernor.mq5 |
//|                              Copyright 2026, Christian Benjamin. |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

#include <GOVERNOR/EquityGovernor_Classes.mqh>

// ---- Master ON/OFF switch
input bool   InpEnableGoverning = true;    // true = Governor active, false = always NORMAL

// ---- Realistic governor thresholds
input double InpDD_NormalMax    = 2.0;     // 2% drawdown triggers CAUTION
input double InpDD_CautionMax   = 5.0;     // 5% drawdown triggers RESTRICTED
input double InpDD_RestrictedMax = 7.0;    // 7% drawdown triggers LOCKDOWN
input int    InpLockdownSec     = 300;     // seconds to stay in LOCKDOWN
input int    InpRestrictedSec   = 180;     // seconds before downgrade from RESTRICTED
input double InpRecoveryThr     = 0.99;    // equity must recover to 99% of peak to downgrade
input double InpCautionLotMult  = 0.5;     // lot multiplier when CAUTION
input int    InpCautionMaxPos   = 1;       // max positions allowed in CAUTION
input int    InpCautionMinSec   = 60;      // min seconds between trades in CAUTION
input double InpMaxDDLimit      = 10.0;    // hard DD limit (blocks all trades)
input double InpMaxDailyLoss    = 5.0;     // hard daily loss limit (blocks all trades)
input double InpTestLot         = 0.1;     // base lot size (normal mode)
input bool   InpEnableTest      = true;
input bool   InpEnableLog       = true;
input bool   InpEnableDash      = false;

// ---- Stress‑Test Mode
input bool   InpStressMode      = false;

// ---- Exit parameters
input double InpSLPips    = 40.0;
input double InpTPPips    = 80.0;
input double InpTrailPips = 30.0;
input int    InpTimerSeconds = 5;

CEquityMonitor         g_Mon;
CDrawdownAnalyzer      g_Anal;
CRecoveryCooldown      g_Cooldown;
CGovernanceStateEngine g_State;
CRestrictionEnforcer   g_Enforcer;
CTradeAuthorizer       g_Auth;
CEventLogger           g_Log;
CVisualizer            g_Vis;
CTestTradingEngine     g_Test;

//+------------------------------------------------------------------+
//| UpdateGovernor                                                   |
//+------------------------------------------------------------------+
void UpdateGovernor()
  {
   double dd = g_Mon.GetDrawdownPercent();
   ENUM_DD_PRESSURE pressure = g_Anal.GetPressure(dd);
   bool rapid = g_Anal.IsRapidCollapse(g_Mon);
   ENUM_GOV_STATE old = g_State.Get();
   g_State.Update(pressure, rapid);
   if(old != g_State.Get() && InpEnableLog)
      g_Log.LogStateChange(old, g_State.Get(), dd);
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_Mon.Init();

// ---Set thresholds to 100% if governing is disabled (never triggers)
   double normalMax    = InpEnableGoverning ? InpDD_NormalMax    : 100.0;
   double cautionMax   = InpEnableGoverning ? InpDD_CautionMax   : 100.0;
   double restrictedMax= InpEnableGoverning ? InpDD_RestrictedMax: 100.0;
   double maxDD        = InpEnableGoverning ? InpMaxDDLimit      : 100.0;
   double maxDaily     = InpEnableGoverning ? InpMaxDailyLoss    : 100.0;

   g_Anal.SetThresholds(normalMax, cautionMax, restrictedMax);
   g_Cooldown.Init(&g_Mon);
   g_Cooldown.SetParams(InpLockdownSec, InpRestrictedSec, InpRecoveryThr);
   g_State.Init(&g_Cooldown);
   g_Enforcer.SetParams(InpCautionLotMult, InpCautionMaxPos, InpCautionMinSec);
   g_Auth.Init(&g_State, &g_Enforcer, &g_Mon);
   g_Auth.SetLimits(maxDD, maxDaily);

   if(InpEnableLog)
      g_Log.SetToExperts(true);
   string mode = InpEnableGoverning ? "GOVERNING ACTIVE" : "GOVERNING DISABLED";
   if(InpStressMode)
      mode += " (STRESS MODE)";
   g_Log.Log("Equity Governor v1.0 – " + mode);

   if(InpEnableDash)
     {
      g_Vis.Init(&g_State, &g_Mon, &g_Cooldown, &g_Enforcer);
      g_Vis.SetPos(CORNER_LEFT_UPPER, 10, 30);
     }

   if(InpEnableTest)
     {
      double lot = InpStressMode ? 0.5 : InpTestLot;
      bool useTrend = !InpStressMode;
      g_Test.Init(&g_Auth, &g_Enforcer, lot, useTrend);
      g_Test.SetRiskParams(InpSLPips, InpTPPips, InpTrailPips);
      g_Log.Log("Test engine: lot=" + DoubleToString(lot,2) +
                ", trend filter=" + (useTrend ? "ON" : "OFF"));
     }

   EventSetTimer(InpTimerSeconds);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_Log.Log("Stopped");
   g_Vis.Hide();
   Comment("");
  }

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(InpEnableDash)
     {
      g_Mon.Update();
      UpdateGovernor();
      g_Vis.Refresh();
     }
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_Mon.Update();
   if(InpEnableGoverning)
      UpdateGovernor();

   if(InpEnableTest)
      g_Test.OnTick();

   if(!InpEnableDash)
     {
      Comment(StringFormat("Gov: %s | DD: %.2f%% | Eq: %.2f",
                           CGovernanceStateEngine::ToString(g_State.Get()),
                           g_Mon.GetDrawdownPercent(),
                           g_Mon.GetEquity()));
     }
   else
      Comment("");
  }
//+------------------------------------------------------------------+