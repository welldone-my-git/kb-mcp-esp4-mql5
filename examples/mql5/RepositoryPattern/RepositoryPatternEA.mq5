//+------------------------------------------------------------------+
//|                                        RepositoryPatternEA.mq5   |
//| Demonstration EA: switches between live and mock repositories,   |
//| executes the same analytics code through both, prints matching   |
//| outputs, renders an equity curve from mock data in OnInit(),     |
//| and performs deterministic cleanup in OnDeinit().                |
//|                                                                  |
//| Requires:                                                        |
//|   TradeRecord.mqh                                                |
//|   ITradeRepository.mqh                                           |
//|   LiveTradeRepository.mqh                                        |
//|   MockTradeRepository.mqh                                        |
//|   AnalyticsEngine.mqh                                            |
//|   EquityCurvePanel.mqh                                           |
//+------------------------------------------------------------------+
#property strict

#include <Repository_Pattern/LiveTradeRepository.mqh>
#include <Repository_Pattern/MockTradeRepository.mqh>
#include <Repository_Pattern/AnalyticsEngine.mqh>
#include <Repository_Pattern/EquityCurvePanel.mqh>

//--- Input parameters
input group   "== Repository Configuration =="
input bool    inp_use_mock_repository    = false; // Use Mock Repository Instead of Live History
input int     inp_history_days           = 30;    // Live History Lookback Period (Days)
input ulong   inp_magic_filter           = 0;     // Magic Number Filter (0 = All Trades)

input group   "== Analytics Configuration =="
input bool    inp_enable_repository_logs = true;  // Enable Repository Diagnostics
input bool    inp_run_both_repositories  = true;  // Run Analytics on Both Repositories

input group   "== Dashboard Configuration =="
input int     inp_panel_x                = 10;    // Equity Curve Panel X Position (Pixels)
input int     inp_panel_y                = 30;    // Equity Curve Panel Y Position (Pixels)
input int     inp_panel_width            = 620;   // Equity Curve Panel Width (Pixels)
input int     inp_panel_height           = 240;   // Equity Curve Panel Height (Pixels)

//--- Global instances
ITradeRepository     *g_repository  = NULL;
CLiveTradeRepository *g_live_repo   = NULL;
CMockTradeRepository *g_mock_repo   = NULL;
CAnalyticsEngine     *g_analytics   = NULL;
CEquityCurvePanel    *g_panel       = NULL;

//+------------------------------------------------------------------+
//| RunAndPrintAnalytics                                             |
//| Purpose: Helper to execute analytics execution pass and broadcast|
//|          results to terminal logger streams.                     |
//+------------------------------------------------------------------+
void RunAndPrintAnalytics(ITradeRepository *repo, datetime analysis_date)
  {
   if(repo == NULL)
     {
      return;
     }

   CAnalyticsEngine engine(repo);
   engine.RunAnalysis(analysis_date);
   engine.PrintReport();
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//| Purpose: Expert initialization function. Allocates repositories, |
//|          runs base benchmarking, and establishes panel views.    |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   datetime now       = TimeCurrent();
   datetime from_date = now - (datetime)(inp_history_days * 86400);

   //--- Construct both repository implementations
   g_live_repo = new CLiveTradeRepository(from_date, now, inp_magic_filter);
   g_mock_repo = new CMockTradeRepository();

   if(CheckPointer(g_live_repo) != POINTER_DYNAMIC || CheckPointer(g_mock_repo) != POINTER_DYNAMIC)
     {
      Print("[RepositoryPatternEA] Failed to allocate repository instances.");
      return(INIT_FAILED);
     }

   //--- Select active repository based on input
   g_repository = inp_use_mock_repository ? (ITradeRepository *)g_mock_repo : (ITradeRepository *)g_live_repo;

   //--- Construct analytics engine bound to active repository
   g_analytics = new CAnalyticsEngine(g_repository);
   if(CheckPointer(g_analytics) != POINTER_DYNAMIC)
     {
      Print("[RepositoryPatternEA] Failed to allocate CAnalyticsEngine.");
      return(INIT_FAILED);
     }

   //--- Run analytics on the active repository
   datetime analysis_date = now - (now % 86400);
   g_analytics.RunAnalysis(analysis_date);

   if(inp_enable_repository_logs)
     {
      g_analytics.PrintReport();
     }

   //--- Optionally run both repositories with identical analytics code
   if(inp_run_both_repositories)
     {
      Print("=== LIVE REPOSITORY RESULTS ===");
      RunAndPrintAnalytics(g_live_repo, analysis_date);

      Print("=== MOCK REPOSITORY RESULTS ===");
      RunAndPrintAnalytics(g_mock_repo, analysis_date);
     }

   //--- Construct and render equity curve panel from mock repository
   //--- This demonstrates that the panel operates without terminal history
   g_panel = new CEquityCurvePanel(0, inp_panel_x, inp_panel_y, inp_panel_width, inp_panel_height);

   if(CheckPointer(g_panel) != POINTER_DYNAMIC)
     {
      Print("[RepositoryPatternEA] Failed to allocate CEquityCurvePanel.");
      return(INIT_FAILED);
     }

   if(!g_panel.Create())
     {
      Print("[RepositoryPatternEA] Failed to create equity curve canvas.");
      return(INIT_FAILED);
     }

   //--- Render equity curve from mock data: no broker connection required
   g_panel.Render(g_mock_repo);

   PrintFormat("[RepositoryPatternEA] Initialized. Active repository: %s | Lookback: %s days | Magic filter: %s",
               g_repository.GetRepositoryType(),
               IntegerToString(inp_history_days),
               (inp_magic_filter == 0) ? "ALL" : IntegerToString((int)inp_magic_filter));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//| Purpose: Expert deinitialization function. Performs orderly state|
//|          cleanup and releases dynamic pointer memory trees.      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Destroy allocated dynamic instances explicitly to prevent leaks
   if(CheckPointer(g_panel) == POINTER_DYNAMIC)
     {
      delete g_panel;
      g_panel = NULL;
     }
   if(CheckPointer(g_analytics) == POINTER_DYNAMIC)
     {
      delete g_analytics;
      g_analytics = NULL;
     }
   if(CheckPointer(g_live_repo) == POINTER_DYNAMIC)
     {
      delete g_live_repo;
      g_live_repo = NULL;
     }
   if(CheckPointer(g_mock_repo) == POINTER_DYNAMIC)
     {
      delete g_mock_repo;
      g_mock_repo = NULL;
     }

   g_repository = NULL;

   PrintFormat("[RepositoryPatternEA] Deinitialized. Reason code: %d.", reason);
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//| Purpose: Expert tick function. Serves as execution entry point   |
//|          for processing real-time quote feeds.                   |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   //--- The EA's trading logic would access repository data here
   //--- through the same ITradeRepository* interface used in OnInit().
   //--- No direct History API calls appear in any trading logic component.
  }
//+------------------------------------------------------------------+