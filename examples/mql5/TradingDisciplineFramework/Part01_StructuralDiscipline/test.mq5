//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property strict
#property description "Demo: Enforces max trades/day, profit target, loss limit with actual blocking"

// ------------------------- INPUTS ---------------------------------
input int    MaxTradesPerDay    = 5;          // Maximum trades per day
input double DailyProfitTarget  = 2.0;        // Profit target in % (e.g. 2.0 = +2%)
input double MaxDailyLoss       = 3.0;        // Max loss in % (e.g. 3.0 = -3%)

// ------------------------- VARIABLES -------------------------------
int      tradesToday     = 0;
datetime dayStartTime    = 0;
double   dayStartEquity  = 0.0;
double   dayStartBalance = 0.0;
bool     profitLimitHit  = false;
bool     lossLimitHit    = false;
bool     tradeBlocked    = false;             // Global block flag (set when any limit hit)

//-------------------------------------------------------------------
// Reset all daily tracking variables
//-------------------------------------------------------------------
void ResetDailyState()
  {
   tradesToday     = 0;
   dayStartTime    = iTime(_Symbol, PERIOD_D1, 0);
   dayStartEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   profitLimitHit  = false;
   lossLimitHit    = false;
   tradeBlocked    = false;
  }

//-------------------------------------------------------------------
// Initialization
//-------------------------------------------------------------------
int OnInit()
  {
   ResetDailyState();
   Print("Discipline Demo initialized. Limits: ", MaxTradesPerDay, " trades/day | +", DailyProfitTarget, "% profit | -", MaxDailyLoss, "% loss");
   return(INIT_SUCCEEDED);
  }

//-------------------------------------------------------------------
// Check profit limit (called periodically or after trades)
//-------------------------------------------------------------------
void CheckProfitLimit()
  {
   if(profitLimitHit)
      return;

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double gainPercent   = ((currentEquity - dayStartEquity) / dayStartEquity) * 100.0;

   if(gainPercent >= DailyProfitTarget)
     {
      profitLimitHit = true;
      tradeBlocked   = true;
      Alert("Daily profit target reached (" + DoubleToString(gainPercent,2) + "%) → trading blocked");
      Print("Profit limit hit → all further trades blocked");
     }
  }

//-------------------------------------------------------------------
// Check loss limit
//-------------------------------------------------------------------
void CheckLossLimit()
  {
   if(lossLimitHit)
      return;

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double lossPercent   = ((dayStartBalance - currentEquity) / dayStartBalance) * 100.0;

   if(lossPercent >= MaxDailyLoss)
     {
      lossLimitHit   = true;
      tradeBlocked   = true;
      Alert("Daily loss limit breached (" + DoubleToString(lossPercent,2) + "%) → trading blocked");
      Print("Loss limit hit → all further trades blocked");
     }
  }

//-------------------------------------------------------------------
// Update trade counter & check limits on every deal
//-------------------------------------------------------------------
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != dayStartTime)
      ResetDailyState();

   if(HistoryDealSelect(trans.deal))
     {
      long entryType = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      if(entryType == DEAL_ENTRY_IN)
        {
         tradesToday++;
         Print("Trade #" + IntegerToString(tradesToday) + " executed today");
        }
     }

// Check all limits after every trade
   if(tradesToday >= MaxTradesPerDay)
     {
      tradeBlocked = true;
      Alert("Daily trade limit reached (" + IntegerToString(tradesToday) + "/" + IntegerToString(MaxTradesPerDay) + ") → trading blocked");
      Print("Trade frequency limit hit → all further trades blocked");
     }

   CheckProfitLimit();
   CheckLossLimit();
  }

//-------------------------------------------------------------------
// CENTRAL ENFORCEMENT GATEWAY – call this instead of OrderSend()
//-------------------------------------------------------------------
bool TryOpenOrder(MqlTradeRequest &req, MqlTradeResult &res)
  {
// Check global block flag first
   if(tradeBlocked)
     {
      Print("Trade blocked by discipline rules: ",
            profitLimitHit  ? "Profit target reached" :
            lossLimitHit    ? "Loss limit breached" :
            "Trade frequency exceeded");
      return false;
     }

// Optional: extra safety – re-check equity-based limits right before send
   CheckProfitLimit();
   CheckLossLimit();
   if(tradeBlocked)
      return false;

// Actually send the trade
   if(!OrderSend(req, res))
     {
      Print("OrderSend failed: ", res.retcode, " - ", res.comment);
      return false;
     }

   Print("Trade sent successfully → ticket #", res.order);
   return true;
  }

//-------------------------------------------------------------------
// Demo: Simulate trade attempts (for Strategy Tester / visual mode only)
// Remove or comment out in real EAs – replace with your signal logic
//-------------------------------------------------------------------
void OnTick()
  {
// Safety throttle: only attempt every ~10–30 seconds in tester
   static datetime lastAttempt = 0;
   if(TimeCurrent() - lastAttempt < 10)
      return;
   lastAttempt = TimeCurrent();

// Example: try to open a small buy (demo only)
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action   = TRADE_ACTION_DEAL;
   req.symbol   = _Symbol;
   req.volume   = 0.01;               // micro lot for safety
   req.type     = ORDER_TYPE_BUY;
   req.price    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   req.sl       = 0;                  // add your SL/TP in real use
   req.tp       = 0;
   req.magic    = 987654;
   req.comment  = "Discipline Demo";

   if(TryOpenOrder(req, res))
      Print("Demo trade attempt succeeded");
   else
      Print("Demo trade attempt blocked by rules");
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
