//+------------------------------------------------------------------+
//|                                       LiveTradeRepository.mqh    |
//| CLiveTradeRepository: implements ITradeRepository using the      |
//| MetaTrader 5 History API. Queries HistorySelect() on each        |
//| method call to reflect current terminal trade history state.     |
//+------------------------------------------------------------------+
#ifndef LIVETRADE_REPOSITORY_MQH
#define LIVETRADE_REPOSITORY_MQH

#include "ITradeRepository.mqh"

//+------------------------------------------------------------------+
//| CLiveTradeRepository                                             |
//| Purpose: Active trading terminal history engine adapter tracking |
//|          deal entries, commissions, and metrics dynamically.     |
//+------------------------------------------------------------------+
class CLiveTradeRepository : public ITradeRepository
  {
private:
   datetime          m_from_date;    // History query start date boundary
   datetime          m_to_date;      // History query end date boundary
   ulong             m_magic;        // Filter: only include deals with this magic number (0 = all)

   //--- Internal utility validation rules
   bool              SelectHistory(void);
   bool              IsEntryDeal(ulong ticket);

public:
   //--- Lifecycle management
                     CLiveTradeRepository(datetime from_date, datetime to_date, ulong magic);
                    ~CLiveTradeRepository(void) {}

   //--- Overridden calculation and data access methods
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
//| Purpose: Initializes the history adapter context boundaries      |
//+------------------------------------------------------------------+
CLiveTradeRepository::CLiveTradeRepository(datetime from_date,
      datetime to_date,
      ulong magic)
   : m_from_date(from_date),
     m_to_date(to_date),
     m_magic(magic)
  {
  }

//+------------------------------------------------------------------+
//| SelectHistory                                                    |
//| Purpose: Populates the terminal cache with system deal records   |
//|          within the specified global timeline window             |
//+------------------------------------------------------------------+
bool CLiveTradeRepository::SelectHistory(void)
  {
//--- Request system logs from MT5 local terminal database
   return(HistorySelect(m_from_date, m_to_date));
  }

//+------------------------------------------------------------------+
//| IsEntryDeal                                                      |
//| Purpose: Discerns whether a historical deal record represents an |
//|          outward execution path that completes a trade loop      |
//+------------------------------------------------------------------+
bool CLiveTradeRepository::IsEntryDeal(ulong ticket)
  {
//--- Retrieve structural transaction tracking type identifier
   long deal_entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);

//--- DEAL_ENTRY_OUT (Close), DEAL_ENTRY_INOUT (Reversal) indicate trade completion
   return(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT);
  }

//+------------------------------------------------------------------+
//| GetTradeCount                                                    |
//| Purpose: Evaluates total number of qualifying closed loop deals  |
//+------------------------------------------------------------------+
int CLiveTradeRepository::GetTradeCount(void)
  {
//--- Synchronize cache storage lists
   if(!SelectHistory())
     {
      return(0);
     }

   int count = 0;
   int total = HistoryDealsTotal();

//--- Loop through the selection index to parse metadata matches
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
        {
         continue;
        }

      //--- Validate magic number ownership constraints if required
      if(m_magic > 0 && (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic)
        {
         continue;
        }

      //--- Filter non-closing transaction fragments
      if(!IsEntryDeal(ticket))
        {
         continue;
        }
      count++;
     }

   return(count);
  }

//+------------------------------------------------------------------+
//| GetClosedTrade                                                   |
//| Purpose: Hydrates and builds a canonical structural trade model  |
//|          matching a virtual tracking positional index reference  |
//+------------------------------------------------------------------+
STradeRecord CLiveTradeRepository::GetClosedTrade(int index)
  {
   STradeRecord record;

//--- Check active collection environment state
   if(!SelectHistory())
     {
      return(record);
     }

   int total     = HistoryDealsTotal();
   int match_idx = 0;

//--- Traverse target tracking database
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
        {
         continue;
        }
      if(m_magic > 0 && (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic)
        {
         continue;
        }
      if(!IsEntryDeal(ticket))
        {
         continue;
        }

      //--- Extract and copy target values upon index verification match
      if(match_idx == index)
        {
         record.ticket      = ticket;
         record.close_time  = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         record.close_price = HistoryDealGetDouble(ticket, DEAL_PRICE);
         record.volume      = HistoryDealGetDouble(ticket, DEAL_VOLUME);
         record.profit      = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         record.commission  = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         record.swap        = HistoryDealGetDouble(ticket, DEAL_SWAP);
         record.symbol      = HistoryDealGetString(ticket, DEAL_SYMBOL);
         record.comment     = HistoryDealGetString(ticket, DEAL_COMMENT);

         //--- Map system enum layouts to direction standards (1=Long, -1=Short)
         long deal_type   = HistoryDealGetInteger(ticket, DEAL_TYPE);
         record.direction = (deal_type == DEAL_TYPE_SELL) ? 1 : -1;
         return(record);
        }

      match_idx++;
     }

   return(record);
  }

//+------------------------------------------------------------------+
//| GetDailyPnL                                                      |
//| Purpose: Computes total net yields generated within a given day  |
//+------------------------------------------------------------------+
double CLiveTradeRepository::GetDailyPnL(datetime date)
  {
   if(!SelectHistory())
     {
      return(0.0);
     }

//--- Normalize query timestamp boundaries into a strict 24-hour Unix frame
   datetime day_start = date - (date % 86400);
   datetime day_end   = day_start + 86400;
   double   daily_pnl = 0.0;
   int      total     = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
        {
         continue;
        }
      if(m_magic > 0 && (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic)
        {
         continue;
        }
      if(!IsEntryDeal(ticket))
        {
         continue;
        }

      //--- Sum profit components if structural event time falls inside bounds
      datetime close_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(close_time >= day_start && close_time < day_end)
        {
         daily_pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         daily_pnl += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         daily_pnl += HistoryDealGetDouble(ticket, DEAL_SWAP);
        }
     }

   return(daily_pnl);
  }

//+------------------------------------------------------------------+
//| GetWinRate                                                       |
//| Purpose: Calculates percentage ratio of net profitable trades    |
//+------------------------------------------------------------------+
double CLiveTradeRepository::GetWinRate(void)
  {
   if(!SelectHistory())
     {
      return(0.0);
     }

   int total = HistoryDealsTotal();
   int wins  = 0;
   int count = 0;

   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
        {
         continue;
        }
      if(m_magic > 0 && (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic)
        {
         continue;
        }
      if(!IsEntryDeal(ticket))
        {
         continue;
        }

      //--- Calculate complete returns by factoring charges and adjustments
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP);
      if(profit > 0.0)
        {
         wins++;
        }
      count++;
     }

//--- Protect against division by zero errors
   if(count == 0)
     {
      return(0.0);
     }
   return((wins / (double)count) * 100.0);
  }

//+------------------------------------------------------------------+
//| GetTotalProfit                                                   |
//| Purpose: Accumulates overall lifetime transaction metrics        |
//+------------------------------------------------------------------+
double CLiveTradeRepository::GetTotalProfit(void)
  {
   if(!SelectHistory())
     {
      return(0.0);
     }

   int    total  = HistoryDealsTotal();
   double result = 0.0;

   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
        {
         continue;
        }
      if(m_magic > 0 && (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic)
        {
         continue;
        }
      if(!IsEntryDeal(ticket))
        {
         continue;
        }

      //--- Continuously increment master balances with comprehensive tracking values
      result += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      result += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      result += HistoryDealGetDouble(ticket, DEAL_SWAP);
     }

   return(result);
  }

//+------------------------------------------------------------------+
//| GetMaxDrawdown                                                   |
//| Purpose: Tracks systemic structural peak reductions to measure   |
//|          maximum depth relative to history curves                |
//+------------------------------------------------------------------+
double CLiveTradeRepository::GetMaxDrawdown(void)
  {
   if(!SelectHistory())
     {
      return(0.0);
     }

   int    total  = HistoryDealsTotal();
   double equity = 0.0;
   double peak   = 0.0;
   double max_dd = 0.0;

   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
        {
         continue;
        }
      if(m_magic > 0 && (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic)
        {
         continue;
        }
      if(!IsEntryDeal(ticket))
        {
         continue;
        }

      //--- Calculate current incremental closed balance level points
      equity += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                HistoryDealGetDouble(ticket, DEAL_SWAP);

      //--- Update maximum running curve historical peak metrics
      if(equity > peak)
        {
         peak = equity;
        }

      //--- Evaluate distance drops between peak caps and raw floors
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
//| Purpose: Determines statistical math expectation value levels     |
//+------------------------------------------------------------------+
double CLiveTradeRepository::GetAverageTrade(void)
  {
   int count = GetTradeCount();
   if(count == 0)
     {
      return(0.0);
     }

//--- Mathematical mean logic processing standard returns
   return(GetTotalProfit() / count);
  }

//+------------------------------------------------------------------+
//| GetRepositoryType                                                |
//| Purpose: Explicit indicator identifying implementation lineage   |
//+------------------------------------------------------------------+
string CLiveTradeRepository::GetRepositoryType(void)
  {
   return("LIVE");
  }

#endif // LIVETRADE_REPOSITORY_MQH
//+------------------------------------------------------------------+