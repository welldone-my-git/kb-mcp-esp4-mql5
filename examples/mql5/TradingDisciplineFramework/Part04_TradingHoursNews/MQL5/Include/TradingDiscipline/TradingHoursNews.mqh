//+------------------------------------------------------------------+
//|                                             TradingHoursNews.mqh |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"

//+------------------------------------------------------------------+
//| Namespace THN: Trading Hours & News Management                   |
//+------------------------------------------------------------------+
namespace THN
{
//--- configuration files
const string SESSIONS_FILE = "TradingSessions.txt";
const string NEWS_FILE     = "NewsEvents.csv";
const string LOG_FILE      = "HoursNewsLog.csv";

//--- internal cache
static datetime s_lastRefresh    = 0;
static int      s_refreshInterval= 1;   // seconds
static bool     s_allowedNow     = true;
static string   s_nextSession    = "";
static string   s_nextNews       = "";
static datetime s_nextNewsTime   = 0;

//--- news events cache
//+------------------------------------------------------------------+
//| Structure: NewsEvent                                             |
//| Stores scheduled news time and blackout windows                  |
//+------------------------------------------------------------------+
struct NewsEvent
  {
   datetime          time;
   int               preBlackout;    // minutes before
   int               postBlackout;   // minutes after
  };
//+------------------------------------------------------------------+

static NewsEvent s_newsEvents[];
static int       s_newsCount = 0;

//--- session cache
static string   s_cachedSessions   = "";
static datetime s_sessionsFileTime = 0;

//--- news file modification time
static datetime s_newsFileTime = 0;

//+------------------------------------------------------------------+
//| SaveSessions                                                     |
//| Saves allowed sessions to file and updates cache                 |
//+------------------------------------------------------------------+
bool SaveSessions(string sessions)
  {
   int handle = FileOpen(SESSIONS_FILE, FILE_TXT|FILE_WRITE);
   if(handle == INVALID_HANDLE)
      return(false);

   FileWrite(handle, sessions);
   FileClose(handle);

   s_cachedSessions   = sessions;
   s_sessionsFileTime = FileModificationTime(SESSIONS_FILE);
   return(true);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| FileModificationTime                                             |
//| Returns 0 if file does not exist or cannot be opened             |
//+------------------------------------------------------------------+
datetime FileModificationTime(string filename)
  {
   if(!FileIsExist(filename))
      return(0);

   int handle = FileOpen(filename, FILE_READ|FILE_BIN);
   if(handle == INVALID_HANDLE)
      return(0);

   datetime modTime = (datetime)FileGetInteger(handle, FILE_MODIFY_DATE);
   FileClose(handle);

   return(modTime);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| LoadSessions                                                     |
//| Loads with caching                                               |
//+------------------------------------------------------------------+
string LoadSessions()
  {
   datetime curTime = FileModificationTime(SESSIONS_FILE);

   if(curTime == s_sessionsFileTime && s_cachedSessions != "")
      return(s_cachedSessions);

   if(!FileIsExist(SESSIONS_FILE))
      return("");

   int handle = FileOpen(SESSIONS_FILE, FILE_TXT|FILE_READ);
   if(handle == INVALID_HANDLE)
      return("");

   string data = FileReadString(handle);
   FileClose(handle);

   s_cachedSessions   = data;
   s_sessionsFileTime = curTime;
   return(data);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ParseTimeRange                                                   |
//| Converts "HH:MM-HH:MM" into minutes since midnight               |
//+------------------------------------------------------------------+
bool ParseTimeRange(string range,int &startMin,int &endMin)
  {
   string parts[];

   if(StringSplit(range,'-',parts) != 2)
      return(false);

   string startStr = parts[0];
   string endStr   = parts[1];

   int h1,m1,h2,m2;

   if(StringSplit(startStr,':',parts) != 2)
      return(false);

   h1 = (int)StringToInteger(parts[0]);
   m1 = (int)StringToInteger(parts[1]);

   if(StringSplit(endStr,':',parts) != 2)
      return(false);

   h2 = (int)StringToInteger(parts[0]);
   m2 = (int)StringToInteger(parts[1]);

   if(h1<0 || h1>23 || m1<0 || m1>59 ||
      h2<0 || h2>23 || m2<0 || m2>59)
      return(false);

   startMin = h1*60 + m1;
   endMin   = h2*60 + m2;
   return(true);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| IsWithinAllowedSessions                                          |
//+------------------------------------------------------------------+
bool IsWithinAllowedSessions(datetime now)
  {
   MqlDateTime t;
   TimeToStruct(now,t);

   int currentMin = t.hour*60 + t.min;

   string sessions = LoadSessions();
   if(sessions == "")
      return(false);

   string parts[];
   int count = StringSplit(sessions,',',parts);

   for(int i=0; i<count; i++)
     {
      string range = parts[i];
      StringTrimLeft(range);
      StringTrimRight(range);

      if(range == "")
         continue;

      int startMin,endMin;
      if(!ParseTimeRange(range,startMin,endMin))
         continue;

      if(currentMin >= startMin && currentMin < endMin)
         return(true);
     }

   return(false);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| GetNextSessionTime                                               |
//+------------------------------------------------------------------+
string GetNextSessionTime(datetime now)
  {
   MqlDateTime t;
   TimeToStruct(now,t);

   int currentMin = t.hour*60 + t.min;

   string sessions = LoadSessions();
   if(sessions == "")
      return("");

   string parts[];
   int count = StringSplit(sessions,',',parts);

   int    bestDiff = 24*60;
   string bestTime = "";

   for(int i=0; i<count; i++)
     {
      string range = parts[i];
      StringTrimLeft(range);
      StringTrimRight(range);

      if(range == "")
         continue;

      int startMin,endMin;
      if(!ParseTimeRange(range,startMin,endMin))
         continue;

      int diff;
      if(currentMin < startMin)
         diff = startMin - currentMin;
      else
         if(currentMin >= endMin)
            diff = (24*60 - currentMin) + startMin;
         else
            diff = 0;

      if(diff < bestDiff)
        {
         bestDiff = diff;
         bestTime = StringSubstr(range,0,5);
        }
     }

   return(bestTime);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| LoadNewsEvents                                                   |
//| Binary read + manual CSV parsing                                 |
//+------------------------------------------------------------------+
bool LoadNewsEvents()
  {
   ArrayResize(s_newsEvents,0);
   if(!FileIsExist(NEWS_FILE))
     {
      s_newsCount = 0;
      return(false);
     }

   datetime curTime = FileModificationTime(NEWS_FILE);
   if(curTime == s_newsFileTime && s_newsCount > 0)
      return(true);

   int handle = FileOpen(NEWS_FILE, FILE_READ|FILE_BIN);
   if(handle == INVALID_HANDLE)
     {
      s_newsCount = 0;
      return(false);
     }

   uchar bytes[];
   FileReadArray(handle,bytes);
   FileClose(handle);

   string content = CharArrayToString(bytes,0,WHOLE_ARRAY,CP_ACP);
   if(content == "")
     {
      s_newsCount = 0;
      return(false);
     }

   string lines[];
   int lineCount = StringSplit(content,'\n',lines);
   int eventCount = 0;

   for(int i=0; i<lineCount; i++)
     {
      string line = lines[i];
      StringTrimLeft(line);
      StringTrimRight(line);
      if(line == "")
         continue;

      string parts[];
      int partCount = StringSplit(line,',',parts);
      if(partCount < 3)
         continue;

      string dtStr   = parts[0];
      string preStr  = parts[1];
      string postStr = parts[2];

      StringReplace(dtStr,"\r","");
      StringReplace(preStr,"\r","");
      StringReplace(postStr,"\r","");

      datetime t   = StringToTime(dtStr);
      int      pre = (int)StringToInteger(preStr);
      int      post= (int)StringToInteger(postStr);

      if(t > 0)
        {
         int sz = ArraySize(s_newsEvents);
         ArrayResize(s_newsEvents,sz+1);
         s_newsEvents[sz].time         = t;
         s_newsEvents[sz].preBlackout  = pre;
         s_newsEvents[sz].postBlackout = post;
         eventCount++;
        }
     }

   s_newsCount    = eventCount;
   s_newsFileTime = curTime;
   return(s_newsCount > 0);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| IsNewsBlackout                                                   |
//+------------------------------------------------------------------+
bool IsNewsBlackout(datetime now)
  {
   if(s_newsCount <= 0)
      return(false);

   int size = ArraySize(s_newsEvents);
   if(size < s_newsCount)
      s_newsCount = size;

   for(int i=0; i<s_newsCount; i++)
     {
      datetime start = s_newsEvents[i].time - s_newsEvents[i].preBlackout*60;
      datetime end   = s_newsEvents[i].time + s_newsEvents[i].postBlackout*60;

      if(now >= start && now <= end)
         return(true);
     }

   return(false);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| GetNextNewsTime                                                  |
//+------------------------------------------------------------------+
datetime GetNextNewsTime(datetime now)
  {
   if(s_newsCount <= 0)
      return(0);

   int size = ArraySize(s_newsEvents);
   if(size < s_newsCount)
      s_newsCount = size;

   datetime next = 0;
   for(int i=0; i<s_newsCount; i++)
     {
      if(s_newsEvents[i].time > now && (next == 0 || s_newsEvents[i].time < next))
         next = s_newsEvents[i].time;
     }
   return(next);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| IsTradingAllowed                                                 |
//+------------------------------------------------------------------+
bool IsTradingAllowed(datetime now)
  {
   bool sessionOK = IsWithinAllowedSessions(now);
   bool newsOK    = !IsNewsBlackout(now);
   return(sessionOK && newsOK);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Refresh                                                          |
//+------------------------------------------------------------------+
bool Refresh()
  {
   datetime now = TimeCurrent();
   if(now - s_lastRefresh < s_refreshInterval)
      return(false);

   LoadNewsEvents();

   s_allowedNow  = IsTradingAllowed(now);
   s_nextSession = GetNextSessionTime(now);

   datetime nextNews = GetNextNewsTime(now);
   if(nextNews > 0)
     {
      s_nextNews     = TimeToString(nextNews,TIME_DATE|TIME_MINUTES);
      s_nextNewsTime = nextNews;
     }
   else
     {
      s_nextNews     = "None";
      s_nextNewsTime = 0;
     }

   s_lastRefresh = now;
   return(true);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| LogBlockedAttempt                                                |
//+------------------------------------------------------------------+
void LogBlockedAttempt(datetime time,string symbol,string reason,string source)
  {
   int handle = FileOpen(LOG_FILE,FILE_TXT|FILE_READ|FILE_WRITE|FILE_CSV,',');
   if(handle == INVALID_HANDLE)
      return;

   FileSeek(handle,0,SEEK_END);
   FileWrite(handle,TimeToString(time),symbol,reason,source);
   FileClose(handle);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ReadLog                                                          |
//| Safe version for dashboard (last N entries)                      |
//+------------------------------------------------------------------+
int ReadLog(string &times[],string &symbols[],string &reasons[],string &sources[],int max=5)
  {
   ArrayResize(times,0);
   ArrayResize(symbols,0);
   ArrayResize(reasons,0);
   ArrayResize(sources,0);

   if(!FileIsExist(LOG_FILE))
      return(0);

   int handle = FileOpen(LOG_FILE,FILE_TXT|FILE_READ|FILE_CSV,',');
   if(handle == INVALID_HANDLE)
      return(0);

   string tmpT[],tmpSym[],tmpR[],tmpSrc[];
   int total = 0;

   while(!FileIsEnding(handle))
     {
      string t   = FileReadString(handle);
      string s   = FileReadString(handle);
      string r   = FileReadString(handle);
      string src = FileReadString(handle);
      if(s == "")
         continue;

      total++;
      ArrayResize(tmpT,total);
      ArrayResize(tmpSym,total);
      ArrayResize(tmpR,total);
      ArrayResize(tmpSrc,total);

      tmpT[total-1]   = t;
      tmpSym[total-1] = s;
      tmpR[total-1]   = r;
      tmpSrc[total-1] = src;
     }
   FileClose(handle);

   if(total == 0)
      return(0);

   int resultCount = (total > max) ? max : total;
   ArrayResize(times,resultCount);
   ArrayResize(symbols,resultCount);
   ArrayResize(reasons,resultCount);
   ArrayResize(sources,resultCount);

   int startIdx = total - resultCount;
   for(int i=0; i<resultCount; i++)
     {
      times[i]   = tmpT[startIdx+i];
      symbols[i] = tmpSym[startIdx+i];
      reasons[i] = tmpR[startIdx+i];
      sources[i] = tmpSrc[startIdx+i];
     }

// reverse order (newest first)
   for(int i=0; i<resultCount/2; i++)
     {
      int j = resultCount-1-i;
      string temp;

      temp=times[i];
      times[i]=times[j];
      times[j]=temp;
      temp=symbols[i];
      symbols[i]=symbols[j];
      symbols[j]=temp;
      temp=reasons[i];
      reasons[i]=reasons[j];
      reasons[j]=temp;
      temp=sources[i];
      sources[i]=sources[j];
      sources[j]=temp;
     }

   return(resultCount);
  }
//+------------------------------------------------------------------+

//--- getters (compact)
bool     IsAllowedNow()          { return s_allowedNow; }
string   GetNextSession()        { return s_nextSession; }
string   GetNextNews()           { return s_nextNews; }
datetime GetNextNewsTimeRaw()    { return s_nextNewsTime; }
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
