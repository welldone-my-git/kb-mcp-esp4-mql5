//+------------------------------------------------------------------+
//|                                                  EquityProtector |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum ENUM_MODE
  {
   MODE_PASSIVE,  // Only observe, no modifications
   MODE_ASSISTED, // Alert before modifying
   MODE_STRICT    // Auto-modify without alert
  };

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input double     InpRiskPercent  = 1.0;        // Risk % of equity
input double     InpRRatio       = 3.0;        // Risk-to-Reward ratio
input int        InpTimerSeconds = 1;          // Scan interval in seconds
input ENUM_MODE  InpDefaultMode  = MODE_STRICT;// Default mode

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
ENUM_MODE g_Mode;
double    g_RiskPercent;
double    g_RRatio;
string    g_Prefix = "Discipline_";

//--- UI object names
string g_BtnPassive  = g_Prefix + "BtnPassive";
string g_BtnAssisted = g_Prefix + "BtnAssisted";
string g_BtnStrict   = g_Prefix + "BtnStrict";
string g_BtnRiskUp   = g_Prefix + "BtnRiskUp";
string g_BtnRiskDown = g_Prefix + "BtnRiskDown";
string g_BtnRRUp     = g_Prefix + "BtnRRUp";
string g_BtnRRDown   = g_Prefix + "BtnRRDown";
string g_LblMode     = g_Prefix + "LblMode";
string g_LblRisk     = g_Prefix + "LblRisk";
string g_LblRR       = g_Prefix + "LblRR";
string g_LblEquity   = g_Prefix + "LblEquity";
string g_LblScore    = g_Prefix + "LblScore";
string g_LblLastAct  = g_Prefix + "LblLastAct";
string g_Rectangle   = g_Prefix + "Rectangle";

//--- Statistics
int g_TotalTradesChecked = 0;
int g_ViolationsCorrected = 0;

//--- UI constants
const int   PANEL_X        = 10;
const int   PANEL_Y        = 40;
const int   PANEL_W        = 280;
const int   PANEL_H        = 150;
const int   BUTTON_WIDTH   = 60;
const int   BUTTON_HEIGHT  = 20;
const int   SMALL_BTN_W    = 20;
const int   ROW_STEP       = 22;
const color BG_COLOR       = C'240,240,240';
const color ACTIVE_COLOR   = clrDodgerBlue;
const color INACTIVE_COLOR = clrGray;

//+------------------------------------------------------------------+
//| Utility: normalize volume by step                                |
//+------------------------------------------------------------------+
double NormalizeVolumeByStep(const string symbol,double volume)
  {
   double step   = SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);

   if(step <= 0.0)
      step = 0.01;

   volume = MathMax(minLot,MathMin(maxLot,volume));
   volume = MathRound(volume/step)*step;

   return NormalizeDouble(volume,2);
  }

//+------------------------------------------------------------------+
//| Utility: normalize price by symbol digits                        |
//+------------------------------------------------------------------+
double NormalizePriceBySymbol(const string symbol,double price)
  {
   int digits = (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   return NormalizeDouble(price,digits);
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate timer
   if(InpTimerSeconds < 1)
     {
      Print("ERROR: InpTimerSeconds must be >= 1. Using 1.");
      EventSetTimer(1);
     }
   else
      EventSetTimer(InpTimerSeconds);

//--- Copy inputs to globals
   g_Mode        = InpDefaultMode;
   g_RiskPercent = InpRiskPercent;
   g_RRatio      = InpRRatio;

//--- Create panel
   DeletePanel();
   CreatePanel();
   UpdatePanel();

   Print("Discipline Engine started. Mode=",EnumToString(g_Mode),
         ", Risk=",DoubleToString(g_RiskPercent,2),"%, R:R=",DoubleToString(g_RRatio,2));

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeletePanel();
   DeleteAllLines();
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   ulong activeTickets[];
   ArrayResize(activeTickets,0);

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      string             symbol    = PositionGetString(POSITION_SYMBOL);
      double             lot       = PositionGetDouble(POSITION_VOLUME);
      double             openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double             sl        = PositionGetDouble(POSITION_SL);
      double             tp        = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE type      = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      //--- Add to active tickets
      int idx = ArraySize(activeTickets);
      ArrayResize(activeTickets,idx+1);
      activeTickets[idx] = ticket;

      double requiredSLDist = CalculateRequiredSLDistance(symbol,lot,g_RiskPercent);
      if(requiredSLDist <= 0.0)
        {
         Print("Warning: cannot calculate risk for ",symbol," ticket ",ticket);
         continue;
        }

      if(g_Mode != MODE_PASSIVE)
         AdjustLotSize(ticket,symbol,type,lot,openPrice,requiredSLDist);

      //--- Re-read position data after potential lot adjustment
      if(PositionSelectByTicket(ticket))
        {
         lot = PositionGetDouble(POSITION_VOLUME);
         sl  = PositionGetDouble(POSITION_SL);
         tp  = PositionGetDouble(POSITION_TP);
        }

      //--- Compliance check
      bool   isCompliant  = true;
      string violationMsg = "";

      if(sl == 0.0)
        {
         isCompliant = false;
         violationMsg = "Missing SL";
        }
      else
         if(tp == 0.0)
           {
            isCompliant = false;
            violationMsg = "Missing TP";
           }
         else
           {
            double currentSLDist = MathAbs(openPrice-sl);
            double point         = SymbolInfoDouble(symbol,SYMBOL_POINT);

            if(MathAbs(currentSLDist-requiredSLDist) > point*0.5)
              {
               isCompliant = false;
               violationMsg = StringFormat("Risk mismatch: current=%.5f required=%.5f",
                                           currentSLDist,requiredSLDist);
              }
           }

      g_TotalTradesChecked++;

      if(!isCompliant)
        {
         Print("Violation on ticket ",ticket,": ",violationMsg);

         if(g_Mode != MODE_PASSIVE)
           {
            if(EnforceSLTP(ticket,symbol,type,lot,openPrice,requiredSLDist,g_RRatio))
              {
               g_ViolationsCorrected++;

               if(g_Mode == MODE_ASSISTED)
                 {
                  Alert(StringFormat("Trade %I64u: %s. Corrected.",ticket,violationMsg));
                  LogAction(ticket,violationMsg+" corrected (assisted)");
                 }
               else
                  if(g_Mode == MODE_STRICT)
                     LogAction(ticket,violationMsg+" corrected (strict)");
              }
            else
               LogAction(ticket,violationMsg+" correction failed");
           }
         else
            LogAction(ticket,violationMsg+" (passive, no action)");
        }

      //--- Draw SL/TP lines for current chart symbol
      if(symbol==_Symbol && PositionSelectByTicket(ticket))
        {
         sl = PositionGetDouble(POSITION_SL);
         tp = PositionGetDouble(POSITION_TP);
         DrawSLTPLines(ticket,sl,tp);
        }
     }

   CleanupLines(activeTickets);
   UpdatePanel();
  }

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(sparam == g_BtnPassive)
     {
      g_Mode = MODE_PASSIVE;
      UpdatePanel();
      Alert("Mode set to PASSIVE");
      Print("Mode changed to PASSIVE");
     }
   else
      if(sparam == g_BtnAssisted)
        {
         g_Mode = MODE_ASSISTED;
         UpdatePanel();
         Alert("Mode set to ASSISTED");
         Print("Mode changed to ASSISTED");
        }
      else
         if(sparam == g_BtnStrict)
           {
            g_Mode = MODE_STRICT;
            UpdatePanel();
            Alert("Mode set to STRICT");
            Print("Mode changed to STRICT");
           }
         else
            if(sparam == g_BtnRiskUp)
              {
               g_RiskPercent = MathMin(10.0,g_RiskPercent+0.1);
               UpdatePanel();
               Alert(StringFormat("Risk percent set to %.2f%%",g_RiskPercent));
               Print("Risk changed to ",g_RiskPercent,"%");
              }
            else
               if(sparam == g_BtnRiskDown)
                 {
                  g_RiskPercent = MathMax(0.1,g_RiskPercent-0.1);
                  UpdatePanel();
                  Alert(StringFormat("Risk percent set to %.2f%%",g_RiskPercent));
                  Print("Risk changed to ",g_RiskPercent,"%");
                 }
               else
                  if(sparam == g_BtnRRUp)
                    {
                     g_RRatio = MathMin(10.0,g_RRatio+0.5);
                     UpdatePanel();
                     Alert(StringFormat("R:R ratio set to %.1f",g_RRatio));
                     Print("R:R changed to ",g_RRatio);
                    }
                  else
                     if(sparam == g_BtnRRDown)
                       {
                        g_RRatio = MathMax(0.5,g_RRatio-0.5);
                        UpdatePanel();
                        Alert(StringFormat("R:R ratio set to %.1f",g_RRatio));
                        Print("R:R changed to ",g_RRatio);
                       }
  }

//+------------------------------------------------------------------+
//| Create on-chart panel                                            |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   ObjectCreate(0,g_Rectangle,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,g_Rectangle,OBJPROP_XDISTANCE,PANEL_X-5);
   ObjectSetInteger(0,g_Rectangle,OBJPROP_YDISTANCE,PANEL_Y-25);
   ObjectSetInteger(0,g_Rectangle,OBJPROP_XSIZE,PANEL_W);
   ObjectSetInteger(0,g_Rectangle,OBJPROP_YSIZE,PANEL_H);
   ObjectSetInteger(0,g_Rectangle,OBJPROP_BGCOLOR,BG_COLOR);
   ObjectSetInteger(0,g_Rectangle,OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,g_Rectangle,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,g_Rectangle,OBJPROP_BACK,true);
   ObjectSetInteger(0,g_Rectangle,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,g_Rectangle,OBJPROP_CORNER,CORNER_LEFT_UPPER);

   int x = PANEL_X;
   int y = PANEL_Y;

   CreateButton(g_BtnPassive, x, y, BUTTON_WIDTH, BUTTON_HEIGHT, "Passive");
   CreateButton(g_BtnAssisted, x+65, y, BUTTON_WIDTH, BUTTON_HEIGHT, "Assisted");
   CreateButton(g_BtnStrict, x+130, y, BUTTON_WIDTH, BUTTON_HEIGHT, "Strict");

   y += ROW_STEP;

   CreateButton(g_BtnRiskDown, x, y, SMALL_BTN_W, SMALL_BTN_W, "-");
   CreateButton(g_BtnRiskUp, x+25, y, SMALL_BTN_W, SMALL_BTN_W, "+");

   ObjectCreate(0,g_LblRisk,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,g_LblRisk,OBJPROP_XDISTANCE,x+50);
   ObjectSetInteger(0,g_LblRisk,OBJPROP_YDISTANCE,y+2);
   ObjectSetInteger(0,g_LblRisk,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,g_LblRisk,OBJPROP_TEXT,"Risk: --%");

   y += ROW_STEP;

   CreateButton(g_BtnRRDown, x, y, SMALL_BTN_W, SMALL_BTN_W, "-");
   CreateButton(g_BtnRRUp, x+25, y, SMALL_BTN_W, SMALL_BTN_W, "+");

   ObjectCreate(0,g_LblRR,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,g_LblRR,OBJPROP_XDISTANCE,x+50);
   ObjectSetInteger(0,g_LblRR,OBJPROP_YDISTANCE,y+2);
   ObjectSetInteger(0,g_LblRR,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,g_LblRR,OBJPROP_TEXT,"R:R: --");

   y += ROW_STEP+5;

   CreateLabel(g_LblMode, x, y, "Mode: --");
   y += ROW_STEP;
   CreateLabel(g_LblEquity, x, y, "Equity: --");
   y += ROW_STEP;
   CreateLabel(g_LblScore, x, y, "Discipline: --%");
   y += ROW_STEP;
   CreateLabel(g_LblLastAct, x, y, "Last action: --", 300, 8);
  }

//+------------------------------------------------------------------+
//| Helper: create a button                                          |
//+------------------------------------------------------------------+
void CreateButton(string name,int x,int y,int w,int h,string text)
  {
   ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,INACTIVE_COLOR);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
  }

//+------------------------------------------------------------------+
//| Helper: create a label                                           |
//+------------------------------------------------------------------+
void CreateLabel(string name,int x,int y,string text,int width=0,int fontSize=10)
  {
   ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   if(width>0)
      ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrBlack);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
  }

//+------------------------------------------------------------------+
//| Delete all panel objects                                         |
//+------------------------------------------------------------------+
void DeletePanel()
  {
   string objects[] =
     {
      g_Rectangle,g_BtnPassive,g_BtnAssisted,g_BtnStrict,
      g_BtnRiskUp,g_BtnRiskDown,g_BtnRRUp,g_BtnRRDown,
      g_LblMode,g_LblRisk,g_LblRR,g_LblEquity,g_LblScore,g_LblLastAct
     };

   for(int i=0; i<ArraySize(objects); i++)
      ObjectDelete(0,objects[i]);
  }

//+------------------------------------------------------------------+
//| Update panel text and button colors                              |
//+------------------------------------------------------------------+
void UpdatePanel()
  {
   string modeStr = "";
   switch(g_Mode)
     {
      case MODE_PASSIVE:
         modeStr = "PASSIVE";
         break;
      case MODE_ASSISTED:
         modeStr = "ASSISTED";
         break;
      case MODE_STRICT:
         modeStr = "STRICT";
         break;
     }

   ObjectSetString(0,g_LblMode,  OBJPROP_TEXT,"Mode: "+modeStr);
   ObjectSetString(0,g_LblRisk,  OBJPROP_TEXT,StringFormat("Risk: %.2f%%",g_RiskPercent));
   ObjectSetString(0,g_LblRR,    OBJPROP_TEXT,StringFormat("R:R: %.1f",g_RRatio));
   ObjectSetString(0,g_LblEquity,OBJPROP_TEXT,StringFormat("Equity: %.2f",AccountInfoDouble(ACCOUNT_EQUITY)));

   double score = (g_TotalTradesChecked>0)
                  ? (1.0-(double)g_ViolationsCorrected/g_TotalTradesChecked)*100.0
                  : 100.0;

   ObjectSetString(0,g_LblScore,OBJPROP_TEXT,StringFormat("Discipline: %.1f%%",score));

   ObjectSetInteger(0,g_BtnPassive, OBJPROP_BGCOLOR,(g_Mode==MODE_PASSIVE)?ACTIVE_COLOR:INACTIVE_COLOR);
   ObjectSetInteger(0,g_BtnAssisted,OBJPROP_BGCOLOR,(g_Mode==MODE_ASSISTED)?ACTIVE_COLOR:INACTIVE_COLOR);
   ObjectSetInteger(0,g_BtnStrict,  OBJPROP_BGCOLOR,(g_Mode==MODE_STRICT)?ACTIVE_COLOR:INACTIVE_COLOR);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Calculate required SL distance in price units                    |
//+------------------------------------------------------------------+
double CalculateRequiredSLDistance(string symbol,double lot,double riskPercent)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<=0.0 || riskPercent<=0.0 || lot<=0.0)
      return 0.0;

   double riskAmount = equity*riskPercent/100.0;
   double tickValue  = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize   = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);

   if(tickValue<=0.0 || tickSize<=0.0)
      return 0.0;

   double riskTicks = riskAmount/(tickValue*lot);
   if(riskTicks<=0.0)
      return 0.0;

   double slDistance = riskTicks*tickSize;

   long stopsLevel = SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevel>0)
     {
      double minStop = stopsLevel*tickSize;
      if(slDistance < minStop)
         slDistance = minStop;
     }

   return slDistance;
  }

//+------------------------------------------------------------------+
//| Adjust oversized lot (partial close)                             |
//+------------------------------------------------------------------+
void AdjustLotSize(ulong ticket,string symbol,ENUM_POSITION_TYPE type,
                   double currentLot,double openPrice,double requiredSLDist)
  {
   long stopsLevel = SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevel <= 0)
      return;

   double tickSize = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double minStopPrice = stopsLevel*tickSize;

   if(requiredSLDist >= minStopPrice)
      return;

   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity*g_RiskPercent/100.0;
   double tickValue  = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);

   if(tickValue <= 0.0)
      return;

   double maxSafeLot = riskAmount/(tickValue*(minStopPrice/tickSize));
   maxSafeLot = NormalizeVolumeByStep(symbol,maxSafeLot);

   if(currentLot > maxSafeLot + SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP)*0.5)
     {
      double reduceAmount = currentLot - maxSafeLot;
      reduceAmount = NormalizeVolumeByStep(symbol,reduceAmount);

      if(reduceAmount <= 0.0)
         return;

      Print("Lot size too large (",DoubleToString(currentLot,2),
            "). Reducing by ",DoubleToString(reduceAmount,2),
            " to ",DoubleToString(maxSafeLot,2)," for ticket ",ticket);

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};

      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = symbol;
      req.volume       = reduceAmount;
      req.deviation    = 10;
      req.position     = ticket;
      req.magic        = (ulong)PositionGetInteger(POSITION_MAGIC);
      req.type_filling = ORDER_FILLING_IOC;

      if(type == POSITION_TYPE_BUY)
         req.type = ORDER_TYPE_SELL;
      else
         req.type = ORDER_TYPE_BUY;

      req.price = SymbolInfoDouble(symbol,(type==POSITION_TYPE_BUY)?SYMBOL_BID:SYMBOL_ASK);

      if(OrderSend(req,res))
        {
         if(res.retcode == TRADE_RETCODE_DONE)
           {
            LogAction(ticket,StringFormat("Reduced lot from %.2f to %.2f",currentLot,maxSafeLot));
            ObjectSetString(0,g_LblLastAct,OBJPROP_TEXT,
                            StringFormat("Last: Ticket %I64u lot reduced",ticket));
           }
         else
            LogAction(ticket,StringFormat("Lot reduction failed, retcode %d",res.retcode));
        }
      else
         LogAction(ticket,"Lot reduction OrderSend failed");
     }
  }

//+------------------------------------------------------------------+
//| Enforce correct SL and TP for a position                         |
//+------------------------------------------------------------------+
bool EnforceSLTP(ulong ticket,string symbol,ENUM_POSITION_TYPE type,
                 double lot,double openPrice,double requiredSLDist,double rr)
  {
   if(requiredSLDist <= 0.0 || rr <= 0.0)
      return false;

   double newSL = 0.0;
   double newTP = 0.0;

   if(type == POSITION_TYPE_BUY)
     {
      newSL = openPrice - requiredSLDist;
      newTP = openPrice + requiredSLDist*rr;
     }
   else
     {
      newSL = openPrice + requiredSLDist;
      newTP = openPrice - requiredSLDist*rr;
     }

   newSL = NormalizePriceBySymbol(symbol,newSL);
   newTP = NormalizePriceBySymbol(symbol,newTP);

   long   stopsLevel   = SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double point        = SymbolInfoDouble(symbol,SYMBOL_POINT);
   double minStopDist  = stopsLevel*point;

   if(MathAbs(openPrice-newSL) < minStopDist || MathAbs(openPrice-newTP) < minStopDist)
     {
      Print("SL/TP too close to market (minStop=",DoubleToString(minStopDist,_Digits),
            "), correction skipped for ticket ",ticket);
      return false;
     }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};

   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = symbol;
   req.position = ticket;
   req.sl       = newSL;
   req.tp       = newTP;

   if(OrderSend(req,res) && res.retcode == TRADE_RETCODE_DONE)
     {
      LogAction(ticket,StringFormat("SL/TP set: SL=%.5f, TP=%.5f",newSL,newTP));
      ObjectSetString(0,g_LblLastAct,OBJPROP_TEXT,
                      StringFormat("Last: Ticket %I64u SL/TP corrected",ticket));
      return true;
     }

   Print("Modify failed for ticket ",ticket,", retcode=",res.retcode);
   return false;
  }

//+------------------------------------------------------------------+
//| Draw horizontal lines for SL and TP                              |
//+------------------------------------------------------------------+
void DrawSLTPLines(ulong ticket,double sl,double tp)
  {
   string slName = g_Prefix + "SL_" + (string)ticket;
   string tpName = g_Prefix + "TP_" + (string)ticket;

   ObjectDelete(0,slName);
   ObjectDelete(0,tpName);

   if(sl != 0.0)
     {
      if(ObjectCreate(0,slName,OBJ_HLINE,0,0,sl))
        {
         ObjectSetInteger(0,slName,OBJPROP_COLOR,clrRed);
         ObjectSetInteger(0,slName,OBJPROP_WIDTH,1);
         ObjectSetInteger(0,slName,OBJPROP_STYLE,STYLE_DASH);
         ObjectSetString(0,slName,OBJPROP_TOOLTIP,"SL Ticket " + (string)ticket);
         ObjectSetString(0,slName,OBJPROP_TEXT,"SL " + (string)ticket);
        }
     }

   if(tp != 0.0)
     {
      if(ObjectCreate(0,tpName,OBJ_HLINE,0,0,tp))
        {
         ObjectSetInteger(0,tpName,OBJPROP_COLOR,clrLimeGreen);
         ObjectSetInteger(0,tpName,OBJPROP_WIDTH,1);
         ObjectSetInteger(0,tpName,OBJPROP_STYLE,STYLE_DASH);
         ObjectSetString(0,tpName,OBJPROP_TOOLTIP,"TP Ticket " + (string)ticket);
         ObjectSetString(0,tpName,OBJPROP_TEXT,"TP " + (string)ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//| Delete all SL/TP lines drawn by this EA                          |
//+------------------------------------------------------------------+
void DeleteAllLines()
  {
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1; i>=0; i--)
     {
      string name = ObjectName(0,i);
      if(StringFind(name,g_Prefix+"SL_")==0 || StringFind(name,g_Prefix+"TP_")==0)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
//| Remove lines for positions that are no longer active             |
//+------------------------------------------------------------------+
void CleanupLines(ulong &activeTickets[])
  {
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1; i>=0; i--)
     {
      string name = ObjectName(0,i);
      if(StringFind(name,g_Prefix+"SL_")==0 || StringFind(name,g_Prefix+"TP_")==0)
        {
         int firstUnderscore  = StringFind(name,"_");
         int secondUnderscore = StringFind(name,"_",firstUnderscore+1);

         if(secondUnderscore > 0)
           {
            ulong ticket = (ulong)StringToInteger(StringSubstr(name,secondUnderscore+1));

            bool found = false;
            for(int j=0; j<ArraySize(activeTickets); j++)
              {
               if(activeTickets[j] == ticket)
                 {
                  found = true;
                  break;
                 }
              }

            if(!found)
               ObjectDelete(0,name);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Log action to Experts tab                                        |
//+------------------------------------------------------------------+
void LogAction(ulong ticket,string msg)
  {
   Print(StringFormat("[%I64u] %s",ticket,msg));
  }
//+------------------------------------------------------------------+
