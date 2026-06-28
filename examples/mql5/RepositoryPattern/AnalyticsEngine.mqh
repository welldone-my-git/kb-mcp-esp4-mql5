//+------------------------------------------------------------------+
//|                                              AnalyticsEngine.mqh |
//| CAnalyticsEngine: computes win rate, total profit, average       |
//| trade, and max drawdown exclusively through ITradeRepository*.   |
//| Contains no direct History API calls.                            |
//+------------------------------------------------------------------+
#ifndef ANALYTICSENGINE_MQH
#define ANALYTICSENGINE_MQH

#include "ITradeRepository.mqh"

//+------------------------------------------------------------------+
//| CAnalyticsEngine                                                 |
//| Purpose: Decoupled statistical processing engine evaluating      |
//|          metrics provided by an abstract historical interface.   |
//+------------------------------------------------------------------+
class CAnalyticsEngine
  {
private:
   ITradeRepository *m_repository;   // Non-owned data layer resource pointer

   double            m_win_rate;     // Cached value for last calculated win rate
   double            m_total_profit; // Cached value for last calculated gross net profit
   double            m_avg_trade;    // Cached value for last calculated average payout expectation
   double            m_max_drawdown; // Cached value for last calculated absolute maximum drawdown depth
   double            m_daily_pnl;    // Cached value for last calculated net day profit/loss
   int               m_trade_count;  // Cached value for last calculated closed trade loop count

public:
   //--- Lifecycle Management
                     CAnalyticsEngine(ITradeRepository *repository);
                    ~CAnalyticsEngine(void) {}

   //--- Processing Routines
   void              RunAnalysis(datetime daily_pnl_date);
   void              PrintReport(void);

   //--- State Constant Accessors
   double            GetWinRate(void)     const;
   double            GetTotalProfit(void) const;
   double            GetAvgTrade(void)    const;
   double            GetMaxDrawdown(void) const;
   double            GetDailyPnL(void)    const;
   int               GetTradeCount(void)  const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//| Purpose: Injects database dependency and normalizes state values |
//+------------------------------------------------------------------+
CAnalyticsEngine::CAnalyticsEngine(ITradeRepository *repository)
   : m_repository(repository),
     m_win_rate(0.0),
     m_total_profit(0.0),
     m_avg_trade(0.0),
     m_max_drawdown(0.0),
     m_daily_pnl(0.0),
     m_trade_count(0)
  {
  }

//+------------------------------------------------------------------+
//| RunAnalysis                                                      |
//| Purpose: Polls and caches metric values across the repository    |
//+------------------------------------------------------------------+
void CAnalyticsEngine::RunAnalysis(datetime daily_pnl_date)
  {
   //--- Validate data layer reference to prevent access violations
   if(m_repository == NULL)
     {
      Print("[CAnalyticsEngine] Repository pointer is null. Analysis aborted.");
      return;
     }

   //--- Sequentially pull evaluation parameters safely from abstraction layer
   m_trade_count  = m_repository.GetTradeCount();
   m_win_rate     = m_repository.GetWinRate();
   m_total_profit = m_repository.GetTotalProfit();
   m_avg_trade    = m_repository.GetAverageTrade();
   m_max_drawdown = m_repository.GetMaxDrawdown();
   m_daily_pnl    = m_repository.GetDailyPnL(daily_pnl_date);
  }

//+-------------------------------------------------------------------------+
//| PrintReport                                                             |
//| Purpose: Formats metric results cleanly onto terminal diagnostic output |
//+-------------------------------------------------------------------------+
void CAnalyticsEngine::PrintReport(void)
  {
   //--- Dynamically isolate driver type name signature details
   string repo_type = (m_repository != NULL) ? m_repository.GetRepositoryType() : "UNKNOWN";

   Print("[INFO] Repository Type = " + repo_type);
   Print("[INFO] Running Analytics...");
   Print("");
   Print("Daily PnL    = " + DoubleToString(m_daily_pnl, 2));
   Print("Win Rate     = " + DoubleToString(m_win_rate, 2) + "%");
   Print("Trade Count  = " + IntegerToString(m_trade_count));
   Print("Total Profit = " + DoubleToString(m_total_profit, 2));
   Print("Avg Trade    = " + DoubleToString(m_avg_trade, 2));
   Print("Max Drawdown = " + DoubleToString(m_max_drawdown, 2));
   Print("");
  }

//+------------------------------------------------------------------+
//| GetWinRate                                                       |
//| Purpose: Returns the cached win rate percentage metric           |
//+------------------------------------------------------------------+
double CAnalyticsEngine::GetWinRate(void) const
  {
   return(m_win_rate);
  }

//+------------------------------------------------------------------+
//| GetTotalProfit                                                   |
//| Purpose: Returns the cached historical gross net profit value    |
//+------------------------------------------------------------------+
double CAnalyticsEngine::GetTotalProfit(void) const
  {
   return(m_total_profit);
  }

//+------------------------------------------------------------------+
//| GetAvgTrade                                                      |
//| Purpose: Returns the cached average profit math expectation value|
//+------------------------------------------------------------------+
double CAnalyticsEngine::GetAvgTrade(void) const
  {
   return(m_avg_trade);
  }

//+------------------------------------------------------------------+
//| GetMaxDrawdown                                                   |
//| Purpose: Returns the cached maximum absolute curve drawdown value|
//+------------------------------------------------------------------+
double CAnalyticsEngine::GetMaxDrawdown(void) const
  {
   return(m_max_drawdown);
  }

//+------------------------------------------------------------------+
//| GetDailyPnL                                                      |
//| Purpose: Returns the cached daily profit/loss for analyzed date  |
//+------------------------------------------------------------------+
double CAnalyticsEngine::GetDailyPnL(void) const
  {
   return(m_daily_pnl);
  }

//+------------------------------------------------------------------+
//| GetTradeCount                                                    |
//| Purpose: Returns the cached total qualifying closed trade count  |
//+------------------------------------------------------------------+
int CAnalyticsEngine::GetTradeCount(void) const
  {
   return(m_trade_count);
  }

#endif // ANALYTICSENGINE_MQH
//+------------------------------------------------------------------+