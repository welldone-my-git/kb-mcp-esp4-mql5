//+------------------------------------------------------------------+
//|                                                      CHANNEL.mq5 |
//|                                   Copyright 2026, MetaQuotes Ltd.|
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

//--- Input groups
input group "==== SWING DETECTION ===="
input int    SwingLookback = 3;
input double MinSwingSize = 0.0001;
input bool   UseATRFiltering = false;
input double SwingSizeATRFactor = 0.8;
input bool   ShowSwingPoints = true;
input bool   ShowSwingLabels = false;

input group "==== CHANNEL PARAMETERS ===="
input int    MinTouchPointsRequired = 2;
input int    MinRecentTouches = 0;
input int    RecentTouchBars = 50;
input double MaxSlopeDifference = 0.2;
input double MinChannelWidthATR = 0.2;
input double TouchToleranceATR = 0.3;
input int    MaxBarsToAnalyze = 150;
input bool   ExtendToRightEdge = false;      // now only affects zones, not lines
input bool   ShowLowReferenceCrosses = false;

input group "==== BREAKOUT SIGNALS ===="
input bool   EnableBreakoutSignals = true;
input bool   BreakoutUseClose = true;
input int    BreakoutBufferPoints = 5;
input double BreakoutMinStrengthATR = 0.0;
input int    BreakoutConfirmationBars = 1;
input bool   BreakoutStrictMode = true;
input double BreakoutStrongThreshold = 2.0;
input bool   AlertOnBreakout = true;
input bool   PermanentArrows = true;
input int    ArrowSize = 2;
input color  BullArrowColor = clrLimeGreen;
input color  BearArrowColor = clrRed;

input group "==== CORE AUTHENTICITY ENHANCEMENTS ===="
input bool   UseMarketRegimeFilter = false;
input double MinTrendStrengthATR = 1.5;
input bool   UseStructuralBreak = true;
input bool   UseLiquiditySweepFilter = true;
input bool   UseRetestMode = false;
input bool   UseVolatilityExpansion = true;
input double MinVolatilityExpansion = 1.3;

input group "==== VISUAL AUTHENTICITY UPGRADES ===="
input bool   UseBreakoutZones = true;
input color  BullZoneColor = clrLime;
input color  BearZoneColor = clrRed;
input uchar  ZoneTransparency = 128;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "==== VISUAL SETTINGS (LINE/POINT COLORS) ===="
input color  UpperLineColor = clrDodgerBlue;
input color  LowerLineColor = clrOrange;
input color  SwingHighColor = clrRed;
input color  SwingLowColor = clrLime;
input int    LineWidth = 2;
input ENUM_LINE_STYLE LineStyle = STYLE_SOLID;
input int    LineExtensionBars = 30;          // extend lines this many bars into future

input group "==== SIGNAL FILTERS ===="
input bool   UseChannelTypeFilter = false;

input group "==== DEBUG ===="
input bool   DebugMode = false;

//--- Prefixes
string TL_PREFIX  = "CHAN_";
string SIG_PREFIX = "SIG_";
string ZONE_PREFIX = "ZONE_";

//--- Globals
int    atrHandle = INVALID_HANDLE;
double currentATR = 0.0001;
double atrBuffer[20];

//--- Structures
struct SwingPoint
  {
   datetime          time;
   double            price;
   int               barIndex;
   double            size;
   bool              isHigh;
   int               order;
  };

struct PendingBreakout
  {
   datetime          breakoutTime;
   double            price;
   bool              isBullish;
   double            linePrice;
   int               totalTouches;
   double            channelSlope;
   double            channelWidth;
   SwingPoint        high1, high2;
  };

struct BreakoutInfo
  {
   datetime          time;
   double            price;
   bool              isBullish;
   int               totalTouches;
  };

enum ChannelType
  {
   ASCENDING,
   DESCENDING,
   HORIZONTAL
  };

enum StrengthGrade
  {
   HIGH,
   MEDIUM,
   LOW
  };

struct Channel
  {
   SwingPoint        high1, high2;
   SwingPoint        low1, low2;
   double            slope;
   double            width;
   int               highTouches, lowTouches;
   double            score;
   ChannelType       type;
   StrengthGrade     strength;
  };

//--- Global arrays
PendingBreakout pendingBreakouts[];
int pendingCount = 0;
BreakoutInfo breakoutsArray[];
int breakoutsCount = 0;

//+------------------------------------------------------------------+
//| Function Prototypes                                              |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix);
double BreakoutBufferPrice();
void InitSwingPoint(SwingPoint &sp, bool isHigh);
double LinePriceAtTime(const SwingPoint &a,const SwingPoint &b,datetime t);
int CountTouchesOnLine(const SwingPoint &a,const SwingPoint &b,
                       const SwingPoint &swings[],int swingCount,
                       bool isUpperLine,double tolerance,
                       int recentBars,int &recentCount);
void GetLastSwing(const SwingPoint &highs[],int highCount,
                  const SwingPoint &lows[],int lowCount,
                  SwingPoint &lastHigh,SwingPoint &lastLow);
void DrawBreakoutZone(datetime time,double priceLow,double priceHigh,bool isBullish,int totalTouches);
void DrawPermanentArrow(datetime time,double price,bool isBullish,int totalTouches,double low=0,double high=0);
void RedrawPermanentArrows();
void CheckRetests();
bool FindBestChannel(const SwingPoint &highs[],int highCount,
                     const SwingPoint &lows[],int lowCount,
                     const MqlRates &rates[],int totalBars,
                     Channel &bestChannel);
void DrawChannel(const Channel &ch);
void DrawBestChannel();
void FindSignificantSwings(const MqlRates &rates[],int totalBars,
                           SwingPoint &highs[],int &highCount,
                           SwingPoint &lows[],int &lowCount);
void AssignSwingOrder(SwingPoint &swings[],int count);
void DrawSwingPoints(const SwingPoint &highs[],int highCount,
                     const SwingPoint &lows[],int lowCount);
void CheckChannelBreakouts(const MqlRates &rates[],const Channel &ch,
                           const SwingPoint &highs[],int highCount,
                           const SwingPoint &lows[],int lowCount);
ChannelType ClassifyChannel(double slope);
StrengthGrade GradeStrength(int totalTouches);

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(UseATRFiltering || UseVolatilityExpansion)
      atrHandle = iATR(_Symbol,_Period,14);

   DeleteObjectsByPrefix(TL_PREFIX);
   DeleteObjectsByPrefix(ZONE_PREFIX);
   ArrayResize(breakoutsArray,100);
   breakoutsCount = 0;
   pendingCount = 0;

   if(DebugMode)
      Print("Parallel Channel Breakout v4.8 initialized (lines extended, touch counting fixed)");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteObjectsByPrefix(TL_PREFIX);
   DeleteObjectsByPrefix(ZONE_PREFIX);
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   Print("Deinit: channel and zone objects removed, permanent arrows preserved.");
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol,_Period,0);

   if(currentBarTime == lastBarTime && lastBarTime != 0)
      return;

   lastBarTime = currentBarTime;

//--- Update ATR
   if((UseATRFiltering || UseVolatilityExpansion) && atrHandle != INVALID_HANDLE)
     {
      double atrTemp[1];
      if(CopyBuffer(atrHandle,0,0,1,atrTemp) > 0)
         currentATR = atrTemp[0];
      CopyBuffer(atrHandle,0,0,20,atrBuffer);
     }

   DeleteObjectsByPrefix(TL_PREFIX);
   DeleteObjectsByPrefix(ZONE_PREFIX);

   bool marketTrending = true;
   if(UseMarketRegimeFilter)
     {
      double high = iHigh(_Symbol,_Period,0);
      double low  = iLow(_Symbol,_Period,0);
      double range = high - low;
      marketTrending = (range >= MinTrendStrengthATR * currentATR);
      if(!marketTrending && DebugMode)
         Print("Market regime: low volatility – channel scan skipped.");
     }

   if(marketTrending)
      DrawBestChannel();

   if(UseRetestMode && pendingCount > 0)
      CheckRetests();

   RedrawPermanentArrows();
  }

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Delete all chart objects with a given prefix                     |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
  {
   int total = ObjectsTotal(0,-1,-1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0,i,-1,-1);
      if(StringLen(name) >= StringLen(prefix) && StringSubstr(name,0,StringLen(prefix)) == prefix)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
//| Returns buffer price based on BreakoutBufferPoints               |
//+------------------------------------------------------------------+
double BreakoutBufferPrice()
  {
   return (double)BreakoutBufferPoints * _Point;
  }

//+------------------------------------------------------------------+
//| Initializes a swing point structure                              |
//+------------------------------------------------------------------+
void InitSwingPoint(SwingPoint &sp,bool isHigh=true)
  {
   sp.time = 0;
   sp.price = 0.0;
   sp.barIndex = 0;
   sp.size = 0.0;
   sp.isHigh = isHigh;
   sp.order = 0;
  }

//+------------------------------------------------------------------+
//| Calculate price on a line defined by two swings at time t        |
//+------------------------------------------------------------------+
double LinePriceAtTime(const SwingPoint &a,const SwingPoint &b,datetime t)
  {
   double dt = (double)(b.time - a.time);
   if(dt == 0.0)
      return a.price;
   double slope = (b.price - a.price) / dt;
   return a.price + slope * (double)(t - a.time);
  }

//+------------------------------------------------------------------+
//| Count touches on a trendline (upper or lower)                    |
//+------------------------------------------------------------------+
int CountTouchesOnLine(const SwingPoint &a,const SwingPoint &b,
                       const SwingPoint &swings[],int swingCount,
                       bool isUpperLine,double tolerance,
                       int recentBars,int &recentCount)
  {
   int touches = 2;               // the two anchor swings
   recentCount = 0;
   double timeDiff = (double)(b.time - a.time);
   if(timeDiff <= 0)
      return touches;
   double slope = (b.price - a.price) / timeDiff;

   for(int i=0; i<swingCount; i++)
     {
      if(swings[i].time == a.time || swings[i].time == b.time)
         continue;
      if(swings[i].time < a.time || swings[i].time > b.time)
         continue;

      double linePrice = a.price + slope * (swings[i].time - a.time);
      double distance = isUpperLine ? linePrice - swings[i].price   // positive if swing below line
                        : swings[i].price - linePrice; // positive if swing above line

      //--- For upper line, only swings BELOW (or exactly on) the line are valid touches.
      //--- For lower line, only swings ABOVE (or exactly on) the line are valid touches.
      bool correctSide = (isUpperLine && distance >= -tolerance) ||
                         (!isUpperLine && distance >= -tolerance);

      if(correctSide && MathAbs(distance) <= tolerance)
        {
         touches++;
         if(swings[i].barIndex <= recentBars)
            recentCount++;
        }
     }
   return touches;
  }

//+------------------------------------------------------------------+
//| Get the most recent swing highs and lows                         |
//+------------------------------------------------------------------+
void GetLastSwing(const SwingPoint &highs[],int highCount,
                  const SwingPoint &lows[],int lowCount,
                  SwingPoint &lastHigh,SwingPoint &lastLow)
  {
   lastHigh.time = 0;
   lastLow.time = 0;
   for(int i=0; i<highCount; i++)
      if(highs[i].time > lastHigh.time)
         lastHigh = highs[i];
   for(int i=0; i<lowCount; i++)
      if(lows[i].time > lastLow.time)
         lastLow = lows[i];
  }

//+------------------------------------------------------------------+
//| Draw a breakout zone rectangle                                   |
//+------------------------------------------------------------------+
void DrawBreakoutZone(datetime time,double priceLow,double priceHigh,bool isBullish,int totalTouches)
  {
   string zoneName = ZONE_PREFIX + (isBullish ? "BUY_" : "SELL_") + IntegerToString((int)time);
   if(ObjectFind(0,zoneName) >= 0)
      return;

   datetime endTime = ExtendToRightEdge ? TimeCurrent() : time + PeriodSeconds(_Period);

   if(!ObjectCreate(0,zoneName,OBJ_RECTANGLE,0,time,priceLow,endTime,priceHigh))
     {
      if(DebugMode)
         Print("Failed to create breakout zone: ",GetLastError());
      return;
     }

   color zoneColor = isBullish ? BullZoneColor : BearZoneColor;
   ObjectSetInteger(0,zoneName,OBJPROP_COLOR,zoneColor);
   ObjectSetInteger(0,zoneName,OBJPROP_FILL,true);
   ObjectSetInteger(0,zoneName,OBJPROP_BACK,true);
   ObjectSetInteger(0,zoneName,OBJPROP_WIDTH,0);
   ObjectSetInteger(0,zoneName,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,zoneName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,zoneName,OBJPROP_HIDDEN,true);
  }

//+------------------------------------------------------------------+
//| Draw a permanent arrow (signal)                                  |
//+------------------------------------------------------------------+
void DrawPermanentArrow(datetime time,double price,bool isBullish,int totalTouches,double low=0,double high=0)
  {
   string arrowName = SIG_PREFIX + (isBullish ? "BUY_" : "SELL_") +
                      IntegerToString((int)time) + "_" + IntegerToString(totalTouches);

   if(ObjectFind(0,arrowName) >= 0)
      return;

   if(!ObjectCreate(0,arrowName,OBJ_ARROW,0,time,price))
     {
      if(DebugMode)
         Print("Failed to create arrow: ",GetLastError());
      return;
     }

   ObjectSetInteger(0,arrowName,OBJPROP_ARROWCODE,isBullish ? 233 : 234);
   ObjectSetInteger(0,arrowName,OBJPROP_COLOR,isBullish ? BullArrowColor : BearArrowColor);
   ObjectSetInteger(0,arrowName,OBJPROP_WIDTH,ArrowSize);
   ObjectSetInteger(0,arrowName,OBJPROP_BACK,false);
   ObjectSetInteger(0,arrowName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,arrowName,OBJPROP_HIDDEN,true);

   string desc = "Channel Breakout " + (isBullish ? "BULLISH" : "BEARISH") +
                 " (" + IntegerToString(totalTouches) + " touches)";
   ObjectSetString(0,arrowName,OBJPROP_TEXT,desc);

   if(UseBreakoutZones && high > low)
      DrawBreakoutZone(time,low,high,isBullish,totalTouches);

   if(breakoutsCount >= ArraySize(breakoutsArray))
      ArrayResize(breakoutsArray,breakoutsCount + 10);

   breakoutsArray[breakoutsCount].time = time;
   breakoutsArray[breakoutsCount].price = price;
   breakoutsArray[breakoutsCount].isBullish = isBullish;
   breakoutsArray[breakoutsCount].totalTouches = totalTouches;
   breakoutsCount++;
  }

//+------------------------------------------------------------------+
//| Redraw all permanent arrows (after chart refresh)                |
//+------------------------------------------------------------------+
void RedrawPermanentArrows()
  {
   if(!PermanentArrows)
      return;

   for(int i=0; i<breakoutsCount; i++)
     {
      string arrowName = SIG_PREFIX + (breakoutsArray[i].isBullish ? "BUY_" : "SELL_") +
                         IntegerToString((int)breakoutsArray[i].time) + "_" +
                         IntegerToString(breakoutsArray[i].totalTouches);

      if(ObjectFind(0,arrowName) < 0)
        {
         if(ObjectCreate(0,arrowName,OBJ_ARROW,0,breakoutsArray[i].time,breakoutsArray[i].price))
           {
            ObjectSetInteger(0,arrowName,OBJPROP_ARROWCODE,breakoutsArray[i].isBullish ? 233 : 234);
            ObjectSetInteger(0,arrowName,OBJPROP_COLOR,breakoutsArray[i].isBullish ? BullArrowColor : BearArrowColor);
            ObjectSetInteger(0,arrowName,OBJPROP_WIDTH,ArrowSize);
            ObjectSetInteger(0,arrowName,OBJPROP_BACK,false);
            ObjectSetInteger(0,arrowName,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,arrowName,OBJPROP_HIDDEN,true);

            string desc = "Channel Breakout " + (breakoutsArray[i].isBullish ? "BULLISH" : "BEARISH") +
                          " (" + IntegerToString(breakoutsArray[i].totalTouches) + " touches)";
            ObjectSetString(0,arrowName,OBJPROP_TEXT,desc);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Check for retests of pending breakouts                           |
//+------------------------------------------------------------------+
void CheckRetests()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int bars = CopyRates(_Symbol,_Period,0,5,rates);
   if(bars < 2)
      return;

   for(int i=pendingCount-1; i>=0; i--)
     {
      datetime lastBarTime = rates[1].time;
      if(lastBarTime <= pendingBreakouts[i].breakoutTime)
         continue;

      double upper = LinePriceAtTime(pendingBreakouts[i].high1,pendingBreakouts[i].high2,lastBarTime);
      double lower = upper - pendingBreakouts[i].channelWidth;
      double close = rates[1].close;

      bool retest = false;
      double arrowPrice = 0;
      if(pendingBreakouts[i].isBullish)
        {
         if(close <= upper + currentATR*0.1 && close >= upper - currentATR*0.1)
           {
            retest = true;
            arrowPrice = rates[1].low - currentATR*0.15;
           }
        }
      else
        {
         if(close >= lower - currentATR*0.1 && close <= lower + currentATR*0.1)
           {
            retest = true;
            arrowPrice = rates[1].high + currentATR*0.15;
           }
        }

      if(retest)
        {
         DrawPermanentArrow(lastBarTime,arrowPrice,pendingBreakouts[i].isBullish,pendingBreakouts[i].totalTouches,rates[1].low,rates[1].high);
         for(int j=i; j<pendingCount-1; j++)
            pendingBreakouts[j] = pendingBreakouts[j+1];
         pendingCount--;
        }
     }
  }

//+------------------------------------------------------------------+
//| Channel Analysis Functions                                       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Classify channel by slope                                        |
//+------------------------------------------------------------------+
ChannelType ClassifyChannel(double slope)
  {
   if(MathAbs(slope) < 0.0001)
      return HORIZONTAL;
   return (slope > 0) ? ASCENDING : DESCENDING;
  }

//+------------------------------------------------------------------+
//| Grade channel strength based on total touches                    |
//+------------------------------------------------------------------+
StrengthGrade GradeStrength(int totalTouches)
  {
   if(totalTouches >= 8)
      return HIGH;
   if(totalTouches >= 5)
      return MEDIUM;
   return LOW;
  }

//+------------------------------------------------------------------+
//| Find the best parallel channel from swing points                  |
//+------------------------------------------------------------------+
bool FindBestChannel(const SwingPoint &highs[],int highCount,
                     const SwingPoint &lows[],int lowCount,
                     const MqlRates &rates[],int totalBars,
                     Channel &bestChannel)
  {
   bestChannel.score = 0.0;
   if(highCount < 2 || lowCount < 2)
     {
      if(DebugMode)
         Print("Not enough swings: highs=",highCount," lows=",lowCount);
      return false;
     }

   double tolerance = TouchToleranceATR * currentATR;

   for(int hi1=0; hi1<highCount-1; hi1++)
     {
      for(int hi2=hi1+1; hi2<highCount; hi2++)
        {
         double dt_high = (double)(highs[hi2].time - highs[hi1].time);
         if(dt_high <= 0)
            continue;
         double slope_high = (highs[hi2].price - highs[hi1].price) / dt_high;

         for(int lo1=0; lo1<lowCount-1; lo1++)
           {
            for(int lo2=lo1+1; lo2<lowCount; lo2++)
              {
               double dt_low = (double)(lows[lo2].time - lows[lo1].time);
               if(dt_low <= 0)
                  continue;
               double slope_low = (lows[lo2].price - lows[lo1].price) / dt_low;

               double avgSlope = (MathAbs(slope_high) + MathAbs(slope_low)) / 2.0;
               double diff = MathAbs(slope_high - slope_low);
               double maxDiff = MaxSlopeDifference * MathMax(avgSlope,0.000001);
               if(diff > maxDiff)
                  continue;

               double upper_at_l1 = highs[hi1].price + slope_high * (lows[lo1].time - highs[hi1].time);
               double upper_at_l2 = highs[hi1].price + slope_high * (lows[lo2].time - highs[hi1].time);

               if(upper_at_l1 <= lows[lo1].price || upper_at_l2 <= lows[lo2].price)
                  continue;

               double dist1 = upper_at_l1 - lows[lo1].price;
               double dist2 = upper_at_l2 - lows[lo2].price;
               double width = (dist1 + dist2) / 2.0;

               if(width < MinChannelWidthATR * currentATR)
                  continue;

               double lower_at_l1 = upper_at_l1 - width;
               double lower_at_l2 = upper_at_l2 - width;
               if(lower_at_l1 > lows[lo1].price + tolerance || lower_at_l2 > lows[lo2].price + tolerance)
                  continue;

               int recentHigh = 0;
               int touchesHigh = CountTouchesOnLine(highs[hi1],highs[hi2],highs,highCount,true,tolerance,RecentTouchBars,recentHigh);

               SwingPoint lowerAnchor1, lowerAnchor2;
               lowerAnchor1.time = highs[hi1].time;
               lowerAnchor1.price = highs[hi1].price - width;
               lowerAnchor2.time = highs[hi2].time;
               lowerAnchor2.price = highs[hi2].price - width;
               int recentLow = 0;
               int touchesLow = CountTouchesOnLine(lowerAnchor1,lowerAnchor2,lows,lowCount,false,tolerance,RecentTouchBars,recentLow);

               if(touchesHigh < MinTouchPointsRequired || touchesLow < MinTouchPointsRequired)
                  continue;
               if(MinRecentTouches > 0 && (recentHigh < MinRecentTouches || recentLow < MinRecentTouches))
                  continue;

               double score = (touchesHigh + touchesLow) * 25.0;
               double recencyBonus = (1.0 - (double)MathMin(highs[hi2].barIndex,lows[lo2].barIndex) / totalBars) * 30.0;
               score += recencyBonus;

               if(score > bestChannel.score)
                 {
                  bestChannel.high1 = highs[hi1];
                  bestChannel.high2 = highs[hi2];
                  bestChannel.low1  = lows[lo1];
                  bestChannel.low2  = lows[lo2];
                  bestChannel.slope = slope_high;
                  bestChannel.width = width;
                  bestChannel.highTouches = touchesHigh;
                  bestChannel.lowTouches  = touchesLow;
                  bestChannel.score = score;
                  bestChannel.type = ClassifyChannel(slope_high);
                  bestChannel.strength = GradeStrength(touchesHigh + touchesLow);

                  if(DebugMode)
                     Print(StringFormat("Candidate accepted: H-touches=%d, L-touches=%d, width=%g, score=%g",
                                        touchesHigh,touchesLow,width,score));
                 }
              }
           }
        }
     }
   return (bestChannel.score > 0.0);
  }

//+------------------------------------------------------------------+
//| Draw the parallel channel with extension                         |
//+------------------------------------------------------------------+
void DrawChannel(const Channel &ch)
  {
   string upName  = TL_PREFIX + "UPPER";
   string dnName  = TL_PREFIX + "LOWER";
   string lblName = TL_PREFIX + "LABEL";

   color upperColor = UpperLineColor;
   color lowerColor = LowerLineColor;

//--- Compute future extension point
   datetime lastSwingTime = MathMax(ch.high2.time,ch.low2.time);
   datetime futureTime = lastSwingTime + LineExtensionBars * PeriodSeconds(_Period);
   double futureUpper = LinePriceAtTime(ch.high1,ch.high2,futureTime);
   double futureLower = futureUpper - ch.width;

//--- Upper line (from first high to future point)
   if(ObjectFind(0,upName) < 0)
      ObjectCreate(0,upName,OBJ_TREND,0,ch.high1.time,ch.high1.price,futureTime,futureUpper);
   else
     {
      ObjectMove(0,upName,0,ch.high1.time,ch.high1.price);
      ObjectMove(0,upName,1,futureTime,futureUpper);
     }
   ObjectSetInteger(0,upName,OBJPROP_COLOR,upperColor);
   ObjectSetInteger(0,upName,OBJPROP_WIDTH,LineWidth);
   ObjectSetInteger(0,upName,OBJPROP_STYLE,LineStyle);
   ObjectSetInteger(0,upName,OBJPROP_RAY_RIGHT,false);   // no ray, we set explicit end
   ObjectSetInteger(0,upName,OBJPROP_BACK,false);

//--- Lower line (parallel, starting at same time as upper)
   double lower1 = ch.high1.price - ch.width;
   if(ObjectFind(0,dnName) < 0)
      ObjectCreate(0,dnName,OBJ_TREND,0,ch.high1.time,lower1,futureTime,futureLower);
   else
     {
      ObjectMove(0,dnName,0,ch.high1.time,lower1);
      ObjectMove(0,dnName,1,futureTime,futureLower);
     }
   ObjectSetInteger(0,dnName,OBJPROP_COLOR,lowerColor);
   ObjectSetInteger(0,dnName,OBJPROP_WIDTH,LineWidth);
   ObjectSetInteger(0,dnName,OBJPROP_STYLE,LineStyle);
   ObjectSetInteger(0,dnName,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,dnName,OBJPROP_BACK,false);

//--- Optional low reference crosses
   if(ShowLowReferenceCrosses)
     {
      string cross1 = TL_PREFIX + "LOWREF1", cross2 = TL_PREFIX + "LOWREF2";
      if(ObjectFind(0,cross1) < 0)
         ObjectCreate(0,cross1,OBJ_ARROW,0,ch.low1.time,ch.low1.price);
      else
         ObjectMove(0,cross1,0,ch.low1.time,ch.low1.price);
      ObjectSetInteger(0,cross1,OBJPROP_ARROWCODE,159);
      ObjectSetInteger(0,cross1,OBJPROP_COLOR,clrGray);
      ObjectSetInteger(0,cross1,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,cross1,OBJPROP_BACK,false);

      if(ObjectFind(0,cross2) < 0)
         ObjectCreate(0,cross2,OBJ_ARROW,0,ch.low2.time,ch.low2.price);
      else
         ObjectMove(0,cross2,0,ch.low2.time,ch.low2.price);
      ObjectSetInteger(0,cross2,OBJPROP_ARROWCODE,159);
      ObjectSetInteger(0,cross2,OBJPROP_COLOR,clrGray);
      ObjectSetInteger(0,cross2,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,cross2,OBJPROP_BACK,false);
     }

//--- Label (placed near the original second swing for readability)
   datetime labelTime = MathMax(ch.high2.time,ch.low2.time);
   double labelPrice = (ch.high1.price + ch.high2.price)/2.0 - ch.width/2.0;
   string strengthText = (ch.strength == HIGH ? "HIGH" : (ch.strength == MEDIUM ? "MEDIUM" : "LOW"));
   string biasText = "NEUTRAL";
   if(UseChannelTypeFilter)
     {
      if(ch.type == ASCENDING)
         biasText = "BUY ONLY";
      else
         if(ch.type == DESCENDING)
            biasText = "SELL ONLY";
     }
//--- Channel type (ASCENDING/DESCENDING/HORIZONTAL) removed from label as requested
   string labelText = "Touches: " + IntegerToString(ch.highTouches + ch.lowTouches) +
                      "\nStrength: " + strengthText + "\nBias: " + biasText;

   if(ObjectFind(0,lblName) < 0)
      ObjectCreate(0,lblName,OBJ_TEXT,0,labelTime,labelPrice);
   else
      ObjectMove(0,lblName,0,labelTime,labelPrice);

   ObjectSetString(0,lblName,OBJPROP_TEXT,labelText);
   ObjectSetInteger(0,lblName,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,lblName,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,lblName,OBJPROP_BACK,false);
  }

//+------------------------------------------------------------------+
//| Draw the best channel on chart                                   |
//+------------------------------------------------------------------+
void DrawBestChannel()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int bars = CopyRates(_Symbol,_Period,0,MaxBarsToAnalyze,rates);
   if(bars < 70)
     {
      if(DebugMode)
         Print("Not enough bars");
      return;
     }

   SwingPoint highs[50], lows[50];
   int highCount = 0, lowCount = 0;

   FindSignificantSwings(rates,bars,highs,highCount,lows,lowCount);
   AssignSwingOrder(highs,highCount);
   AssignSwingOrder(lows,lowCount);

   if(ShowSwingPoints)
      DrawSwingPoints(highs,highCount,lows,lowCount);

   Channel bestChan;
   if(FindBestChannel(highs,highCount,lows,lowCount,rates,bars,bestChan))
     {
      DrawChannel(bestChan);
      if(EnableBreakoutSignals)
         CheckChannelBreakouts(rates,bestChan,highs,highCount,lows,lowCount);
     }
   else
      if(DebugMode)
         Print("No channel to draw.");
  }

//+------------------------------------------------------------------+
//| Detect significant swing highs and lows                          |
//+------------------------------------------------------------------+
void FindSignificantSwings(const MqlRates &rates[],int totalBars,
                           SwingPoint &highs[],int &highCount,
                           SwingPoint &lows[],int &lowCount)
  {
   highCount = 0;
   lowCount = 0;
   double minSize = UseATRFiltering ? currentATR * SwingSizeATRFactor : MinSwingSize;

   for(int i = SwingLookback; i < totalBars - SwingLookback; i++)
     {
      //--- Detect Swing High
      bool isHigh = true;
      double currentHigh = rates[i].high;
      for(int j=1; j<=SwingLookback; j++)
        {
         if(rates[i-j].high >= currentHigh || rates[i+j].high >= currentHigh)
           {
            isHigh = false;
            break;
           }
        }
      if(isHigh)
        {
         double leftLow  = MathMin(rates[i-1].low,rates[i-2].low);
         double rightLow = MathMin(rates[i+1].low,rates[i+2].low);
         double swingSize = currentHigh - MathMax(leftLow,rightLow);
         if(swingSize >= minSize && highCount < 50)
           {
            highs[highCount].time = rates[i].time;
            highs[highCount].price = currentHigh;
            highs[highCount].barIndex = i;
            highs[highCount].size = swingSize;
            highs[highCount].isHigh = true;
            highCount++;
           }
        }

      //--- Detect Swing Low
      bool isLow = true;
      double currentLow = rates[i].low;
      for(int j=1; j<=SwingLookback; j++)
        {
         if(rates[i-j].low <= currentLow || rates[i+j].low <= currentLow)
           {
            isLow = false;
            break;
           }
        }
      if(isLow)
        {
         double leftHigh  = MathMax(rates[i-1].high,rates[i-2].high);
         double rightHigh = MathMax(rates[i+1].high,rates[i+2].high);
         double swingSize = MathMin(leftHigh,rightHigh) - currentLow;
         if(swingSize >= minSize && lowCount < 50)
           {
            lows[lowCount].time = rates[i].time;
            lows[lowCount].price = currentLow;
            lows[lowCount].barIndex = i;
            lows[lowCount].size = swingSize;
            lows[lowCount].isHigh = false;
            lowCount++;
           }
        }
     }
   if(DebugMode)
      Print("Swings found: Highs=",highCount," Lows=",lowCount);
  }

//+------------------------------------------------------------------+
//| Assign order numbers to swings (chronological)                   |
//+------------------------------------------------------------------+
void AssignSwingOrder(SwingPoint &swings[],int count)
  {
   if(count <= 0)
      return;
   for(int i=0; i<count-1; i++)
     {
      for(int j=i+1; j<count; j++)
        {
         if(swings[i].time > swings[j].time)
           {
            SwingPoint t = swings[i];
            swings[i] = swings[j];
            swings[j] = t;
           }
        }
     }
   for(int i=0; i<count; i++)
      swings[i].order = i+1;
  }

//+------------------------------------------------------------------+
//| Draw swing points on chart                                       |
//+------------------------------------------------------------------+
void DrawSwingPoints(const SwingPoint &highs[],int highCount,
                     const SwingPoint &lows[],int lowCount)
  {
   for(int i=0; i<highCount; i++)
     {
      string name = TL_PREFIX + "H_" + IntegerToString(highs[i].order);
      if(ObjectFind(0,name) < 0)
         ObjectCreate(0,name,OBJ_ARROW_THUMB_DOWN,0,highs[i].time,highs[i].price);
      else
         ObjectMove(0,name,0,highs[i].time,highs[i].price);
      ObjectSetInteger(0,name,OBJPROP_COLOR,SwingHighColor);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_TOP);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      if(ShowSwingLabels)
        {
         string lbl = name + "_LABEL";
         double pr = highs[i].price + currentATR*0.05;
         if(ObjectFind(0,lbl) < 0)
            ObjectCreate(0,lbl,OBJ_TEXT,0,highs[i].time,pr);
         else
            ObjectMove(0,lbl,0,highs[i].time,pr);
         ObjectSetString(0,lbl,OBJPROP_TEXT,"H"+IntegerToString(highs[i].order));
         ObjectSetInteger(0,lbl,OBJPROP_COLOR,SwingHighColor);
         ObjectSetInteger(0,lbl,OBJPROP_FONTSIZE,8);
         ObjectSetInteger(0,lbl,OBJPROP_BACK,false);
        }
     }
   for(int i=0; i<lowCount; i++)
     {
      string name = TL_PREFIX + "L_" + IntegerToString(lows[i].order);
      if(ObjectFind(0,name) < 0)
         ObjectCreate(0,name,OBJ_ARROW_THUMB_UP,0,lows[i].time,lows[i].price);
      else
         ObjectMove(0,name,0,lows[i].time,lows[i].price);
      ObjectSetInteger(0,name,OBJPROP_COLOR,SwingLowColor);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_BOTTOM);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      if(ShowSwingLabels)
        {
         string lbl = name + "_LABEL";
         double pr = lows[i].price - currentATR*0.05;
         if(ObjectFind(0,lbl) < 0)
            ObjectCreate(0,lbl,OBJ_TEXT,0,lows[i].time,pr);
         else
            ObjectMove(0,lbl,0,lows[i].time,pr);
         ObjectSetString(0,lbl,OBJPROP_TEXT,"L"+IntegerToString(lows[i].order));
         ObjectSetInteger(0,lbl,OBJPROP_COLOR,SwingLowColor);
         ObjectSetInteger(0,lbl,OBJPROP_FONTSIZE,8);
         ObjectSetInteger(0,lbl,OBJPROP_BACK,false);
        }
     }
  }

//+------------------------------------------------------------------+
//| Checks for breakout crossing and applies filters                 |
//+------------------------------------------------------------------+
void CheckChannelBreakouts(const MqlRates &rates[],const Channel &ch,
                           const SwingPoint &highs[],int highCount,
                           const SwingPoint &lows[],int lowCount)
  {
   if(ArraySize(rates) < 3)
      return;

   datetime t1 = rates[1].time;
   datetime t2 = rates[2].time;
   double buf = BreakoutBufferPrice();
   double minStrength = BreakoutMinStrengthATR * currentATR;
   double strongThreshold = BreakoutStrongThreshold * currentATR;
   int totalTouches = ch.highTouches + ch.lowTouches;

   double upper1 = LinePriceAtTime(ch.high1,ch.high2,t1);
   double upper2 = LinePriceAtTime(ch.high1,ch.high2,t2);
   double pUp1 = BreakoutUseClose ? rates[1].close : rates[1].high;
   double pUp2 = BreakoutUseClose ? rates[2].close : rates[2].high;

   bool crossedUp = false;
   if(BreakoutStrictMode)
      crossedUp = (pUp2 <= upper2 + buf) && (pUp1 > upper1 + buf);
   else
      crossedUp = (pUp1 > upper1 + buf);

   double upStrength = pUp1 - (upper1 + buf);
   bool strongUp = (minStrength == 0) || (upStrength >= minStrength);
   bool superStrongUp = (strongThreshold > 0) && (upStrength >= strongThreshold);

   double lower1 = upper1 - ch.width;
   double lower2 = upper2 - ch.width;
   double pLow1 = BreakoutUseClose ? rates[1].close : rates[1].low;
   double pLow2 = BreakoutUseClose ? rates[2].close : rates[2].low;

   bool crossedDown = false;
   if(BreakoutStrictMode)
      crossedDown = (pLow2 >= lower2 - buf) && (pLow1 < lower1 - buf);
   else
      crossedDown = (pLow1 < lower1 - buf);

   double downStrength = (lower1 - buf) - pLow1;
   bool strongDown = (minStrength == 0) || (downStrength >= minStrength);
   bool superStrongDown = (strongThreshold > 0) && (downStrength >= strongThreshold);

   bool isSweepUp = false, isSweepDown = false;
   if(UseLiquiditySweepFilter)
     {
      double high = rates[1].high, low = rates[1].low, close = rates[1].close;
      isSweepUp   = (high > upper1 + buf) && (close <= upper1 + buf);
      isSweepDown = (low < lower1 - buf) && (close >= lower1 - buf);
     }

   bool volExpanded = true;
   if(UseVolatilityExpansion && atrBuffer[0] > 0)
     {
      double atrNow = atrBuffer[0];
      double atr10  = atrBuffer[10];
      if(atr10 > 0)
         volExpanded = (atrNow / atr10) >= MinVolatilityExpansion;
     }

   bool structBullish = true, structBearish = true;
   if(UseStructuralBreak)
     {
      SwingPoint lastHigh, lastLow;
      GetLastSwing(highs,highCount,lows,lowCount,lastHigh,lastLow);
      if(crossedUp && lastHigh.time > 0)
         structBullish = (pUp1 > lastHigh.price);
      if(crossedDown && lastLow.time > 0)
         structBearish = (pLow1 < lastLow.price);
     }

   if(DebugMode)
     {
      if(crossedUp)
         Print("Bullish breakout at ",TimeToString(t1),", strength=",upStrength);
      if(crossedDown)
         Print("Bearish breakout at ",TimeToString(t1),", strength=",downStrength);
     }

   bool allowBullish = true, allowBearish = true;
   if(UseChannelTypeFilter)
     {
      if(ch.type == ASCENDING)
         allowBearish = false;
      else
         if(ch.type == DESCENDING)
            allowBullish = false;
     }

//--- Bullish
   bool bullishNow = crossedUp && strongUp && allowBullish && !isSweepUp && volExpanded && structBullish;
   if(bullishNow)
     {
      bool trigger = superStrongUp;
      if(!trigger)
        {
         trigger = true;
         for(int i=1; i<=BreakoutConfirmationBars; i++)
           {
            if(i >= ArraySize(rates))
              {
               trigger = false;
               break;
              }
            datetime ti = rates[i].time;
            double ui = LinePriceAtTime(ch.high1,ch.high2,ti);
            double pi = BreakoutUseClose ? rates[i].close : rates[i].high;
            if(!(pi > ui + buf && (pi - (ui + buf)) >= minStrength))
              {
               trigger = false;
               break;
              }
           }
        }
      if(trigger)
        {
         if(UseRetestMode)
           {
            if(pendingCount >= ArraySize(pendingBreakouts))
               ArrayResize(pendingBreakouts,pendingCount+10);
            PendingBreakout pb;
            pb.breakoutTime = t1;
            pb.price = pUp1;
            pb.isBullish = true;
            pb.linePrice = upper1;
            pb.totalTouches = totalTouches;
            pb.channelSlope = ch.slope;
            pb.channelWidth = ch.width;
            pb.high1 = ch.high1;
            pb.high2 = ch.high2;
            pendingBreakouts[pendingCount++] = pb;
            if(DebugMode)
               Print("Bullish pending retest at ",TimeToString(t1));
           }
         else
           {
            double arrowPrice = rates[1].low - currentATR*0.15;
            DrawPermanentArrow(t1,arrowPrice,true,totalTouches,rates[1].low,rates[1].high);
           }
         if(AlertOnBreakout)
            Alert(_Symbol," ",EnumToString(_Period),": BUY breakout");
        }
     }

//--- Bearish
   bool bearishNow = crossedDown && strongDown && allowBearish && !isSweepDown && volExpanded && structBearish;
   if(bearishNow)
     {
      bool trigger = superStrongDown;
      if(!trigger)
        {
         trigger = true;
         for(int i=1; i<=BreakoutConfirmationBars; i++)
           {
            if(i >= ArraySize(rates))
              {
               trigger = false;
               break;
              }
            datetime ti = rates[i].time;
            double ui = LinePriceAtTime(ch.high1,ch.high2,ti);
            double li = ui - ch.width;
            double pi = BreakoutUseClose ? rates[i].close : rates[i].low;
            if(!(pi < li - buf && ((li - buf) - pi) >= minStrength))
              {
               trigger = false;
               break;
              }
           }
        }
      if(trigger)
        {
         if(UseRetestMode)
           {
            if(pendingCount >= ArraySize(pendingBreakouts))
               ArrayResize(pendingBreakouts,pendingCount+10);
            PendingBreakout pb;
            pb.breakoutTime = t1;
            pb.price = pLow1;
            pb.isBullish = false;
            pb.linePrice = lower1;
            pb.totalTouches = totalTouches;
            pb.channelSlope = ch.slope;
            pb.channelWidth = ch.width;
            pb.high1 = ch.high1;
            pb.high2 = ch.high2;
            pendingBreakouts[pendingCount++] = pb;
            if(DebugMode)
               Print("Bearish pending retest at ",TimeToString(t1));
           }
         else
           {
            double arrowPrice = rates[1].high + currentATR*0.15;
            DrawPermanentArrow(t1,arrowPrice,false,totalTouches,rates[1].low,rates[1].high);
           }
         if(AlertOnBreakout)
            Alert(_Symbol," ",EnumToString(_Period),": SELL breakout");
        }
     }
  }

//+------------------------------------------------------------------+
//| ChartEvent                                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
