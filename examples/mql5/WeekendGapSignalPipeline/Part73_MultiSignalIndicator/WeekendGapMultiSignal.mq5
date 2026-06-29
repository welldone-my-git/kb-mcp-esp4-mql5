//+------------------------------------------------------------------+
//|                                        WeekendGapMultiSignal.mq5 |
//|                              Copyright 2026, Christian Benjamin. |
//|                           https://www.mql5.com/en/users/lynchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin."
#property link      "https://www.mql5.com/en/users/lynchris"
#property version   "1.0"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   2

//--- visual properties for buy/sell arrows
#property indicator_label1  "Buy"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrBlue
#property indicator_width1  2

#property indicator_label2  "Sell"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrOrange
#property indicator_width2  2

//--- arrow symbols (wingdings)
#define ARROW_UP   233
#define ARROW_DOWN 234

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input bool   ShowHistoricalGaps      = true;      // Show historical gap zones
input int    MaxHistoricalWeeks      = 26;       // Max weeks to scan backwards
input double MinGapPips              = 0.5;      // Minimum gap size to consider
input double MinTradableGapPips      = 1.0;      // Minimum gap size for signals
input bool   ShowDetailedLabels      = true;     // Show extra labels on gaps
input bool   ShowTradeLevels         = true;     // Draw TP/SL lines for signals
input double ConfirmationOffsetPips  = 0.0;      // Pips offset for signal confirmation
input double StopBufferPips          = 0.0;      // Extra pips beyond weekly high/low for SL
input color  ActiveFillColor         = clrGainsboro;  // Fill color for active gaps
input color  ActiveOutlineColor      = clrDimGray;    // Outline color for active gaps
input int    ActiveFillOpacity       = 45;            // Fill opacity (0-100)
input color  BuyArrowColor           = clrBlue;       // Buy arrow color
input color  SellArrowColor          = clrOrange;     // Sell arrow color
input color  TPLineColor             = clrBlue;       // Take profit line color
input color  SLLineColor             = clrTomato;     // Stop loss line color
input color  WeekSeparatorColor      = clrGray;       // Vertical line color
input int    WeekSeparatorStyle      = STYLE_DASH;    // Line style for week separators
input int    LineWidth               = 2;             // Rectangle border width
input int    FontSize                = 8;             // Label font size
input int    ArrowSize               = 2;             // Arrow symbol size
input bool   InvertSignals           = false;         // Invert generated signals (buy<->sell)
input bool   DrawWeekSeparators      = true;          // Draw vertical lines at week boundaries
input bool   EnableAlerts            = true;          // Show popup alerts
input bool   EnableSound             = false;         // Play sound on new signal
input string SoundFile               = "alert.wav";   // Sound file name
input bool   EnableNotification      = false;         // Send mobile notification
input bool   EnableEmail             = false;         // Send email on signal

//+------------------------------------------------------------------+
//| Indicator buffers                                                |
//+------------------------------------------------------------------+
double BufferBuyArrow[];   // Buy arrow prices
double BufferSellArrow[];  // Sell arrow prices
double BufferBuyTP[];      // Buy take profit levels (for information)
double BufferBuySL[];      // Buy stop loss levels
double BufferSellTP[];     // Sell take profit levels
double BufferSellSL[];     // Sell stop loss levels

//+------------------------------------------------------------------+
//| Structure: one trade signal                                      |
//+------------------------------------------------------------------+
struct SignalRecord
  {
   datetime          signalTime;     // Bar opening time of signal
   double            signalPrice;    // Price where arrow is drawn
   double            signalTP;       // Take profit level
   double            signalSL;       // Stop loss level
   bool              signalIsBuy;    // true = buy, false = sell
  };

//+------------------------------------------------------------------+
//| Structure: weekly gap information                                |
//+------------------------------------------------------------------+
struct GapInfo
  {
   datetime          monOpenTime;      // Monday 00:00 of this gap week
   double            gapHigh;          // Upper edge of gap (max of Fri close / Mon open)
   double            gapLow;           // Lower edge of gap
   bool              isGapDown;        // true if gap down (Fri close > Mon open)
   bool              gapFilled;        // Has price touched the opposite edge?
   int               scanStartIndex;   // Bar index where this week starts (for historical scan)
   double            weekLow;          // Lowest price seen so far this week
   double            weekHigh;         // Highest price seen so far this week
   datetime          lastSignalBarTime;// Last bar that generated a signal (avoid duplicates)
   SignalRecord      signals[];        // All signals recorded for this gap
  };

//--- global data
GapInfo   g_gaps[];          // Array of all detected gaps
datetime  g_lastBarTime = 0;  // Time of last processed bar (for new bar detection)
bool      g_firstRun    = true;

//+------------------------------------------------------------------+
//| Helper: return pip size for current symbol                       |
//+------------------------------------------------------------------+
double PipSize()
  {
   return (_Digits == 3 || _Digits == 5) ? (_Point * 10.0) : _Point;
  }

//+------------------------------------------------------------------+
//| Helper: convert pips to price offset                             |
//+------------------------------------------------------------------+
double PipOffset(double pips)
  {
   return pips * PipSize();
  }

//+------------------------------------------------------------------+
//| Helper: apply alpha transparency to a color                      |
//+------------------------------------------------------------------+
color ColorSetAlpha(color clr, uchar alpha)
  {
   return (color)((clr & 0x00FFFFFF) | ((uint)alpha << 24));
  }

//+------------------------------------------------------------------+
//| Helper: return next Monday 00:00 after given Monday              |
//+------------------------------------------------------------------+
datetime GetNextMondayOpen(datetime monday)
  {
   return monday + 7 * 86400;
  }

//+------------------------------------------------------------------+
//| Helper: generate unique prefix string for a gap index            |
//+------------------------------------------------------------------+
string PrefixForIndex(int idx)
  {
   return "WG_" + IntegerToString(idx);
  }

//+------------------------------------------------------------------+
//| Helper: check if candle's high/low range contains a level        |
//+------------------------------------------------------------------+
bool CandleTouchesLevel(double hi, double lo, double lvl)
  {
   return (hi >= lvl && lo <= lvl);
  }

//+------------------------------------------------------------------+
//| Helper: return gap size in pips for given gap index              |
//+------------------------------------------------------------------+
double GapPips(int gapIdx)
  {
   if(gapIdx < 0 || gapIdx >= ArraySize(g_gaps))
      return 0.0;
   return MathAbs(g_gaps[gapIdx].gapHigh - g_gaps[gapIdx].gapLow) / PipSize();
  }

//+------------------------------------------------------------------+
//| Helper: check if gap meets the tradable size threshold           |
//+------------------------------------------------------------------+
bool IsTradableGap(int gapIdx)
  {
   return (GapPips(gapIdx) >= MinTradableGapPips);
  }

//+------------------------------------------------------------------+
//| Alert dispatcher: popup, sound, push, email                      |
//+------------------------------------------------------------------+
void DoAlert(string msg, bool sound, bool push, bool mail)
  {
   if(!EnableAlerts)
      return;
   Alert(msg);
   if(sound)
      PlaySound(SoundFile);
   if(push)
      SendNotification(msg);
   if(mail)
      SendMail("Weekend Gap Signal", msg);
  }

//+------------------------------------------------------------------+
//| Delete all chart objects prefixed with "WG_"                     |
//+------------------------------------------------------------------+
void DeleteWGObjects()
  {
   const long chart_id = 0;
   int total = ObjectsTotal(chart_id, 0, -1);
   for(int i = total - 1; i >= 0; --i)
     {
      string name = ObjectName(chart_id, i, 0, -1);
      if(StringFind(name, "WG_") == 0)
         ObjectDelete(chart_id, name);
     }
  }

//+------------------------------------------------------------------+
//| Draw a vertical line to separate weeks                           |
//+------------------------------------------------------------------+
void DrawWeekSeparator(datetime lineTime, int weekNumber)
  {
   if(!DrawWeekSeparators)
      return;
   string objName = "WG_WeekSep_" + IntegerToString(weekNumber);
   if(ObjectFind(0, objName) >= 0)
      return;
   ObjectCreate(0, objName, OBJ_VLINE, 0, lineTime, 0);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, WeekSeparatorColor);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, WeekSeparatorStyle);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
  }

//+------------------------------------------------------------------+
//| Draw or update a text label on the chart                         |
//+------------------------------------------------------------------+
void DrawTextLabel(string name, datetime t, double p, string txt, color clr, int sz, string font, int anchor = ANCHOR_LEFT)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   else
      ObjectMove(0, name, 0, t, p);

   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, sz);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
  }

//+------------------------------------------------------------------+
//| Check if a gap with given Monday open already exists             |
//+------------------------------------------------------------------+
bool GapExistsByMonOpen(datetime monOpen)
  {
   for(int i = 0; i < ArraySize(g_gaps); i++)
      if(g_gaps[i].monOpenTime == monOpen)
         return true;
   return false;
  }

//+------------------------------------------------------------------+
//| Append a new gap structure to global array                       |
//+------------------------------------------------------------------+
void AddGap(const GapInfo &g)
  {
   int sz = ArraySize(g_gaps);
   ArrayResize(g_gaps, sz + 1);
   g_gaps[sz] = g;
  }

//+------------------------------------------------------------------+
//| Draw TP/SL trend lines for a specific signal                     |
//+------------------------------------------------------------------+
void DrawTradeLevels(int gapIdx, int sigIdx, string prefix)
  {
   if(!ShowTradeLevels)
      return;
   if(gapIdx < 0 || gapIdx >= ArraySize(g_gaps))
      return;
   if(sigIdx < 0 || sigIdx >= ArraySize(g_gaps[gapIdx].signals))
      return;

   SignalRecord sig = g_gaps[gapIdx].signals[sigIdx];
   datetime endTime = g_gaps[gapIdx].monOpenTime + 7 * 86400;
   string id = prefix + "_S" + IntegerToString(sigIdx);
   string tpName = id + "_TP";
   string slName = id + "_SL";

   ObjectDelete(0, tpName);
   ObjectDelete(0, slName);

//--- draw take profit line (horizontal from signal time to week end)
   ObjectCreate(0, tpName, OBJ_TREND, 0, sig.signalTime, sig.signalTP, endTime, sig.signalTP);
   ObjectSetInteger(0, tpName, OBJPROP_COLOR, TPLineColor);
   ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, tpName, OBJPROP_RAY_RIGHT, false);

//--- draw stop loss line
   ObjectCreate(0, slName, OBJ_TREND, 0, sig.signalTime, sig.signalSL, endTime, sig.signalSL);
   ObjectSetInteger(0, slName, OBJPROP_COLOR, SLLineColor);
   ObjectSetInteger(0, slName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, slName, OBJPROP_RAY_RIGHT, false);
  }

//+------------------------------------------------------------------+
//| Create visual objects for a gap (rectangle, midline, labels)     |
//+------------------------------------------------------------------+
void CreateGapObjects(int gapIdx, string prefix)
  {
   if(!ShowHistoricalGaps || gapIdx < 0 || gapIdx >= ArraySize(g_gaps))
      return;

//--- draw week separator if enabled
   if(DrawWeekSeparators)
     {
      int weekNum = (int)(g_gaps[gapIdx].monOpenTime / 86400 / 7);
      DrawWeekSeparator(g_gaps[gapIdx].monOpenTime, weekNum);
     }

   datetime leftTime   = g_gaps[gapIdx].monOpenTime;
   datetime rightTime  = GetNextMondayOpen(leftTime);
   long     weekLength = rightTime - leftTime;
   double   mid        = (g_gaps[gapIdx].gapHigh + g_gaps[gapIdx].gapLow) / 2.0;

   string rect = prefix + "_RECT";
   string midL = prefix + "_MID";
   string lbl  = prefix + "_LBL";

//--- gap rectangle
   if(ObjectFind(0, rect) < 0)
     {
      ObjectCreate(0, rect, OBJ_RECTANGLE, 0, leftTime, g_gaps[gapIdx].gapHigh, rightTime, g_gaps[gapIdx].gapLow);
      ObjectSetInteger(0, rect, OBJPROP_COLOR, ActiveOutlineColor);
      ObjectSetInteger(0, rect, OBJPROP_WIDTH, LineWidth);
      ObjectSetInteger(0, rect, OBJPROP_FILL, true);
      ObjectSetInteger(0, rect, OBJPROP_BGCOLOR, ColorSetAlpha(ActiveFillColor, (uchar)(ActiveFillOpacity * 255 / 100)));
      ObjectSetInteger(0, rect, OBJPROP_BACK, true);
     }

//--- midline (solid yellow for clear visibility)
   if(ObjectFind(0, midL) < 0)
     {
      ObjectCreate(0, midL, OBJ_TREND, 0, leftTime, mid, rightTime, mid);
      ObjectSetInteger(0, midL, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, midL, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, midL, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, midL, OBJPROP_BACK, true);
     }

//--- main label showing gap size
   if(ObjectFind(0, lbl) < 0)
     {
      datetime labelTime = (datetime)(leftTime + (long)(weekLength * 0.25));
      DrawTextLabel(lbl, labelTime, mid, StringFormat("WG | %.1fp", GapPips(gapIdx)), clrBlack, FontSize, "Arial Bold", ANCHOR_CENTER);
     }

//--- detailed labels (Friday close, Monday open, midpoint)
   if(ShowDetailedLabels)
     {
      datetime detailTime = (datetime)(leftTime + (long)(weekLength * 0.05));
      double gapHeight    = g_gaps[gapIdx].gapHigh - g_gaps[gapIdx].gapLow;
      double offset       = gapHeight * 0.1;
      int smallFont       = MathMax(FontSize - 1, 6);

      string topText;
      string botText;

      if(g_gaps[gapIdx].isGapDown)
        {
         topText = "FRIDAY CLOSE";
         botText = "MONDAY OPEN";
        }
      else
        {
         topText = "MONDAY OPEN";
         botText = "FRIDAY CLOSE";
        }

      DrawTextLabel(prefix + "_TOP", detailTime, g_gaps[gapIdx].gapHigh - offset, topText, clrBlack, smallFont, "Arial");
      DrawTextLabel(prefix + "_BOT", detailTime, g_gaps[gapIdx].gapLow + offset,  botText, clrBlack, smallFont, "Arial");
      DrawTextLabel(prefix + "_MIDPRICE", detailTime, mid,                        "MIDPOINT",     clrBlack, smallFont, "Arial");
     }
  }

//+------------------------------------------------------------------+
//| Update visuals when gap state changes (signal added, filled)     |
//+------------------------------------------------------------------+
void UpdateGapVisuals(int gapIdx, string prefix)
  {
   if(!ShowHistoricalGaps || gapIdx < 0 || gapIdx >= ArraySize(g_gaps))
      return;

   string rect = prefix + "_RECT";
   string lbl  = prefix + "_LBL";

   if(ObjectFind(0, rect) < 0)
      return;

   int sigCount = ArraySize(g_gaps[gapIdx].signals);

//--- if there is at least one signal, highlight rectangle with signal color
   if(sigCount > 0)
     {
      SignalRecord latest = g_gaps[gapIdx].signals[sigCount - 1];
      color sigColor = latest.signalIsBuy ? clrLimeGreen : clrRed;
      ObjectSetInteger(0, rect, OBJPROP_COLOR, sigColor);
      ObjectSetInteger(0, rect, OBJPROP_FILL, true);
      //--- use semi-transparent version of signal color for background
      color bgColor = ColorSetAlpha(sigColor, 60);
      ObjectSetInteger(0, rect, OBJPROP_BGCOLOR, bgColor);

      if(ObjectFind(0, lbl) >= 0)
        {
         ObjectSetInteger(0, lbl, OBJPROP_COLOR, clrBlack);
         string side = latest.signalIsBuy ? "BUY" : "SELL";
         ObjectSetString(0, lbl, OBJPROP_TEXT, StringFormat("WG | %.1fp | %s", GapPips(gapIdx), side));
        }
      return;
     }

//--- no signal: default inactive appearance
   ObjectSetInteger(0, rect, OBJPROP_COLOR, ActiveOutlineColor);
   ObjectSetInteger(0, rect, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, rect, OBJPROP_WIDTH, LineWidth);
   ObjectSetInteger(0, rect, OBJPROP_FILL, true);
   ObjectSetInteger(0, rect, OBJPROP_BGCOLOR, ColorSetAlpha(ActiveFillColor, (uchar)(ActiveFillOpacity * 255 / 100)));

   if(ObjectFind(0, lbl) >= 0)
     {
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, clrBlack);
      ObjectSetString(0, lbl, OBJPROP_TEXT, StringFormat("WG | %.1fp", GapPips(gapIdx)));
     }
  }

//+------------------------------------------------------------------+
//| Record a new signal and draw its objects/alert                   |
//+------------------------------------------------------------------+
void PublishSignal(int gapIdx, int barIdx, bool isBuy, bool isHistorical,
                   const datetime &time[], const double &high[], const double &low[])
  {
   SignalRecord newSig;
   newSig.signalTime  = time[barIdx];
   newSig.signalIsBuy = isBuy;

//--- visual arrow placement: always 2 pips away from candle edge to avoid overlap
   double visualOffset = PipOffset(2.0);
   newSig.signalPrice = isBuy ? (low[barIdx] - visualOffset) : (high[barIdx] + visualOffset);
   newSig.signalTP    = isBuy ? g_gaps[gapIdx].gapHigh : g_gaps[gapIdx].gapLow;
   newSig.signalSL    = isBuy ? (g_gaps[gapIdx].weekLow - PipOffset(StopBufferPips))
                        : (g_gaps[gapIdx].weekHigh + PipOffset(StopBufferPips));

//--- store signal
   int sz = ArraySize(g_gaps[gapIdx].signals);
   ArrayResize(g_gaps[gapIdx].signals, sz + 1);
   g_gaps[gapIdx].signals[sz] = newSig;
   g_gaps[gapIdx].lastSignalBarTime = time[barIdx];

//--- draw TP/SL levels if requested
   if(ShowTradeLevels)
      DrawTradeLevels(gapIdx, sz, PrefixForIndex(gapIdx));

//--- for live signals (not historical), send alerts and print
   if(!isHistorical)
     {
      string signalType = isBuy ? "BUY" : "SELL";
      string msg = StringFormat("Weekend Gap %s signal on %s %s at %s | TP: %.*f | SL: %.*f",
                                signalType, _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period),
                                TimeToString(newSig.signalTime, TIME_DATE | TIME_MINUTES),
                                _Digits, newSig.signalTP, _Digits, newSig.signalSL);
      DoAlert(msg, EnableSound, EnableNotification, EnableEmail);
      Print(msg);
     }
  }

//+------------------------------------------------------------------+
//| Render arrow buffers from stored signals                         |
//+------------------------------------------------------------------+
void RenderSignalBuffers(const int rates_total)
  {
//--- reset buffers (called only on new bar, so performance acceptable for most cases)
   for(int i = 0; i < rates_total; i++)
     {
      BufferBuyArrow[i] = EMPTY_VALUE;
      BufferSellArrow[i] = EMPTY_VALUE;
      BufferBuyTP[i]    = EMPTY_VALUE;
      BufferBuySL[i]    = EMPTY_VALUE;
      BufferSellTP[i]   = EMPTY_VALUE;
      BufferSellSL[i]   = EMPTY_VALUE;
     }

//--- fill from gap signals
   for(int g = 0; g < ArraySize(g_gaps); g++)
     {
      for(int s = 0; s < ArraySize(g_gaps[g].signals); s++)
        {
         SignalRecord sig = g_gaps[g].signals[s];
         int sh = iBarShift(_Symbol, _Period, sig.signalTime, false);
         if(sh < 0 || sh >= rates_total)
            continue;

         if(sig.signalIsBuy)
           {
            BufferBuyArrow[sh] = sig.signalPrice;
            BufferBuyTP[sh]    = NormalizeDouble(sig.signalTP, _Digits);
            BufferBuySL[sh]    = NormalizeDouble(sig.signalSL, _Digits);
           }
         else
           {
            BufferSellArrow[sh] = sig.signalPrice;
            BufferSellTP[sh]    = NormalizeDouble(sig.signalTP, _Digits);
            BufferSellSL[sh]    = NormalizeDouble(sig.signalSL, _Digits);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Process a single bar for a given gap: signal detection & fill    |
//+------------------------------------------------------------------+
void ProcessBarForGap(int gapIdx, int shift, const double &high[], const double &low[],
                      const double &close[], const datetime &time[], bool historical=false)
  {
   if(gapIdx < 0 || gapIdx >= ArraySize(g_gaps))
      return;
   if(time[shift] <= g_gaps[gapIdx].monOpenTime)
      return;
   datetime nextMonday = g_gaps[gapIdx].monOpenTime + 7 * 86400;
   if(time[shift] >= nextMonday)
      return;
   if(g_gaps[gapIdx].gapFilled)
      return;
   if(!IsTradableGap(gapIdx))
      return;

//--- initialise weekly high/low if not set
   if(g_gaps[gapIdx].weekLow == 0)
      g_gaps[gapIdx].weekLow = g_gaps[gapIdx].gapLow;
   if(g_gaps[gapIdx].weekHigh == 0)
      g_gaps[gapIdx].weekHigh = g_gaps[gapIdx].gapHigh;

//--- update weekly extremes
   if(high[shift] > g_gaps[gapIdx].weekHigh)
      g_gaps[gapIdx].weekHigh = high[shift];
   if(low[shift] < g_gaps[gapIdx].weekLow)
      g_gaps[gapIdx].weekLow = low[shift];

//--- check if gap got filled (price touches the opposite edge)
   if((g_gaps[gapIdx].isGapDown && CandleTouchesLevel(high[shift], low[shift], g_gaps[gapIdx].gapHigh)) ||
      (!g_gaps[gapIdx].isGapDown && CandleTouchesLevel(high[shift], low[shift], g_gaps[gapIdx].gapLow)))
     {
      g_gaps[gapIdx].gapFilled = true;
      return;
     }

//--- determine raw signal conditions (using confirmation offset for logic)
   bool buySignal = false, sellSignal = false;
   if(g_gaps[gapIdx].isGapDown)
     {
      buySignal = (low[shift] <= (g_gaps[gapIdx].gapLow + PipOffset(ConfirmationOffsetPips)) &&
                   close[shift] > g_gaps[gapIdx].gapLow);
     }
   else
     {
      sellSignal = (high[shift] >= (g_gaps[gapIdx].gapHigh - PipOffset(ConfirmationOffsetPips)) &&
                    close[shift] < g_gaps[gapIdx].gapHigh);
     }

   bool signalNow = (buySignal || sellSignal);
   if(signalNow && g_gaps[gapIdx].lastSignalBarTime != time[shift])
     {
      bool isBuy = buySignal;
      if(InvertSignals)
         isBuy = !isBuy;
      PublishSignal(gapIdx, shift, isBuy, historical, time, high, low);
     }
  }

//+------------------------------------------------------------------+
//| Scan entire history to detect all weekly gaps                    |
//+------------------------------------------------------------------+
void DetectAllGaps()
  {
   ArrayResize(g_gaps, 0);
   int bars = Bars(_Symbol, _Period);
   if(bars < 3)
      return;

//--- load historical price data
   datetime timeArr[];
   double openArr[], closeArr[];
   ArraySetAsSeries(timeArr, true);
   ArraySetAsSeries(openArr, true);
   ArraySetAsSeries(closeArr, true);
   if(CopyTime(_Symbol, _Period, 0, bars, timeArr) <= 0)
      return;
   if(CopyOpen(_Symbol, _Period, 0, bars, openArr) <= 0)
      return;
   if(CopyClose(_Symbol, _Period, 0, bars, closeArr) <= 0)
      return;

   double pip = PipSize();
   int barsPerWeek = (int)((7 * 86400) / PeriodSeconds(_Period));
   if(barsPerWeek < 1)
      barsPerWeek = 1;
   int limit = MathMin(bars - 2, MaxHistoricalWeeks * barsPerWeek);
   if(limit < 1)
      return;

//--- iterate bars to find weekend gaps
   for(int i = 0; i < limit; i++)
     {
      double diff = (double)(timeArr[i] - timeArr[i + 1]);
      if(diff >= 172800)   // at least two days difference indicates weekend
        {
         double mondayOpen = openArr[i];
         double fridayClose = closeArr[i + 1];
         double gapPips = MathAbs(mondayOpen - fridayClose) / pip;
         if(gapPips >= MinGapPips && !GapExistsByMonOpen(timeArr[i]))
           {
            GapInfo gap;
            gap.monOpenTime = timeArr[i];
            gap.gapHigh = MathMax(mondayOpen, fridayClose);
            gap.gapLow = MathMin(mondayOpen, fridayClose);
            gap.isGapDown = (fridayClose > mondayOpen);
            gap.gapFilled = false;
            gap.scanStartIndex = i;
            gap.weekLow = 0;
            gap.weekHigh = 0;
            gap.lastSignalBarTime = 0;
            ArrayResize(gap.signals, 0);
            AddGap(gap);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Scan historical signals for all detected gaps                    |
//+------------------------------------------------------------------+
void ScanHistoricalSignals()
  {
   int bars = Bars(_Symbol, _Period);
   if(bars < 3)
      return;

//--- load price arrays for scanning
   datetime timeArr[];
   double highArr[], lowArr[], closeArr[];
   ArraySetAsSeries(timeArr, true);
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(closeArr, true);
   if(CopyTime(_Symbol, _Period, 0, bars, timeArr) <= 0)
      return;
   if(CopyHigh(_Symbol, _Period, 0, bars, highArr) <= 0)
      return;
   if(CopyLow(_Symbol, _Period, 0, bars, lowArr) <= 0)
      return;
   if(CopyClose(_Symbol, _Period, 0, bars, closeArr) <= 0)
      return;

//--- for each gap, walk forward from Monday and simulate signals
   for(int g = 0; g < ArraySize(g_gaps); g++)
     {
      int mondayIdx = g_gaps[g].scanStartIndex;
      if(mondayIdx < 0 || mondayIdx >= bars)
         continue;
      datetime nextMonday = g_gaps[g].monOpenTime + 7 * 86400;
      for(int s = mondayIdx - 1; s >= 0; s--)   
        {
         if(timeArr[s] >= nextMonday)
            break;
         ProcessBarForGap(g, s, highArr, lowArr, closeArr, timeArr, true);
         if(g_gaps[g].gapFilled)
            break;
        }
     }
  }

//+------------------------------------------------------------------+
//| Check for new signals on the current (latest) bar                |
//+------------------------------------------------------------------+
void CheckLiveSignals(const datetime &time[], const double &high[],
                      const double &low[], const double &close[])
  {
   int shift = 1;   
   if(ArraySize(time) <= shift + 1)
      return;

   for(int g = 0; g < ArraySize(g_gaps); g++)
     {
      datetime nextMonday = g_gaps[g].monOpenTime + 7 * 86400;
      if(time[shift] >= nextMonday)
         continue;
      ProcessBarForGap(g, shift, high, low, close, time, false);
     }
  }

//+------------------------------------------------------------------+
//| Indicator initialization function                                 |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- remove old objects
   DeleteWGObjects();

//--- set indicator buffers
   SetIndexBuffer(0, BufferBuyArrow, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSellArrow, INDICATOR_DATA);
   SetIndexBuffer(2, BufferBuyTP, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferBuySL, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferSellTP, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferSellSL, INDICATOR_CALCULATIONS);

//--- configure arrow plots
   PlotIndexSetInteger(0, PLOT_ARROW, ARROW_UP);
   PlotIndexSetInteger(1, PLOT_ARROW, ARROW_DOWN);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, ArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, ArrowSize);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, BuyArrowColor);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, SellArrowColor);

//--- series orientation for easy indexing
   ArraySetAsSeries(BufferBuyArrow, true);
   ArraySetAsSeries(BufferSellArrow, true);
   ArraySetAsSeries(BufferBuyTP, true);
   ArraySetAsSeries(BufferBuySL, true);
   ArraySetAsSeries(BufferSellTP, true);
   ArraySetAsSeries(BufferSellSL, true);

//--- initialise buffers with empty values
   ArrayInitialize(BufferBuyArrow, EMPTY_VALUE);
   ArrayInitialize(BufferSellArrow, EMPTY_VALUE);
   ArrayInitialize(BufferBuyTP, EMPTY_VALUE);
   ArrayInitialize(BufferBuySL, EMPTY_VALUE);
   ArrayInitialize(BufferSellTP, EMPTY_VALUE);
   ArrayInitialize(BufferSellSL, EMPTY_VALUE);

//--- set short name for the indicator (as it appears in the chart)
   IndicatorSetString(INDICATOR_SHORTNAME, "Weekend Gap Multi-Signal");

   g_firstRun = true;
   g_lastBarTime = 0;
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Indicator deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteWGObjects();
   ArrayFree(g_gaps);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function (main calculation)           |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- ensure all arrays are series-aligned (newest bar at index 0)
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   if(rates_total < 3)
      return 0;

//--- detect new bar (closed bar)
   bool newBar = (time[0] != g_lastBarTime);
   if(newBar)
      g_lastBarTime = time[0];

//--- first run or full recalculation: build gap database and historical signals
   if(prev_calculated == 0 || g_firstRun)
     {
      DetectAllGaps();
      ScanHistoricalSignals();

      if(ShowHistoricalGaps)
        {
         for(int g = 0; g < ArraySize(g_gaps); g++)
           {
            string prefix = PrefixForIndex(g);
            CreateGapObjects(g, prefix);
            UpdateGapVisuals(g, prefix);
           }
        }

      RenderSignalBuffers(rates_total);
      g_firstRun = false;
      return rates_total;
     }

//--- on a new bar, check for new gaps and live signals
   if(newBar)
     {
      //--- detect potential new weekend gap using closed bars only
      if((time[1] - time[2]) >= 172800)
        {
         if(!GapExistsByMonOpen(time[1]))
           {
            double mondayOpen = open[1];
            double fridayClose = close[2];
            double gp = MathAbs(mondayOpen - fridayClose) / PipSize();
            if(gp >= MinGapPips)
              {
               GapInfo gap;
               gap.monOpenTime = time[1];
               gap.gapHigh = MathMax(mondayOpen, fridayClose);
               gap.gapLow = MathMin(mondayOpen, fridayClose);
               gap.isGapDown = (fridayClose > mondayOpen);
               gap.gapFilled = false;
               gap.scanStartIndex = 1;
               gap.weekLow = 0;
               gap.weekHigh = 0;
               gap.lastSignalBarTime = 0;
               ArrayResize(gap.signals, 0);
               AddGap(gap);
               int idx = ArraySize(g_gaps) - 1;
               if(ShowHistoricalGaps)
                 {
                  string prefix = PrefixForIndex(idx);
                  CreateGapObjects(idx, prefix);
                  UpdateGapVisuals(idx, prefix);
                 }
              }
           }
        }

      //--- check for signals on the latest completed bar
      CheckLiveSignals(time, high, low, close);
      RenderSignalBuffers(rates_total);

      //--- update visual appearance of all gaps
      if(ShowHistoricalGaps)
        {
         for(int g = 0; g < ArraySize(g_gaps); g++)
            UpdateGapVisuals(g, PrefixForIndex(g));
        }
     }

   return rates_total;
  }
//+------------------------------------------------------------------+