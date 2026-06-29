//+------------------------------------------------------------------+
//|                                             TradingHoursNews.mqh |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"

namespace THN
{
const string SESSIONS_FILE = "TradingSessions.txt";
const string NEWS_FILE     = "NewsEvents.csv";
const string LOG_FILE      = "HoursNewsLog.csv";

static datetime s_lastRefresh    = 0;
static int      s_refreshInterval= 1;
static bool     s_allowedNow     = true;
static string   s_nextSession    = "";
static string   s_nextNews       = "";
static datetime s_nextNewsTime   = 0;

struct NewsEvent
  {
   datetime time;
   int      preBlackout;
   int      postBlackout;
  };
static NewsEvent s_newsEvents[];
static int       s_newsCount = 0;

static string   s_cachedSessions   = "";
static datetime s_sessionsFileTime = 0;
static datetime s_newsFileTime = 0;

//--- helper: file modification time
datetime FileModificationTime(string filename)
  {
   if(!FileIsExist(filename)) return 0;
   int handle = FileOpen(filename, FILE_READ|FILE_BIN);
   if(handle == INVALID_HANDLE) return 0;
   datetime mod = (datetime)FileGetInteger(handle, FILE_MODIFY_DATE);
   FileClose(handle);
   return mod;
  }

//--- load sessions (unchanged)
string LoadSessions()
  {
   datetime cur = FileModificationTime(SESSIONS_FILE);
   if(cur == s_sessionsFileTime && s_cachedSessions != "")
      return s_cachedSessions;
   if(!FileIsExist(SESSIONS_FILE)) return "";
   int handle = FileOpen(SESSIONS_FILE, FILE_TXT|FILE_READ);
   if(handle == INVALID_HANDLE) return "";
   string data = FileReadString(handle);
   FileClose(handle);
   s_cachedSessions = data;
   s_sessionsFileTime = cur;
   return data;
  }

bool ParseTimeRange(string range, int &startMin, int &endMin)
  {
   string parts[];
   if(StringSplit(range, '-', parts) != 2) return false;
   int h1,m1,h2,m2;
   string p[];
   if(StringSplit(parts[0], ':', p) != 2) return false;
   h1 = (int)StringToInteger(p[0]); m1 = (int)StringToInteger(p[1]);
   if(StringSplit(parts[1], ':', p) != 2) return false;
   h2 = (int)StringToInteger(p[0]); m2 = (int)StringToInteger(p[1]);
   if(h1<0||h1>23||m1<0||m1>59||h2<0||h2>23||m2<0||m2>59) return false;
   startMin = h1*60 + m1;
   endMin   = h2*60 + m2;
   return true;
  }

bool IsWithinAllowedSessions(datetime now)
  {
   MqlDateTime t;
   TimeToStruct(now, t);
   int curr = t.hour*60 + t.min;
   string sessions = LoadSessions();
   if(sessions == "") return false;
   string parts[];
   int count = StringSplit(sessions, ',', parts);
   for(int i=0; i<count; i++)
     {
      string r = parts[i];
      StringTrimLeft(r); StringTrimRight(r);
      if(r == "") continue;
      int start, end;
      if(!ParseTimeRange(r, start, end)) continue;
      if(curr >= start && curr < end) return true;
     }
   return false;
  }

string GetNextSessionTime(datetime now)
  {
   MqlDateTime t;
   TimeToStruct(now, t);
   int curr = t.hour*60 + t.min;
   string sessions = LoadSessions();
   if(sessions == "") return "";
   string parts[];
   int count = StringSplit(sessions, ',', parts);
   int bestDiff = 24*60;
   string bestTime = "";
   for(int i=0; i<count; i++)
     {
      string r = parts[i];
      StringTrimLeft(r); StringTrimRight(r);
      if(r == "") continue;
      int start, end;
      if(!ParseTimeRange(r, start, end)) continue;
      int diff;
      if(curr < start) diff = start - curr;
      else diff = (24*60 - curr) + start;
      if(diff < bestDiff)
        {
         bestDiff = diff;
         int h = start / 60;
         int m = start % 60;
         bestTime = StringFormat("%02d:%02d", h, m);
        }
     }
   return bestTime;
  }

//--- ****** FIXED: robust news loading (handles UTF-8, UTF-16, ANSI) ******
bool LoadNewsEvents()
  {
   ArrayResize(s_newsEvents, 0);
   s_newsCount = 0;
   
   if(!FileIsExist(NEWS_FILE))
     {
      Print("[THN] News file not found: ", NEWS_FILE);
      return false;
     }
   
   datetime cur = FileModificationTime(NEWS_FILE);
   if(cur == s_newsFileTime && s_newsCount>0) return true;
   
   //--- read as binary to avoid encoding issues
   int handle = FileOpen(NEWS_FILE, FILE_READ|FILE_BIN);
   if(handle == INVALID_HANDLE)
     {
      Print("[THN] Cannot open news file. Error: ", GetLastError());
      return false;
     }
   
   uchar bytes[];
   FileReadArray(handle, bytes);
   FileClose(handle);
   
   //--- try UTF-8 first, then ANSI
   string content = CharArrayToString(bytes, 0, WHOLE_ARRAY, CP_UTF8);
   if(StringLen(content) == 0)
      content = CharArrayToString(bytes, 0, WHOLE_ARRAY, CP_ACP);
   if(StringLen(content) == 0)
     {
      Print("[THN] Failed to decode news file content.");
      return false;
     }
   
   //--- split into lines
   string lines[];
   int lineCount = StringSplit(content, '\n', lines);
   int eventsAdded = 0;
   
   for(int i=0; i<lineCount; i++)
     {
      string line = lines[i];
      //--- remove carriage return and trim
      StringReplace(line, "\r", "");
      StringTrimLeft(line);
      StringTrimRight(line);
      if(line == "") continue;
      
      //--- remove possible UTF-8 BOM (EF BB BF) which may appear as first characters
      if(StringGetCharacter(line, 0) == 0xFEFF)
         line = StringSubstr(line, 1);
      
      //--- split by comma
      string parts[];
      int partsCount = StringSplit(line, ',', parts);
      if(partsCount < 3)
        {
         Print("[THN] Line ", i+1, " invalid (need 3 columns): '", line, "'");
         continue;
        }
      
      string dtStr = parts[0];
      string preStr = parts[1];
      string postStr = parts[2];
      //--- clean any leftover
      StringTrimLeft(dtStr); StringTrimRight(dtStr);
      StringTrimLeft(preStr); StringTrimRight(preStr);
      StringTrimLeft(postStr); StringTrimRight(postStr);
      
      datetime dt = StringToTime(dtStr);
      if(dt == 0)
        {
         Print("[THN] Line ", i+1, " invalid date: '", dtStr, "'");
         continue;
        }
      int pre = (int)StringToInteger(preStr);
      int post = (int)StringToInteger(postStr);
      
      int sz = ArraySize(s_newsEvents);
      ArrayResize(s_newsEvents, sz+1);
      s_newsEvents[sz].time = dt;
      s_newsEvents[sz].preBlackout = pre;
      s_newsEvents[sz].postBlackout = post;
      eventsAdded++;
      Print("[THN] Loaded news: ", TimeToString(dt), " pre=", pre, " post=", post);
     }
   
   s_newsCount = eventsAdded;
   s_newsFileTime = cur;
   Print("[THN] Total news events loaded: ", s_newsCount);
   return s_newsCount > 0;
  }

bool IsNewsBlackout(datetime now)
  {
   LoadNewsEvents();
   for(int i=0; i<s_newsCount; i++)
     {
      if(i >= ArraySize(s_newsEvents)) break;
      datetime start = s_newsEvents[i].time - s_newsEvents[i].preBlackout*60;
      datetime end   = s_newsEvents[i].time + s_newsEvents[i].postBlackout*60;
      if(now >= start && now <= end) return true;
     }
   return false;
  }

datetime GetNextNewsTime(datetime now)
  {
   LoadNewsEvents();
   datetime next = 0;
   for(int i=0; i<s_newsCount; i++)
     {
      if(i >= ArraySize(s_newsEvents)) break;
      if(s_newsEvents[i].time > now && (next == 0 || s_newsEvents[i].time < next))
         next = s_newsEvents[i].time;
     }
   return next;
  }

bool Refresh()
  {
   datetime now = TimeCurrent();
   if(now - s_lastRefresh < s_refreshInterval) return false;
   
   LoadNewsEvents();
   s_allowedNow = IsWithinAllowedSessions(now) && !IsNewsBlackout(now);
   s_nextSession = GetNextSessionTime(now);
   
   datetime nxt = GetNextNewsTime(now);
   if(nxt > 0)
     {
      s_nextNews = TimeToString(nxt, TIME_DATE|TIME_MINUTES);
      s_nextNewsTime = nxt;
      Print("[THN] Next news: ", s_nextNews);
     }
   else
     {
      s_nextNews = "None";
      s_nextNewsTime = 0;
      Print("[THN] No future news events found.");
     }
   
   s_lastRefresh = now;
   return true;
  }

bool IsAllowedNow() { return s_allowedNow; }
string GetNextSession() { return s_nextSession; }
string GetNextNews() { return s_nextNews; }
datetime GetNextNewsTimeRaw() { return s_nextNewsTime; }

void LogBlockedAttempt(datetime time, string symbol, string reason, string source)
  {
   int handle = FileOpen(LOG_FILE, FILE_TXT|FILE_READ|FILE_WRITE|FILE_CSV, ',');
   if(handle == INVALID_HANDLE) return;
   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle, TimeToString(time), symbol, reason, source);
   FileClose(handle);
  }
}