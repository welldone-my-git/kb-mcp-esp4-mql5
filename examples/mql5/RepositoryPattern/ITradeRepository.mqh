//+------------------------------------------------------------------+
//|                                           ITradeRepository.mqh |
//| Abstract repository contract. All analytics consumers depend     |
//| exclusively on this interface, never on concrete                 |
//| implementations or the History API directly.                    |
//+------------------------------------------------------------------+
#ifndef ITRADE_REPOSITORY_MQH
#define ITRADE_REPOSITORY_MQH

#include "TradeRecord.mqh"

//+------------------------------------------------------------------+
//| ITradeRepository                                                 |
//| Purpose: Interface defining data access contracts for historical |
//|          and transactional trade tracking operations.            |
//+------------------------------------------------------------------+
class ITradeRepository
  {
public:
   //--- Interface methods for record retrieval and counting
   virtual int          GetTradeCount(void) = 0;
   virtual STradeRecord GetClosedTrade(int index) = 0;

   //--- Interface methods for metric calculations and diagnostic evaluation
   virtual double       GetDailyPnL(datetime date) = 0;
   virtual double       GetWinRate(void) = 0;
   virtual double       GetTotalProfit(void) = 0;
   virtual double       GetMaxDrawdown(void) = 0;
   virtual double       GetAverageTrade(void) = 0;

   //--- Interface metadata identity and memory lifecycle management
   virtual string       GetRepositoryType(void) = 0;
   virtual             ~ITradeRepository(void) {}
  };

#endif // ITRADE_REPOSITORY_MQH
//+------------------------------------------------------------------+