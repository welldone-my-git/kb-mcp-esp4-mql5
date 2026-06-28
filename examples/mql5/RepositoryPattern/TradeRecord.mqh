//+------------------------------------------------------------------+
//|                                                  TradeRecord.mqh |
//| STradeRecord: canonical trade record struct shared across all    |
//| repository implementations and analytics consumers.              |
//+------------------------------------------------------------------+
#ifndef TRADERECORD_MQH
#define TRADERECORD_MQH

//+------------------------------------------------------------------+
//| STradeRecord                                                     |
//| Purpose: Core data structure representing a finalized trade deal |
//+------------------------------------------------------------------+
struct STradeRecord
  {
   ulong             ticket;        // Deal or order ticket identifier
   datetime          open_time;     // Trade open timestamp
   datetime          close_time;    // Trade close timestamp
   double            open_price;    // Entry price
   double            close_price;   // Exit price
   double            volume;        // Executed volume in lots
   double            profit;        // Net profit including swap and commission
   double            commission;    // Commission charged by broker
   double            swap;          // Swap charged or credited
   string            symbol;        // Trading instrument symbol
   int               direction;     // 1 = long, -1 = short
   string            comment;       // Order or deal comment

   //--- Constructor initializing all fields safely to default clear states
                     STradeRecord(void)
      :              ticket(0),
         open_time(0),
         close_time(0),
         open_price(0.0),
         close_price(0.0),
         volume(0.0),
         profit(0.0),
         commission(0.0),
         swap(0.0),
         symbol(""),
         direction(0),
         comment("")
     {
      //--- Empty structural body
     }
  };

#endif // TRADERECORD_MQH
//+------------------------------------------------------------------+