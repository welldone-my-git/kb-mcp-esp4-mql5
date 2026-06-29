//+------------------------------------------------------------------+
//|                                    WeekendGapSignalIndicator.mq5 |
//|                              Copyright 2026, Christian Benjamin. |
//|                           https://www.mql5.com/en/users/lynchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin."
#property link      "https://www.mql5.com/en/users/lynchris"
#property version   "1.0"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Buy arrow plot
#property indicator_label1  "Buy"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

//--- Sell arrow plot
#property indicator_label2  "Sell"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

//--- arrow codes
#define ARROW_UP   233
#define ARROW_DOWN 234

//--- input parameters
input bool     ShowHistoricalGaps   = true;        // Show historical gaps (visual only)
input int      MaxHistoricalWeeks    = 26;          // Max weeks to look back
input double   MinGapPips            = 0.5;         // Minimum gap size in pips
input bool     ShowDetailedLabels    = true;        // Show extra price labels
input color    ActiveFillColor       = clrGainsboro;
input color    ActiveOutlineColor    = clrDimGray;
input color    ReactionColor         = clrDarkOrange;
input color    MemoryOutlineColor    = clrSilver;
input int      ActiveFillOpacity     = 50;          // Rectangle fill opacity (0-100)
input int      LineWidth             = 2;
input int      FontSize              = 7;
input int      ArrowSize             = 2;
input bool     InvertSignals         = false;       // Invert buy/sell logic

//--- week separator inputs
input bool     DrawWeekSeparators    = true;        // Draw vertical lines between weeks
input color    WeekSeparatorColor    = clrGray;     // Color of week separator lines
input int      WeekSeparatorStyle    = STYLE_DASH;  // Line style

//--- arrow color inputs
input color    BuyArrowColor         = clrDodgerBlue; // Buy arrows (chart objects)
input color    SellArrowColor        = clrRed;        // Sell arrows (chart objects)

//--- alert inputs
input bool     EnableAlerts          = true;        // Enable popup alerts on gap fills
input bool     EnableSound           = false;       // Play sound on fill
input string   SoundFile             = "alert.wav"; // Sound file name
input bool     EnableNotification    = false;       // Send push notification
input bool     EnableEmail           = false;       // Send email

//--- EA signal buffers (exposed via CopyBuffer)
double BufferBuy[];          // Buy signals: fill price at bar index
double BufferSell[];         // Sell signals: fill price at bar index
double BufferGapState[];     // Gap state at bar (for EA, 0..4)
double BufferFillPrice[];    // Fill price at bar (optional)

//--- Enum for gap state
enum ENUM_GAP_STATE
  {
   GAP_FRESH = 0,
   GAP_PARTIAL = 1,
   GAP_REACTION = 2,
   GAP_FILLED = 3,
   GAP_HISTORICAL = 4
  };

//--- Visual settings structure
struct VisualSettings
  {
   color             activeFillColor;
   color             activeOutlineColor;
   color             reactionColor;
   color             memoryOutlineColor;
   int               activeFillOpacity;
   int               lineWidth;
   int               fontSize;
  };

//--- Gap data structure (full record)
struct WeekendGapRecord
  {
   datetime          startTime;          // Monday open time
   datetime          endTime;            // Next Monday open time
   double            gapHigh;            // Upper boundary (max of Fri close, Mon open)
   double            gapLow;             // Lower boundary (min of Fri close, Mon open)
   double            midpoint;           // (gapHigh+gapLow)/2
   bool              isGapDown;          // true if Friday close > Monday open
   ENUM_GAP_STATE    state;              // Current state (FRESH, PARTIAL, REACTION, FILLED, HISTORICAL)
   bool              activeWeek;         // true if gap belongs to current week
   datetime          fillTime;           // Time when gap was filled
   double            fillPrice;          // Price at fill (gapHigh for down, gapLow for up)
   bool              signalPublished;    // Prevent duplicate signals
   int               fillBarIndex;       // Bar index where fill occurred (for buffer writing)
   int               lastScanBar;        // Last bar index scanned for fill (historical)
  };

//--- Active gap tracking
struct ActiveGap
  {
   int               gapIndex;           // Index in m_gaps[] array
   int               lastUpdateBar;      // Last processed bar index (rates_total based)
   bool              isBull;             // true = gap up (buy signal when filled), false = gap down
   double            gapHigh, gapLow;
   datetime          startTime;
   ENUM_GAP_STATE    state;
   bool              signalPublished;
  };

//--- Global arrays
WeekendGapRecord   m_gaps[];            // All detected gaps (historical + current)
ActiveGap          activeGaps[];        // Unfilled gaps being monitored
VisualSettings     m_vis;               // Visual settings (global)
datetime           m_lastBarTime = 0;
bool               m_firstRun = true;
int                atrHandle;           // For ATR-based filtering (optional extension)
double             atrBuffer[];

//--- Helper functions prototypes
string   StateToString(ENUM_GAP_STATE state);
color    ColorSetAlpha(color clr, uchar alpha);
datetime GetWeekMonday(datetime t);
double   PipSize();
datetime GetNextMondayOpen(datetime thisMondayOpenTime);
string   PrefixForIndex(int idx);
void     DeleteWGObjects();
void     DrawSignalArrow(const WeekendGapRecord &gap, string prefix);
void     DrawWeekSeparator(datetime lineTime, int weekNumber);
void     CreateGapObjects(const WeekendGapRecord &gap, string prefix);
void     UpdateGapVisuals(const WeekendGapRecord &gap, string prefix);
void     DetectAllGaps();
void     ComputeHistoricalFills();
void     AddNewGapToActive(int gapIdx);
void     UpdateActiveGaps(int newBarIdx, const double &high[], const double &low[], const double &close[], const datetime &time[]);
void     RemoveActiveGap(int activeIdx);
void     PublishSignal(int gapIdx, int fillBarIdx, double fillPrice, bool isHistorical);
int      FindBarIndexByTime(datetime targetTime, const datetime &timeArray[]);
void     DoAlert(string msg, bool playSound, bool pushNote, bool sendMail);

//+------------------------------------------------------------------+
//| Custom indicator initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Set indicator buffers (EA accessible)
   SetIndexBuffer(0, BufferBuy, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSell, INDICATOR_DATA);
   SetIndexBuffer(2, BufferGapState, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferFillPrice, INDICATOR_CALCULATIONS);

   //--- Arrow plotting properties
   PlotIndexSetInteger(0, PLOT_ARROW, ARROW_UP);
   PlotIndexSetInteger(1, PLOT_ARROW, ARROW_DOWN);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrNONE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrNONE);

   //--- Set series indexing (oldest at 0)
   ArraySetAsSeries(BufferBuy, false);
   ArraySetAsSeries(BufferSell, false);
   ArraySetAsSeries(BufferGapState, false);
   ArraySetAsSeries(BufferFillPrice, false);

   //--- Initialize buffers to EMPTY_VALUE
   ArrayInitialize(BufferBuy, EMPTY_VALUE);
   ArrayInitialize(BufferSell, EMPTY_VALUE);
   ArrayInitialize(BufferGapState, EMPTY_VALUE);
   ArrayInitialize(BufferFillPrice, EMPTY_VALUE);

   //--- Visual settings
   m_vis.activeFillColor    = ActiveFillColor;
   m_vis.activeOutlineColor = ActiveOutlineColor;
   m_vis.reactionColor      = ReactionColor;
   m_vis.memoryOutlineColor = MemoryOutlineColor;
   m_vis.activeFillOpacity  = ActiveFillOpacity;
   m_vis.lineWidth          = LineWidth;
   m_vis.fontSize           = FontSize;

   //--- Optional ATR handle (for future expansion)
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(atrHandle == INVALID_HANDLE)
      Print("Warning: ATR handle creation failed");

   m_firstRun = true;
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   DeleteWGObjects();
   ArrayFree(m_gaps);
   ArrayFree(activeGaps);
  }

//+------------------------------------------------------------------+
//| Main calculation loop (EA-compatible)                            |
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
   if(rates_total < 2)
      return 0;

   //--- For each new bar (from prev_calculated onward), reset buffers to prevent repainting
   for(int i = prev_calculated; i < rates_total; i++)
     {
      BufferBuy[i]       = EMPTY_VALUE;
      BufferSell[i]      = EMPTY_VALUE;
      BufferGapState[i]  = EMPTY_VALUE;
      BufferFillPrice[i] = EMPTY_VALUE;
     }

   //--- First run: full historical scan, fill reconstruction, and active gap initialization
   if(prev_calculated == 0)
     {
      //--- 1. Detect all historical and current gaps
      DetectAllGaps();

      //--- 2. Reconstruct historical fills (scan past price action)
      ComputeHistoricalFills();

      //--- 3. Publish all historical signals into buffers (for backtesting)
      //--- No alerts for historical fills
      for(int g = 0; g < ArraySize(m_gaps); g++)
        {
         if(m_gaps[g].state == GAP_FILLED &&
            m_gaps[g].fillBarIndex >= 0 &&
            m_gaps[g].fillBarIndex < rates_total)
           {
            PublishSignal(g, m_gaps[g].fillBarIndex, m_gaps[g].fillPrice, true);
           }
        }

      //--- 4. Build active gaps list for those not yet filled
      for(int g = 0; g < ArraySize(m_gaps); g++)
        {
         if(m_gaps[g].state != GAP_FILLED)
            AddNewGapToActive(g);
        }

      //--- 5. Create visual objects (only if needed, EA doesn't rely on them)
      if(ShowHistoricalGaps)
        {
         for(int g = 0; g < ArraySize(m_gaps); g++)
            CreateGapObjects(m_gaps[g], PrefixForIndex(g));
        }

      m_firstRun = false;
      return rates_total;
     }

   //--- Incremental update: only new bars have arrived
   int newBars = rates_total - prev_calculated;
   if(newBars <= 0)
      return rates_total;

   //--- For each newly arrived bar, update active gaps (check fills, state changes)
   for(int bar = prev_calculated; bar < rates_total; bar++)
     {
      UpdateActiveGaps(bar, high, low, close, time);
     }

   //--- Also check for newly formed weekend gaps on the latest bar (if Monday open)
   int scanStart = MathMax(0, rates_total - 100);
   for(int i = scanStart; i < rates_total - 1; i++)
     {
      double diffSeconds = (double)(time[i + 1] - time[i]);
      if(diffSeconds >= 172800)
        {
         double fridayClose = close[i];
         double mondayOpen  = open[i + 1];
         double gapPips     = MathAbs(mondayOpen - fridayClose) / PipSize();

         if(gapPips >= MinGapPips)
           {
            bool exists = false;
            for(int g = 0; g < ArraySize(m_gaps); g++)
              {
               if(m_gaps[g].startTime == time[i + 1])
                 {
                  exists = true;
                  break;
                 }
              }

            if(!exists)
              {
               WeekendGapRecord newGap;
               newGap.startTime       = time[i + 1];
               newGap.endTime         = GetNextMondayOpen(time[i + 1]);
               newGap.gapHigh         = MathMax(mondayOpen, fridayClose);
               newGap.gapLow          = MathMin(mondayOpen, fridayClose);
               newGap.midpoint        = (newGap.gapHigh + newGap.gapLow) / 2.0;
               newGap.isGapDown       = (fridayClose > mondayOpen);
               newGap.activeWeek      = (GetWeekMonday(time[i + 1]) == GetWeekMonday(TimeCurrent()));
               newGap.state           = newGap.activeWeek ? GAP_FRESH : GAP_HISTORICAL;
               newGap.fillTime        = 0;
               newGap.fillPrice       = 0;
               newGap.signalPublished = false;
               newGap.fillBarIndex    = -1;
               newGap.lastScanBar     = 0;

               int idx = ArraySize(m_gaps);
               ArrayResize(m_gaps, idx + 1);
               m_gaps[idx] = newGap;

               if(newGap.state != GAP_FILLED)
                  AddNewGapToActive(idx);

               if(ShowHistoricalGaps)
                  CreateGapObjects(m_gaps[idx], PrefixForIndex(idx));
              }
           }
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| Detect all gaps (historical and current)                         |
//+------------------------------------------------------------------+
void DetectAllGaps()
  {
   ArrayResize(m_gaps, 0);
   int bars = Bars(_Symbol, _Period);
   if(bars < 2)
      return;

   datetime timeArr[];
   double openArr[], closeArr[];
   ArraySetAsSeries(timeArr, true);
   ArraySetAsSeries(openArr, true);
   ArraySetAsSeries(closeArr, true);

   if(CopyTime(_Symbol, _Period, 0, bars, timeArr) <= 0) return;
   if(CopyOpen(_Symbol, _Period, 0, bars, openArr) <= 0) return;
   if(CopyClose(_Symbol, _Period, 0, bars, closeArr) <= 0) return;

   double pip = PipSize();
   int limit = MathMin(bars - 1, 10000);
   datetime currentWeek = GetWeekMonday(TimeCurrent());

   for(int i = 1; i < limit; i++)
     {
      double diffSeconds = (double)(timeArr[i - 1] - timeArr[i]);
      if(diffSeconds >= 172800)
        {
         double fridayClose = closeArr[i];
         double mondayOpen  = openArr[i - 1];
         double gapPips     = MathAbs(mondayOpen - fridayClose) / pip;

         if(gapPips >= MinGapPips)
           {
            WeekendGapRecord gap;
            gap.startTime       = timeArr[i - 1];
            gap.endTime         = GetNextMondayOpen(timeArr[i - 1]);
            gap.gapHigh         = MathMax(mondayOpen, fridayClose);
            gap.gapLow          = MathMin(mondayOpen, fridayClose);
            gap.midpoint        = (gap.gapHigh + gap.gapLow) / 2.0;
            gap.isGapDown       = (fridayClose > mondayOpen);
            gap.activeWeek      = (GetWeekMonday(timeArr[i - 1]) == currentWeek);
            gap.state           = gap.activeWeek ? GAP_FRESH : GAP_HISTORICAL;
            gap.fillTime        = 0;
            gap.fillPrice       = 0;
            gap.signalPublished = false;
            gap.fillBarIndex    = -1;
            gap.lastScanBar     = 0;

            int size = ArraySize(m_gaps);
            ArrayResize(m_gaps, size + 1);
            m_gaps[size] = gap;
           }
        }
     }

   Print("Weekend Gap Indicator: Detected ", ArraySize(m_gaps), " gaps.");
  }

//+------------------------------------------------------------------+
//| Scan historical price action to find fills for past gaps         |
//+------------------------------------------------------------------+
void ComputeHistoricalFills()
  {
   for(int g = 0; g < ArraySize(m_gaps); g++)
     {
      if(m_gaps[g].state == GAP_FILLED)
         continue;
      if(m_gaps[g].activeWeek)
         continue;

      datetime from = m_gaps[g].startTime;
      datetime to   = TimeCurrent();
      int startBar  = m_gaps[g].lastScanBar;

      double high[], low[];
      datetime timeHist[];
      if(CopyHigh(_Symbol, _Period, from, to, high) <= 0) continue;
      if(CopyLow(_Symbol, _Period, from, to, low) <= 0) continue;
      if(CopyTime(_Symbol, _Period, from, to, timeHist) <= 0) continue;

      ArraySetAsSeries(high, false);
      ArraySetAsSeries(low, false);
      ArraySetAsSeries(timeHist, false);

      for(int i = startBar; i < ArraySize(timeHist); i++)
        {
         if(timeHist[i] < from)
            continue;

         if(m_gaps[g].isGapDown)
           {
            if(high[i] >= m_gaps[g].gapHigh)
              {
               m_gaps[g].state         = GAP_FILLED;
               m_gaps[g].fillTime      = timeHist[i];
               m_gaps[g].fillPrice     = m_gaps[g].gapHigh;
               m_gaps[g].fillBarIndex  = FindBarIndexByTime(timeHist[i], timeHist);
               break;
              }
           }
         else
           {
            if(low[i] <= m_gaps[g].gapLow)
              {
               m_gaps[g].state         = GAP_FILLED;
               m_gaps[g].fillTime      = timeHist[i];
               m_gaps[g].fillPrice     = m_gaps[g].gapLow;
               m_gaps[g].fillBarIndex  = FindBarIndexByTime(timeHist[i], timeHist);
               break;
              }
           }

         m_gaps[g].lastScanBar = i + 1;
        }
     }
  }

//+------------------------------------------------------------------+
//| Add a gap to the active monitoring array                         |
//+------------------------------------------------------------------+
void AddNewGapToActive(int gapIdx)
  {
   int sz = ArraySize(activeGaps);
   ArrayResize(activeGaps, sz + 1);
   activeGaps[sz].gapIndex         = gapIdx;
   activeGaps[sz].lastUpdateBar    = -1;
   activeGaps[sz].isBull           = !m_gaps[gapIdx].isGapDown;
   activeGaps[sz].gapHigh          = m_gaps[gapIdx].gapHigh;
   activeGaps[sz].gapLow           = m_gaps[gapIdx].gapLow;
   activeGaps[sz].startTime        = m_gaps[gapIdx].startTime;
   activeGaps[sz].state            = m_gaps[gapIdx].state;
   activeGaps[sz].signalPublished  = m_gaps[gapIdx].signalPublished;
  }

//+------------------------------------------------------------------+
//| Update all active gaps based on new bar data                     |
//+------------------------------------------------------------------+
void UpdateActiveGaps(int newBarIdx, const double &high[], const double &low[], const double &close[], const datetime &time[])
  {
   for(int a = ArraySize(activeGaps) - 1; a >= 0; a--)
     {
      int gapIdx = activeGaps[a].gapIndex;

      if(m_gaps[gapIdx].state == GAP_FILLED)
        {
         RemoveActiveGap(a);
         continue;
        }

      if(time[newBarIdx] < m_gaps[gapIdx].startTime)
         continue;

      double currentPrice = close[newBarIdx];
      bool isGapDown      = m_gaps[gapIdx].isGapDown;
      double gHigh        = m_gaps[gapIdx].gapHigh;
      double gLow         = m_gaps[gapIdx].gapLow;
      ENUM_GAP_STATE newState = m_gaps[gapIdx].state;

      if(isGapDown)
        {
         if(currentPrice > gHigh)
            newState = GAP_FILLED;
         else if(currentPrice > gLow && currentPrice <= gHigh)
            newState = (newState == GAP_FRESH || newState == GAP_REACTION) ? GAP_PARTIAL : newState;
         else if(currentPrice <= gLow)
            newState = GAP_REACTION;
        }
      else
        {
         if(currentPrice < gLow)
            newState = GAP_FILLED;
         else if(currentPrice >= gLow && currentPrice < gHigh)
            newState = (newState == GAP_FRESH || newState == GAP_REACTION) ? GAP_PARTIAL : newState;
         else if(currentPrice >= gHigh)
            newState = GAP_REACTION;
        }

      if(newState != m_gaps[gapIdx].state)
        {
         m_gaps[gapIdx].state   = newState;
         activeGaps[a].state    = newState;

         if(newState == GAP_FILLED)
           {
            m_gaps[gapIdx].fillTime      = time[newBarIdx];
            m_gaps[gapIdx].fillPrice     = isGapDown ? gHigh : gLow;
            m_gaps[gapIdx].fillBarIndex  = newBarIdx;

            if(!m_gaps[gapIdx].signalPublished)
              {
               PublishSignal(gapIdx, newBarIdx, m_gaps[gapIdx].fillPrice, false);
               m_gaps[gapIdx].signalPublished   = true;
               activeGaps[a].signalPublished    = true;
              }

            RemoveActiveGap(a);
            continue;
           }

         if(ShowHistoricalGaps)
            UpdateGapVisuals(m_gaps[gapIdx], PrefixForIndex(gapIdx));
        }

      activeGaps[a].lastUpdateBar = newBarIdx;
     }
  }

//+------------------------------------------------------------------+
//| Remove an active gap from the array (swap with last)             |
//+------------------------------------------------------------------+
void RemoveActiveGap(int activeIdx)
  {
   int last = ArraySize(activeGaps) - 1;
   if(activeIdx != last)
      activeGaps[activeIdx] = activeGaps[last];
   ArrayResize(activeGaps, last);
  }

//+------------------------------------------------------------------+
//| Publish signal into indicator buffers at the given bar index     |
//+------------------------------------------------------------------+
void PublishSignal(int gapIdx, int fillBarIdx, double fillPrice, bool isHistorical)
  {
   bool isGapUp   = !m_gaps[gapIdx].isGapDown;
   bool buySignal = InvertSignals ? !isGapUp : isGapUp;

   if(buySignal)
     {
      if(fillBarIdx < ArraySize(BufferBuy))
        {
         BufferBuy[fillBarIdx]       = fillPrice;
         BufferGapState[fillBarIdx]  = (double)GAP_FILLED;
         BufferFillPrice[fillBarIdx] = fillPrice;
        }
     }
   else
     {
      if(fillBarIdx < ArraySize(BufferSell))
        {
         BufferSell[fillBarIdx]      = fillPrice;
         BufferGapState[fillBarIdx]  = (double)GAP_FILLED;
         BufferFillPrice[fillBarIdx] = fillPrice;
        }
     }

   //--- Visual arrow (only if ShowHistoricalGaps is true)
   if(ShowHistoricalGaps)
      DrawSignalArrow(m_gaps[gapIdx], PrefixForIndex(gapIdx));

   //--- Alerts & log for real-time fills only
   if(!isHistorical)
     {
      string signalType = buySignal ? "BUY" : "SELL";
      string msg = StringFormat("Weekend Gap %s Signal on %s %s at %s (Price: %.5f)",
                                signalType, _Symbol, EnumToString(Period()),
                                TimeToString(TimeCurrent()), fillPrice);
      DoAlert(msg, EnableSound, EnableNotification, EnableEmail);
      Print(msg);
     }
  }

//+------------------------------------------------------------------+
//| Send alerts (popup, sound, push, email)                          |
//+------------------------------------------------------------------+
void DoAlert(string msg, bool playSound, bool pushNote, bool sendMail)
  {
   if(!EnableAlerts)
      return;
   Alert(msg);
   if(playSound)
      PlaySound(SoundFile);
   if(pushNote)
      SendNotification(msg);
   if(sendMail)
      SendMail("Weekend Gap Indicator Alert", msg);
  }

//+------------------------------------------------------------------+
//| Find bar index by approximate time (for historical fills)        |
//+------------------------------------------------------------------+
int FindBarIndexByTime(datetime targetTime, const datetime &timeArray[])
  {
   for(int i = 0; i < ArraySize(timeArray); i++)
      if(timeArray[i] == targetTime)
         return i;
   return -1;
  }

//+------------------------------------------------------------------+
//| Helper: Convert state to string                                  |
//+------------------------------------------------------------------+
string StateToString(ENUM_GAP_STATE state)
  {
   switch(state)
     {
      case GAP_FRESH:      return "FRESH";
      case GAP_PARTIAL:    return "PARTIAL";
      case GAP_REACTION:   return "REACTION";
      case GAP_FILLED:     return "FILLED";
      case GAP_HISTORICAL: return "HIST";
     }
   return "";
  }

//+------------------------------------------------------------------+
//| Helper: Apply alpha to color (for rectangle fill)                |
//+------------------------------------------------------------------+
color ColorSetAlpha(color clr, uchar alpha)
  {
   return (color)((clr & 0x00FFFFFF) | ((uint)alpha << 24));
  }

//+------------------------------------------------------------------+
//| Helper: Get Monday 00:00 of the week containing t                |
//+------------------------------------------------------------------+
datetime GetWeekMonday(datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int daysSinceMonday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   return t - daysSinceMonday * 86400 - (t % 86400);
  }

//+------------------------------------------------------------------+
//| Helper: Pip size based on digits                                 |
//+------------------------------------------------------------------+
double PipSize()
  {
   return (_Digits == 3 || _Digits == 5) ? (_Point * 10.0) : _Point;
  }

//+------------------------------------------------------------------+
//| Helper: Next Monday open time (00:00)                            |
//+------------------------------------------------------------------+
datetime GetNextMondayOpen(datetime thisMondayOpenTime)
  {
   return thisMondayOpenTime + 7 * 86400;
  }

//+------------------------------------------------------------------+
//| Helper: Unique object name prefix for a gap index                |
//+------------------------------------------------------------------+
string PrefixForIndex(int idx)
  {
   return "WG_" + IntegerToString(idx);
  }

//+------------------------------------------------------------------+
//| Delete all indicator-created objects                              |
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
//| Draw an arrow on chart when gap fills (visual only)              |
//+------------------------------------------------------------------+
void DrawSignalArrow(const WeekendGapRecord &gap, string prefix)
  {
   if(gap.state != GAP_FILLED || gap.fillTime == 0)
      return;
   if(ObjectFind(0, prefix + "_ARROW") >= 0)
      return;

   bool defaultIsBuy = !gap.isGapDown;
   bool isBuy = InvertSignals ? !defaultIsBuy : defaultIsBuy;

   ObjectCreate(0, prefix + "_ARROW", OBJ_ARROW, 0, gap.fillTime, gap.fillPrice);
   ObjectSetInteger(0, prefix + "_ARROW", OBJPROP_COLOR, isBuy ? BuyArrowColor : SellArrowColor);
   ObjectSetInteger(0, prefix + "_ARROW", OBJPROP_WIDTH, ArrowSize);
   ObjectSetInteger(0, prefix + "_ARROW", OBJPROP_ANCHOR, isBuy ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetInteger(0, prefix + "_ARROW", OBJPROP_ARROWCODE, isBuy ? 233 : 234);
  }

//+------------------------------------------------------------------+
//| Create visual objects for a gap (rectangle, text, etc.)          |
//+------------------------------------------------------------------+
void CreateGapObjects(const WeekendGapRecord &gap, string prefix)
  {
   if(!ShowHistoricalGaps)
      return;

   if(DrawWeekSeparators)
     {
      int weekNum = (int)(gap.startTime / 86400 / 7);
      DrawWeekSeparator(gap.startTime, weekNum);
     }

   datetime leftTime   = gap.startTime;
   datetime rightEdge  = GetNextMondayOpen(gap.startTime);
   long     weekLength  = rightEdge - leftTime;
   double   mid         = (gap.gapHigh + gap.gapLow) / 2.0;

   //--- Rectangle – placed behind bars
   ObjectCreate(0, prefix + "_RECT", OBJ_RECTANGLE, 0, leftTime, gap.gapHigh, rightEdge, gap.gapLow);
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_COLOR, m_vis.activeOutlineColor);
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_WIDTH, m_vis.lineWidth);
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_FILL, true);
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_BGCOLOR, ColorSetAlpha(m_vis.activeFillColor, (uchar)(m_vis.activeFillOpacity * 255 / 100)));
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_BACK, true);

   //--- Mid line (also behind)
   ObjectCreate(0, prefix + "_MID", OBJ_TREND, 0, leftTime, mid, rightEdge, mid);
   ObjectSetInteger(0, prefix + "_MID", OBJPROP_COLOR, clrDarkGray);
   ObjectSetInteger(0, prefix + "_MID", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, prefix + "_MID", OBJPROP_BACK, true);

   //--- Main label (stays on top)
   double pipDist = (gap.gapHigh - gap.gapLow) / PipSize();
   string text = StringFormat("WG | %.1fp | %s", pipDist, StateToString(gap.state));
   datetime mainLabelTime = (datetime)(leftTime + (long)(weekLength * 0.25));
   ObjectCreate(0, prefix + "_LBL", OBJ_TEXT, 0, mainLabelTime, mid);
   ObjectSetString(0, prefix + "_LBL", OBJPROP_TEXT, text);
   ObjectSetInteger(0, prefix + "_LBL", OBJPROP_FONTSIZE, m_vis.fontSize);
   ObjectSetInteger(0, prefix + "_LBL", OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, prefix + "_LBL", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, prefix + "_LBL", OBJPROP_ANCHOR, ANCHOR_CENTER);

   if(ShowDetailedLabels)
     {
      datetime detailTime = (datetime)(leftTime + (long)(weekLength * 0.05));
      double gapHeight = gap.gapHigh - gap.gapLow;
      double offset    = gapHeight * 0.1;
      int smallFont    = MathMax(m_vis.fontSize - 1, 6);
      double friPrice  = gap.isGapDown ? gap.gapHigh : gap.gapLow;
      string friText   = StringFormat("Fri Close: %." + IntegerToString(_Digits) + "f", friPrice);
      ObjectCreate(0, prefix + "_TOP", OBJ_TEXT, 0, detailTime, gap.gapHigh - offset);
      ObjectSetString(0, prefix + "_TOP", OBJPROP_TEXT, friText);
      ObjectSetInteger(0, prefix + "_TOP", OBJPROP_FONTSIZE, smallFont);
      ObjectSetInteger(0, prefix + "_TOP", OBJPROP_COLOR, clrWhite);

      double monPrice = gap.isGapDown ? gap.gapLow : gap.gapHigh;
      string monText  = StringFormat("Mon Open: %." + IntegerToString(_Digits) + "f", monPrice);
      ObjectCreate(0, prefix + "_BOT", OBJ_TEXT, 0, detailTime, gap.gapLow + offset);
      ObjectSetString(0, prefix + "_BOT", OBJPROP_TEXT, monText);
      ObjectSetInteger(0, prefix + "_BOT", OBJPROP_FONTSIZE, smallFont);
      ObjectSetInteger(0, prefix + "_BOT", OBJPROP_COLOR, clrWhite);

      string midText = StringFormat("Mid: %." + IntegerToString(_Digits) + "f", gap.midpoint);
      ObjectCreate(0, prefix + "_MIDPRICE", OBJ_TEXT, 0, detailTime, gap.midpoint);
      ObjectSetString(0, prefix + "_MIDPRICE", OBJPROP_TEXT, midText);
      ObjectSetInteger(0, prefix + "_MIDPRICE", OBJPROP_FONTSIZE, smallFont);
      ObjectSetInteger(0, prefix + "_MIDPRICE", OBJPROP_COLOR, clrWhite);
     }
  }

//+------------------------------------------------------------------+
//| Update visual objects based on gap state                         |
//+------------------------------------------------------------------+
void UpdateGapVisuals(const WeekendGapRecord &gap, string prefix)
  {
   if(!ShowHistoricalGaps)
      return;
   if(ObjectFind(0, prefix + "_RECT") < 0)
      return;

   if(!gap.activeWeek || gap.state == GAP_HISTORICAL)
     {
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_COLOR, m_vis.memoryOutlineColor);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_FILL, false);

      if(ObjectFind(0, prefix + "_LBL") >= 0)
        {
         ObjectSetInteger(0, prefix + "_LBL", OBJPROP_COLOR, clrDimGray);
         ObjectSetString(0, prefix + "_LBL", OBJPROP_FONT, "Arial");
        }
     }
   else
     {
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_COLOR, m_vis.activeOutlineColor);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_WIDTH, m_vis.lineWidth);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_FILL, true);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_BGCOLOR, ColorSetAlpha(m_vis.activeFillColor, (uchar)(m_vis.activeFillOpacity * 255 / 100)));

      if(ObjectFind(0, prefix + "_LBL") >= 0)
        {
         ObjectSetInteger(0, prefix + "_LBL", OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, prefix + "_LBL", OBJPROP_FONT, "Arial Bold");
        }
     }

   if(ObjectFind(0, prefix + "_LBL") >= 0)
     {
      double pipDist = (gap.gapHigh - gap.gapLow) / PipSize();
      string text = StringFormat("WG | %.1fp | %s", pipDist, StateToString(gap.state));
      ObjectSetString(0, prefix + "_LBL", OBJPROP_TEXT, text);
     }
  }
//+------------------------------------------------------------------+
