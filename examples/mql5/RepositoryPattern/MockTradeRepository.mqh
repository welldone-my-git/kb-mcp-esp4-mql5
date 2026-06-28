//+------------------------------------------------------------------+
//|                                       MockTradeRepository.mqh    |
//| CMockTradeRepository: implements ITradeRepository via a          |
//| hardcoded in-memory STradeRecord array. Produces deterministic   |
//| results independent of terminal state or broker connection.      |
//+------------------------------------------------------------------+
#ifndef MOCKTRADE_REPOSITORY_MQH
#define MOCKTRADE_REPOSITORY_MQH

#include "ITradeRepository.mqh"

//+------------------------------------------------------------------+
//| CMockTradeRepository                                             |
//| Purpose: Mock database provider serving a static historical deal |
//|          matrix for isolated strategic analysis testing.         |
//+------------------------------------------------------------------+
class CMockTradeRepository : public ITradeRepository
  {
private:
   STradeRecord      m_trades[];     // In-memory trade dataset
   int               m_count;        // Number of records in dataset

   void              BuildDataset(void);

public:
   //--- Lifecycle Management
                     CMockTradeRepository(void);
                    ~CMockTradeRepository(void) {}

   //--- Interface Implementations
   virtual int          GetTradeCount(void);
   virtual STradeRecord GetClosedTrade(int index);
   virtual double       GetDailyPnL(datetime date);
   virtual double       GetWinRate(void);
   virtual double       GetTotalProfit(void);
   virtual double       GetMaxDrawdown(void);
   virtual double       GetAverageTrade(void);
   virtual string       GetRepositoryType(void);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMockTradeRepository::CMockTradeRepository(void) 
   : m_count(0)
  {
   //--- Populate local dataset array upon initialization
   BuildDataset();
  }

//+-------------------------------------------------------------------+
//| BuildDataset                                                      |
//| Purpose: Constructs a fixed 48-trade dataset matching structural  |
//|          sample criteria (Win Rate 60.42%, Count: 48)             |
//+-------------------------------------------------------------------+
void CMockTradeRepository::BuildDataset(void)
  {
   //--- Profit values: 29 winners, 19 losers, net 344.20 on a base day
   double profits[] =
     {
      18.50,  -12.30,  25.70,  -8.90,  31.20,  -15.40,  22.10,  -9.80,
      27.30,   14.60, -11.20,  19.80, -22.50,  35.40,  -13.70,  28.90,
       8.40,  -17.60,  23.50,  16.20, -10.30,  29.70,  -14.80,  21.40,
      12.90,  -19.20,  33.60,   7.80, -11.90,  26.10,  -16.50,  18.70,
      24.30,  -13.10,  30.80,   9.20, -20.40,  22.90,  -8.60,   15.40,
      28.50,  -12.70,  19.30,  -9.40,  34.20,  -17.80,  11.60,  25.90
     };

   string symbols[] =
     {
      "EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "EURUSD", "GBPUSD", "USDJPY",
      "EURUSD", "AUDUSD", "USDCAD", "GBPUSD", "EURUSD", "USDJPY", "AUDUSD", "EURUSD",
      "GBPUSD", "USDCAD", "EURUSD", "USDJPY", "GBPUSD", "EURUSD", "AUDUSD", "USDCAD",
      "USDJPY", "EURUSD", "GBPUSD", "AUDUSD", "USDCAD", "EURUSD", "USDJPY", "GBPUSD",
      "EURUSD", "AUDUSD", "USDCAD", "USDJPY", "EURUSD", "GBPUSD", "AUDUSD", "EURUSD",
      "USDJPY", "USDCAD", "GBPUSD", "EURUSD", "AUDUSD", "USDJPY", "EURUSD", "GBPUSD"
     };

   //--- Configure internal array dimensions
   m_count = ArraySize(profits);
   ArrayResize(m_trades, m_count);

   //--- Base date reference: Midnight of 2024-01-15 
   datetime base_day = D'2024.01.15 00:00';

   //--- Synthesize comprehensive historical metadata loops
   for(int i = 0; i < m_count; i++)
     {
      m_trades[i].ticket      = (ulong)(100001 + i);
      m_trades[i].open_time   = base_day + (i * 600);
      m_trades[i].close_time  = base_day + (i * 600) + 300;
      m_trades[i].open_price  = 1.08000 + (i * 0.00010);
      m_trades[i].close_price = m_trades[i].open_price + (profits[i] > 0 ? 0.00050 : -0.00050);
      m_trades[i].volume      = 0.10;
      m_trades[i].profit      = profits[i];
      m_trades[i].commission  = -0.70;
      m_trades[i].swap        = 0.0;
      m_trades[i].symbol      = symbols[i];
      m_trades[i].direction   = (profits[i] > 0 && i % 2 == 0) ? 1 : -1;
      m_trades[i].comment     = "Mock trade " + IntegerToString(i + 1);
     }
  }

//+------------------------------------------------------------------+
//| GetTradeCount                                                    |
//+------------------------------------------------------------------+
int CMockTradeRepository::GetTradeCount(void)
  {
   return(m_count);
  }

//+------------------------------------------------------------------+
//| GetClosedTrade                                                   |
//+------------------------------------------------------------------+
STradeRecord CMockTradeRepository::GetClosedTrade(int index)
  {
   //--- Validate boundaries to safeguard against array out-of-range errors
   if(index < 0 || index >= m_count)
     {
      STradeRecord empty_record;
      return(empty_record);
     }
     
   return(m_trades[index]);
  }

//+------------------------------------------------------------------+
//| GetDailyPnL                                                      |
//| Purpose: Aggregates complete net payouts matching an exact day   |
//+------------------------------------------------------------------+
double CMockTradeRepository::GetDailyPnL(datetime date)
  {
   //--- Map target timestamp to standard 24-hour Unix time frames
   datetime day_start = date - (date % 86400);
   datetime day_end   = day_start + 86400;
   double   daily_pnl = 0.0;

   //--- Extract matching historical entries
   for(int i = 0; i < m_count; i++)
     {
      if(m_trades[i].close_time >= day_start && m_trades[i].close_time < day_end)
        {
         daily_pnl += m_trades[i].profit + 
                      m_trades[i].commission + 
                      m_trades[i].swap;
        }
     }

   return(daily_pnl);
  }

//+------------------------------------------------------------------+
//| GetWinRate                                                       |
//+------------------------------------------------------------------+
double CMockTradeRepository::GetWinRate(void)
  {
   if(m_count == 0)
     {
      return(0.0);
     }

   int wins = 0;
   for(int i = 0; i < m_count; i++)
     {
      //--- Evaluate trade result net of operational overhead costs
      double net = m_trades[i].profit + 
                   m_trades[i].commission + 
                   m_trades[i].swap;
      if(net > 0.0)
        {
         wins++;
        }
     }

   return((wins / (double)m_count) * 100.0);
  }

//+------------------------------------------------------------------+
//| GetTotalProfit                                                   |
//+------------------------------------------------------------------+
double CMockTradeRepository::GetTotalProfit(void)
  {
   double total = 0.0;
   
   for(int i = 0; i < m_count; i++)
     {
      total += m_trades[i].profit + 
               m_trades[i].commission + 
               m_trades[i].swap;
     }
     
   return(total);
  }

//+------------------------------------------------------------------+
//| GetMaxDrawdown                                                   |
//| Purpose: Processes the continuous data grid to locate the widest |
//|          peak-to-trough drop valley in the cumulative equity path|
//+------------------------------------------------------------------+
double CMockTradeRepository::GetMaxDrawdown(void)
  {
   double equity = 0.0;
   double peak   = 0.0;
   double max_dd = 0.0;

   for(int i = 0; i < m_count; i++)
     {
      equity += m_trades[i].profit + 
                m_trades[i].commission + 
                m_trades[i].swap;

      if(equity > peak)
        {
         peak = equity;
        }
        
      double dd = peak - equity;
      if(dd > max_dd)
        {
         max_dd = dd;
        }
     }

   return(max_dd);
  }

//+------------------------------------------------------------------+
//| GetAverageTrade                                                  |
//+------------------------------------------------------------------+
double CMockTradeRepository::GetAverageTrade(void)
  {
   if(m_count == 0)
     {
      return(0.0);
     }
     
   return(GetTotalProfit() / m_count);
  }

//+------------------------------------------------------------------+
//| GetRepositoryType                                                |
//+------------------------------------------------------------------+
string CMockTradeRepository::GetRepositoryType(void)
  {
   return("MOCK");
  }

#endif // MOCKTRADE_REPOSITORY_MQH
//+------------------------------------------------------------------+