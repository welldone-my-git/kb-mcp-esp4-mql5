//+------------------------------------------------------------------+
//|                                        Flag_Pattern_Detector.mq5 |
//|                              Copyright 2026, Christian Benjamin. |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "2.0"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   2

//--- visible arrow plots
#property indicator_label1  "Buy arrow"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "Sell arrow"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

//--- arrow symbol codes (Wingdings)
#define ARROW_UP   233
#define ARROW_DOWN 234

//--- buffers
double BufferBuy[];          // holds bullish breakout signals (arrow placement)
double BufferSell[];         // holds bearish breakout signals
double BufferPoleHeight[];   // stores flagpole height for EA (not plotted)

//--- Inputs (user adjustable parameters)
input int      LookbackBars      = 2000;        // Bars to scan backward on first load
input double   MinPoleATR        = 1;         // Minimum flagpole size (multiple of ATR)
input double   MaxRetracePercent = 61.8;        // Maximum retracement allowed (% of pole)
input int      MinFlagBars       = 3;           // Minimum number of consolidation bars
input int      MaxFlagBars       = 20;          // Maximum consolidation duration (0 = no limit)
input bool     DebugMode         = true;        // Print debug messages to Experts log
input color    BullFlagColor     = clrDodgerBlue;
input color    BearFlagColor     = clrTomato;

//--- Alert parameters
input bool     EnableAlerts      = true;
input bool     EnableSound       = false;
input string   SoundFile         = "alert.wav";
input bool     EnableNotification = false;
input bool     EnableEmail       = false;

//--- Structures to store pattern data
struct DrawnFlag
  {
   int               poleStart, poleEnd, flagStart, flagEnd;
   datetime          startTime, endTime;
   bool              isBull;
  };
struct ActiveFlag
  {
   int               poleStart, poleEnd, flagStart, lastUpdate;
   bool              isBull;
   double            poleHigh, poleLow, poleLength, extreme;
   int               pullbacks, pushes;
   datetime          poleStartTime, poleEndTime;
  };

//--- global arrays
DrawnFlag  drawnFlags[];
ActiveFlag activeFlags[];
int        atrHandle;
double     atrBuffer[];

//+------------------------------------------------------------------+
//| Lighten a color for fill effects (used in channel rectangle)     |
//+------------------------------------------------------------------+
color ColorLighter(color clr,double percent)
  {
   percent = MathMax(0,MathMin(100,percent));
   double factor = percent/100.0;
   uchar r=(uchar)((clr>>16)&0xFF);
   uchar g=(uchar)((clr>>8)&0xFF);
   uchar b=(uchar)(clr&0xFF);
   r=(uchar)(r+(255-r)*factor);
   g=(uchar)(g+(255-g)*factor);
   b=(uchar)(b+(255-b)*factor);
   return (color)((r<<16)|(g<<8)|b);
  }

//+------------------------------------------------------------------+
//| Check if a new flag overlaps or is too close to existing flags   |
//+------------------------------------------------------------------+
bool IsTooClose(int newStartBar,int newEndBar,bool newIsBull)
  {
//--- exact duplicate check
   for(int i=0; i<ArraySize(drawnFlags); i++)
      if(drawnFlags[i].flagStart==newStartBar && drawnFlags[i].flagEnd==newEndBar)
         return true;

//--- overlap / proximity check
   for(int i=0; i<ArraySize(drawnFlags); i++)
     {
      int existStart=drawnFlags[i].flagStart;
      int existEnd  =drawnFlags[i].flagEnd;
      int existLen  =existEnd-existStart+1;
      int newLen    =newEndBar-newStartBar+1;
      int overlapStart=MathMax(newStartBar,existStart);
      int overlapEnd  =MathMin(newEndBar,existEnd);
      int overlapLen  =(overlapEnd>=overlapStart)?(overlapEnd-overlapStart+1):0;
      double overlapPercent=(double)overlapLen/MathMin(existLen,newLen)*100.0;
      if(overlapPercent>30.0)
         return true;
      if(MathAbs(newStartBar-existStart)<=3)
         return true;
      if(MathAbs(newEndBar-existStart)<=2)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Store a completed flag pattern into the history array            |
//+------------------------------------------------------------------+
void RecordDrawnFlag(int poleStart,int poleEnd,int flagStart,int flagEnd,
                     datetime startTime,datetime endTime,bool isBull)
  {
   int sz=ArraySize(drawnFlags);
   ArrayResize(drawnFlags,sz+1);
   drawnFlags[sz].poleStart=poleStart;
   drawnFlags[sz].poleEnd  =poleEnd;
   drawnFlags[sz].flagStart=flagStart;
   drawnFlags[sz].flagEnd  =flagEnd;
   drawnFlags[sz].startTime=startTime;
   drawnFlags[sz].endTime  =endTime;
   drawnFlags[sz].isBull   =isBull;
  }

//+------------------------------------------------------------------+
//| Return true if the pole was already drawn                         |
//+------------------------------------------------------------------+
bool IsPoleAlreadyDrawn(int poleStart,int poleEnd)
  {
   for(int i=0;i<ArraySize(drawnFlags);i++)
      if(drawnFlags[i].poleStart==poleStart && drawnFlags[i].poleEnd==poleEnd)
         return true;
   return false;
  }

//+------------------------------------------------------------------+
//| Return true if the pole is already active (not yet broken)       |
//+------------------------------------------------------------------+
bool IsPoleAlreadyActive(int poleStart,int poleEnd)
  {
   for(int i=0;i<ArraySize(activeFlags);i++)
      if(activeFlags[i].poleStart==poleStart && activeFlags[i].poleEnd==poleEnd)
         return true;
   return false;
  }

//+------------------------------------------------------------------+
//| Find the minimum low in a bar range                              |
//+------------------------------------------------------------------+
double FindMinInRange(int start,int end,const double &low[])
  {
   double m=DBL_MAX;
   for(int i=start;i<=end;i++)
      if(low[i]<m)
         m=low[i];
   return m;
  }

//+------------------------------------------------------------------+
//| Find the maximum high in a bar range                             |
//+------------------------------------------------------------------+
double FindMaxInRange(int start,int end,const double &high[])
  {
   double m=-DBL_MAX;
   for(int i=start;i<=end;i++)
      if(high[i]>m)
         m=high[i];
   return m;
  }

//+------------------------------------------------------------------+
//| Send alert notifications (popup, sound, push, email)             |
//+------------------------------------------------------------------+
void DoAlert(string msg,bool playSound,bool pushNote,bool sendMail)
  {
   if(!EnableAlerts)
      return;
   Alert(msg);
   if(playSound)
      PlaySound(SoundFile);
   if(pushNote)
      SendNotification(msg);
   if(sendMail)
      SendMail("Flag Detector Alert",msg);
  }

//+------------------------------------------------------------------+
//| Draw the complete flag pattern on the chart                      |
//+------------------------------------------------------------------+
void DrawSlantedPattern(int poleStart,int poleEnd,int flagStart,int flagEnd,bool isBull,
                        const double &high[],const double &low[],const datetime &time[])
  {
//--- unique name prefix based on pole bar indices
   string prefix="Flag_"+IntegerToString(poleStart)+"_"+IntegerToString(poleEnd)+"_";
   ObjectsDeleteAll(0,prefix);

   int endConsol=MathMax(flagStart,flagEnd-1);
   datetime startTime=time[flagStart];
   datetime endTime  =time[endConsol];
   color clr=isBull?BullFlagColor:BearFlagColor;
   string typeStr=isBull?"Bullish Flag":"Bearish Flag";

//--- 1. Draw the flagpole
   ObjectCreate(0,prefix+"pole",OBJ_TREND,0,
                time[poleStart],isBull?low[poleStart]:high[poleStart],
                time[poleEnd],isBull?high[poleEnd]:low[poleEnd]);
   ObjectSetInteger(0,prefix+"pole",OBJPROP_COLOR,clr);
   ObjectSetInteger(0,prefix+"pole",OBJPROP_WIDTH,2);
   ObjectSetInteger(0,prefix+"pole",OBJPROP_RAY_RIGHT,false);

//--- 2. Construct slanted parallel channel
   int half=flagStart+(endConsol-flagStart)/2;
   double upperStart,upperEnd,lowerStart,lowerEnd;

   if(isBull)
     {
      //--- find highest high in first half and second half for slope
      int idxHighFirst=flagStart,idxHighSecond=half+1;
      double highFirst=high[flagStart],highSecond=(half+1<=endConsol)?high[half+1]:high[flagStart];
      for(int i=flagStart+1;i<=half&&i<=endConsol;i++)
         if(high[i]>highFirst)
           {
            highFirst=high[i];
            idxHighFirst=i;
           }
      for(int i=half+2;i<=endConsol;i++)
         if(high[i]>highSecond)
           {
            highSecond=high[i];
            idxHighSecond=i;
           }

      //--- ensure a slight downward tilt if second high isn't lower
      if(highSecond>=highFirst)
         highSecond=highFirst-(highFirst-FindMinInRange(flagStart,endConsol,low))*0.1;

      //--- calculate slope of the upper line
      double slope=0;
      if(time[idxHighSecond]!=time[idxHighFirst])
         slope=(highSecond-highFirst)/(double)(time[idxHighSecond]-time[idxHighFirst]);

      //--- extend the upper line across the whole consolidation
      upperStart=highFirst+slope*(startTime-time[idxHighFirst]);
      upperEnd  =highFirst+slope*(endTime  -time[idxHighFirst]);

      //--- lowest low to anchor the lower line
      double lowestLow=FindMinInRange(flagStart,endConsol,low);
      int idxLowest=flagStart;
      for(int i=flagStart+1;i<=endConsol;i++)
         if(low[i]<lowestLow)
           {
            lowestLow=low[i];
            idxLowest=i;
           }

      //--- create the lower line parallel to the upper
      lowerStart=lowestLow+slope*(startTime-time[idxLowest]);
      lowerEnd  =lowestLow+slope*(endTime  -time[idxLowest]);

      //--- push lower line down if any low sticks out
      for(int i=flagStart;i<=endConsol;i++)
        {
         double ratio=(double)(time[i]-startTime)/(double)(endTime-startTime);
         double lineVal=lowerStart+(lowerEnd-lowerStart)*ratio;
         if(low[i]<lineVal)
           {
            double diff=lineVal-low[i]+_Point;
            lowerStart-=diff;
            lowerEnd-=diff;
           }
        }
     }
   else
     {
      int idxLowFirst=flagStart,idxLowSecond=half+1;
      double lowFirst=low[flagStart],lowSecond=(half+1<=endConsol)?low[half+1]:low[flagStart];
      for(int i=flagStart+1;i<=half&&i<=endConsol;i++)
         if(low[i]<lowFirst)
           {
            lowFirst=low[i];
            idxLowFirst=i;
           }
      for(int i=half+2;i<=endConsol;i++)
         if(low[i]<lowSecond)
           {
            lowSecond=low[i];
            idxLowSecond=i;
           }

      //--- slight upward tilt if needed
      if(lowSecond<=lowFirst)
         lowSecond=lowFirst+(FindMaxInRange(flagStart,endConsol,high)-lowFirst)*0.1;

      double slope=0;
      if(time[idxLowSecond]!=time[idxLowFirst])
         slope=(lowSecond-lowFirst)/(double)(time[idxLowSecond]-time[idxLowFirst]);

      lowerStart=lowFirst+slope*(startTime-time[idxLowFirst]);
      lowerEnd  =lowFirst+slope*(endTime  -time[idxLowFirst]);

      double highestHigh=FindMaxInRange(flagStart,endConsol,high);
      int idxHighest=flagStart;
      for(int i=flagStart+1;i<=endConsol;i++)
         if(high[i]>highestHigh)
           {
            highestHigh=high[i];
            idxHighest=i;
           }

      upperStart=highestHigh+slope*(startTime-time[idxHighest]);
      upperEnd  =highestHigh+slope*(endTime  -time[idxHighest]);

      //--- push upper line up if any high breaks it
      for(int i=flagStart;i<=endConsol;i++)
        {
         double ratio=(double)(time[i]-startTime)/(double)(endTime-startTime);
         double lineVal=upperStart+(upperEnd-upperStart)*ratio;
         if(high[i]>lineVal)
           {
            double diff=high[i]-lineVal+_Point;
            upperStart+=diff;
            upperEnd+=diff;
           }
        }
     }

//--- 3. Draw upper and lower channel lines (dashed, bold)
   ObjectCreate(0,prefix+"upper",OBJ_TREND,0,startTime,upperStart,endTime,upperEnd);
   ObjectSetInteger(0,prefix+"upper",OBJPROP_COLOR,clr);
   ObjectSetInteger(0,prefix+"upper",OBJPROP_WIDTH,3);
   ObjectSetInteger(0,prefix+"upper",OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,prefix+"upper",OBJPROP_RAY_RIGHT,false);

   ObjectCreate(0,prefix+"lower",OBJ_TREND,0,startTime,lowerStart,endTime,lowerEnd);
   ObjectSetInteger(0,prefix+"lower",OBJPROP_COLOR,clr);
   ObjectSetInteger(0,prefix+"lower",OBJPROP_WIDTH,3);
   ObjectSetInteger(0,prefix+"lower",OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,prefix+"lower",OBJPROP_RAY_RIGHT,false);

//--- 4. Fill rectangle between the lines
   double rectHigh=MathMax(MathMax(upperStart,upperEnd),MathMax(lowerStart,lowerEnd));
   double rectLow =MathMin(MathMin(upperStart,upperEnd),MathMin(lowerStart,lowerEnd));
   ObjectCreate(0,prefix+"rect",OBJ_RECTANGLE,0,startTime,rectHigh,endTime,rectLow);
   ObjectSetInteger(0,prefix+"rect",OBJPROP_COLOR,ColorLighter(clr,70));
   ObjectSetInteger(0,prefix+"rect",OBJPROP_FILL,true);
   ObjectSetInteger(0,prefix+"rect",OBJPROP_BACK,true);
   ObjectSetInteger(0,prefix+"rect",OBJPROP_WIDTH,1);

//--- 5. Text label in the middle
   int midIdx=(flagStart+endConsol)/2;
   double labelPrice=isBull?rectHigh+(rectHigh-rectLow)*0.15:rectLow-(rectHigh-rectLow)*0.15;
   ObjectCreate(0,prefix+"label",OBJ_TEXT,0,time[midIdx],labelPrice);
   ObjectSetString(0,prefix+"label",OBJPROP_TEXT,typeStr);
   ObjectSetInteger(0,prefix+"label",OBJPROP_COLOR,clr);
   ObjectSetInteger(0,prefix+"label",OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,prefix+"label",OBJPROP_BACK,true);
  }

//+------------------------------------------------------------------+
//| Try to add a new active flag (unfinished pattern)                |
//+------------------------------------------------------------------+
bool TryAddActiveFlag(int poleStart,int poleEnd,bool isBull,
                      const double &high[],const double &low[],
                      const datetime &time[],int rates_total)
  {
//--- reject if already drawn or already active
   if(IsPoleAlreadyDrawn(poleStart,poleEnd)||IsPoleAlreadyActive(poleStart,poleEnd))
      return false;

   double poleHigh=isBull?high[poleEnd]:high[poleStart];
   double poleLow =isBull?low[poleStart]:low[poleEnd];
   double poleLen =poleHigh-poleLow;
   int flagStart=poleEnd+1;

   if(flagStart>=rates_total)
      return false;
   int lastBar=rates_total-1;
   if(lastBar-flagStart+1<MinFlagBars)
      return false;       // not enough bars yet

//--- find the extreme price within the flag area
   double extreme=isBull?FindMinInRange(flagStart,lastBar,low):FindMaxInRange(flagStart,lastBar,high);

//--- check maximum retracement
   if(isBull)
     {
      if((poleHigh-extreme)/poleLen*100>MaxRetracePercent)
         return false;
     }
   else
     {
      if((extreme-poleLow)/poleLen*100>MaxRetracePercent)
         return false;
     }

//--- count pullbacks and pushes (structural quality)
   int pullbacks=0,pushes=0;
   for(int k=flagStart+1;k<=lastBar;k++)
     {
      if(isBull)
        {
         if(high[k]<high[k-1])
            pullbacks++;
         if(low[k] >low[k-1])
            pushes++;
        }
      else
        {
         if(low[k] >low[k-1])
            pullbacks++;
         if(high[k]<high[k-1])
            pushes++;
        }
     }

//--- reject if duration exceeds max
   if(MaxFlagBars>0 && lastBar-flagStart+1>MaxFlagBars)
      return false;

//--- store active flag
   int idx=ArraySize(activeFlags);
   ArrayResize(activeFlags,idx+1);
   activeFlags[idx].poleStart=poleStart;
   activeFlags[idx].poleEnd=poleEnd;
   activeFlags[idx].flagStart=flagStart;
   activeFlags[idx].lastUpdate=lastBar;
   activeFlags[idx].isBull=isBull;
   activeFlags[idx].poleHigh=poleHigh;
   activeFlags[idx].poleLow=poleLow;
   activeFlags[idx].poleLength=poleLen;
   activeFlags[idx].extreme=extreme;
   activeFlags[idx].pullbacks=pullbacks;
   activeFlags[idx].pushes=pushes;
   activeFlags[idx].poleStartTime=time[poleStart];
   activeFlags[idx].poleEndTime=time[poleEnd];
   return true;
  }

//+------------------------------------------------------------------+
//| Update an active flag – check for breakout or invalidation       |
//+------------------------------------------------------------------+
bool UpdateActiveFlag(int index,const double &high[],const double &low[],
                      const double &close[],const datetime &time[],
                      int newBar,int rates_total)
  {
   ActiveFlag af=activeFlags[index];

//--- already processed this bar
   if(newBar<=af.lastUpdate)
      return false;

   bool breakout=false;
   if(af.isBull)
     {
      if(close[newBar]>af.poleHigh)
         breakout=true;
     }
   else
     {
      if(close[newBar]<af.poleLow)
         breakout=true;
     }

   if(breakout)
     {
      if(IsTooClose(af.flagStart,newBar,af.isBull))
         return true;

      //--- draw the completed pattern
      DrawSlantedPattern(af.poleStart,af.poleEnd,af.flagStart,newBar,af.isBull,high,low,time);

      //--- fill indicator buffers (signal output)
      if(af.isBull && newBar<ArraySize(BufferBuy))
        {
         BufferBuy[newBar]=low[newBar]-10*_Point;
         if(newBar<ArraySize(BufferPoleHeight))
            BufferPoleHeight[newBar]=af.poleLength;
        }
      else
         if(!af.isBull && newBar<ArraySize(BufferSell))
           {
            BufferSell[newBar]=high[newBar]+10*_Point;
            if(newBar<ArraySize(BufferPoleHeight))
               BufferPoleHeight[newBar]=af.poleLength;
           }

      //--- alert and log
      string msg=StringFormat("Flag Detector: %s flag on %s %s at %s",
                              af.isBull?"Bull":"Bear",_Symbol,EnumToString(Period()),
                              TimeToString(time[newBar]));
      DoAlert(msg,EnableSound,EnableNotification,EnableEmail);
      if(DebugMode)
         Print((af.isBull?"BULL":"BEAR")," Flag | ",TimeToString(time[newBar]),
               " | Pole height: ",af.poleLength);

      //--- record as drawn
      RecordDrawnFlag(af.poleStart,af.poleEnd,af.flagStart,newBar,
                      time[af.flagStart],time[newBar],af.isBull);
      return true;
     }

//--- no breakout: update extremes and check invalidation
   if(af.isBull)
     {
      if(low[newBar]<af.extreme)
         af.extreme=low[newBar];
     }
   else
     {
      if(high[newBar]>af.extreme)
         af.extreme=high[newBar];
     }

   double retrace=af.isBull?(af.poleHigh-af.extreme)/af.poleLength*100
                  :(af.extreme-af.poleLow)/af.poleLength*100;
   if(retrace>MaxRetracePercent)
      return true;

   if(MaxFlagBars>0 && newBar-af.flagStart+1>MaxFlagBars)
      return true; // too long

//--- update structural counters
   if(newBar>af.flagStart)
     {
      int prev=newBar-1;
      if(af.isBull)
        {
         if(high[newBar]<high[prev])
            af.pullbacks++;
         if(low[newBar] >low[prev])
            af.pushes++;
        }
      else
        {
         if(low[newBar] >low[prev])
            af.pullbacks++;
         if(high[newBar]<high[prev])
            af.pushes++;
        }
     }

   af.lastUpdate=newBar;
   activeFlags[index]=af;
   return false;
  }

//+------------------------------------------------------------------+
//| Remove an active flag from the array                             |
//+------------------------------------------------------------------+
void RemoveActiveFlag(int index)
  {
   int last=ArraySize(activeFlags)-1;
   activeFlags[index]=activeFlags[last];
   ArrayResize(activeFlags,last);
  }

//+------------------------------------------------------------------+
//| Search for a 3‑bar impulsive move (flagpole)                     |
//+------------------------------------------------------------------+
bool FindThreeBarMove(int startIndex,int rates_total,
                      const double &open[],const double &close[],
                      const double &atr[],
                      int &moveStart,int &moveEnd,bool &isBull)
  {
   for(int j=startIndex;j<=rates_total-3;j++)
     {
      double totalUp=0,totalDown=0;
      for(int k=0;k<3;k++)
        {
         if(close[j+k]>open[j+k])
            totalUp  +=close[j+k]-open[j+k];
         else
            totalDown+=open[j+k]-close[j+k];
        }
      //--- bullish flagpole
      if(totalUp>totalDown && totalUp>atr[j]*MinPoleATR)
        {
         moveStart=j;
         moveEnd=j+2;
         isBull=true;
         return true;
        }
      //--- bearish flagpole
      if(totalDown>totalUp && totalDown>atr[j]*MinPoleATR)
        {
         moveStart=j;
         moveEnd=j+2;
         isBull=false;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Validate flag consolidation (retrace, pullbacks, max duration)   |
//+------------------------------------------------------------------+
bool ValidateFlagConsolidation(int flagStart,int flagEnd,bool isBull,
                               double poleHigh,double poleLow,double poleLength,
                               const double &high[],const double &low[])
  {
   double extreme=isBull?FindMinInRange(flagStart,flagEnd,low):FindMaxInRange(flagStart,flagEnd,high);
   double retrace=isBull?(poleHigh-extreme)/poleLength*100:(extreme-poleLow)/poleLength*100;
   if(retrace>MaxRetracePercent)
      return false;

   int pullbacks=0,pushes=0;
   for(int k=flagStart+1;k<flagEnd;k++)
     {
      if(isBull)
        {
         if(high[k]<high[k-1])
            pullbacks++;
         if(low[k] >low[k-1])
            pushes++;
        }
      else
        {
         if(low[k] >low[k-1])
            pullbacks++;
         if(high[k]<high[k-1])
            pushes++;
        }
     }
   if(pullbacks<pushes)
      return false;
   if(MaxFlagBars>0&&(flagEnd-flagStart+1)>MaxFlagBars)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//| Scan historical bars for completed flag patterns                 |
//+------------------------------------------------------------------+
void ScanHistoricalFlags(int rates_total,
                         const double &open[],const double &high[],
                         const double &low[],const double &close[],
                         const datetime &time[])
  {
   int histStart=MathMax(0,rates_total-LookbackBars);
   for(int i=histStart;i<rates_total-MinFlagBars-1;i++)
     {
      int moveStart,moveEnd;
      bool isBullMove;
      if(!FindThreeBarMove(i,rates_total,open,close,atrBuffer,moveStart,moveEnd,isBullMove))
         continue;

      int flagStart=moveEnd+1;
      int breakoutLimit=(MaxFlagBars>0)?flagStart+MaxFlagBars:rates_total;
      breakoutLimit=MathMin(breakoutLimit,rates_total);
      double poleLow=isBullMove?low[moveStart]:low[moveEnd];
      double poleHigh=isBullMove?high[moveEnd]:high[moveStart];
      double poleLength=poleHigh-poleLow;
      int flagEnd=-1;

      //--- find breakout bar
      if(isBullMove)
         for(int k=flagStart;k<breakoutLimit;k++)
            if(close[k]>poleHigh)
              {
               flagEnd=k;
               break;
              }
            else
               for(int k=flagStart;k<breakoutLimit;k++)
                  if(close[k]<poleLow)
                    {
                     flagEnd=k;
                     break;
                    }

      if(flagEnd==-1||(flagEnd-flagStart)<MinFlagBars)
         continue;     // not enough flag bars
      if(!ValidateFlagConsolidation(flagStart,flagEnd,isBullMove,poleHigh,poleLow,poleLength,high,low))
         continue;
      if(IsTooClose(flagStart,flagEnd,isBullMove))
         continue;

      //--- draw and fill buffers for historical pattern
      DrawSlantedPattern(moveStart,moveEnd,flagStart,flagEnd,isBullMove,high,low,time);
      if(isBullMove && flagEnd<ArraySize(BufferBuy))
        {
         BufferBuy[flagEnd]=low[flagEnd]-10*_Point;
         if(flagEnd<ArraySize(BufferPoleHeight))
            BufferPoleHeight[flagEnd]=poleLength;
        }
      else
         if(!isBullMove && flagEnd<ArraySize(BufferSell))
           {
            BufferSell[flagEnd]=high[flagEnd]+10*_Point;
            if(flagEnd<ArraySize(BufferPoleHeight))
               BufferPoleHeight[flagEnd]=poleLength;
           }
      RecordDrawnFlag(moveStart,moveEnd,flagStart,flagEnd,time[flagStart],time[flagEnd],isBullMove);
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create ATR handle (20-period)
   atrHandle=iATR(_Symbol,PERIOD_CURRENT,20);
   if(atrHandle==INVALID_HANDLE)
      return INIT_FAILED;

//--- bind buffers
   SetIndexBuffer(0,BufferBuy,INDICATOR_DATA);
   SetIndexBuffer(1,BufferSell,INDICATOR_DATA);
   SetIndexBuffer(2,BufferPoleHeight,INDICATOR_CALCULATIONS);
//--- set arrow symbols
   PlotIndexSetInteger(0,PLOT_ARROW,ARROW_UP);
   PlotIndexSetInteger(1,PLOT_ARROW,ARROW_DOWN);

//--- ensure standard indexing (oldest bar at index 0)
   ArraySetAsSeries(BufferBuy,false);
   ArraySetAsSeries(BufferSell,false);
   ArraySetAsSeries(BufferPoleHeight,false);

//--- initialize buffers with empty values
   ArrayInitialize(BufferBuy,EMPTY_VALUE);
   ArrayInitialize(BufferSell,EMPTY_VALUE);
   ArrayInitialize(BufferPoleHeight,0.0);

   if(DebugMode)
      Print("Flag Detector v2.0 ",_Symbol);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(atrHandle!=INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   ObjectsDeleteAll(0,"Flag_");
   ArrayFree(drawnFlags);
   ArrayFree(activeFlags);
  }

//+------------------------------------------------------------------+
//| Main calculation loop                                            |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int32_t  &spread[])
  {
//--- copy ATR buffer for all available bars
   if(CopyBuffer(atrHandle,0,0,rates_total,atrBuffer)!=rates_total)
      return 0;

//--- reset buffer values for newly arrived bars (prevents repainting)
   for(int i=prev_calculated;i<rates_total;i++)
     {
      if(i<ArraySize(BufferBuy))
         BufferBuy[i]=EMPTY_VALUE;
      if(i<ArraySize(BufferSell))
         BufferSell[i]=EMPTY_VALUE;
      if(i<ArraySize(BufferPoleHeight))
         BufferPoleHeight[i]=0.0;
     }

//--- first run: full historical scan + initial active search
   if(prev_calculated==0)
     {
      ScanHistoricalFlags(rates_total,open,high,low,close,time);
      int activeScanStart=MathMax(0,rates_total-LookbackBars);
      for(int i=activeScanStart;i<=rates_total-MinFlagBars-1;i++)
        {
         int moveStart,moveEnd;
         bool isBullMove;
         if(FindThreeBarMove(i,rates_total,open,close,atrBuffer,moveStart,moveEnd,isBullMove))
            TryAddActiveFlag(moveStart,moveEnd,isBullMove,high,low,time,rates_total);
        }
     }
   else
     {
      int newBars=rates_total-prev_calculated;
      if(newBars>0)
        {
         //--- update existing active flags (remove if broken/invalid)
         for(int i=ArraySize(activeFlags)-1;i>=0;i--)
           {
            bool remove=false;
            for(int bar=prev_calculated;bar<rates_total;bar++)
               if(UpdateActiveFlag(i,high,low,close,time,bar,rates_total))
                 {remove=true;break;}
            if(remove)
               RemoveActiveFlag(i);
           }

         //--- scan recent bars for new flagpoles (window = max(50, LookbackBars))
         int scanWindow=MathMax(50,LookbackBars);
         int newPoleScanStart=MathMax(0,rates_total-scanWindow);
         for(int i=newPoleScanStart;i<=rates_total-3;i++)
           {
            int moveStart,moveEnd;
            bool isBullMove;
            if(FindThreeBarMove(i,rates_total,open,close,atrBuffer,moveStart,moveEnd,isBullMove))
               TryAddActiveFlag(moveStart,moveEnd,isBullMove,high,low,time,rates_total);
           }
        }
     }

   return rates_total;
  }
//+------------------------------------------------------------------+