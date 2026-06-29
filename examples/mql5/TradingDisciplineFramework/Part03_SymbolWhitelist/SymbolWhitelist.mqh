//+------------------------------------------------------------------+
//|                                              SymbolWhitelist.mqh |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.00"

//+------------------------------------------------------------------+
//| namespace SWL (Symbol WhiteList)                                 |
//+------------------------------------------------------------------+
namespace SWL
{
const string WHITELIST_FILE = "SymbolWhitelist.txt";
const string LOG_FILE       = "SymbolWhitelistLog.csv";

//+------------------------------------------------------------------+
//| Saves the whitelist string to file                               |
//+------------------------------------------------------------------+
bool SaveWhitelist(string whitelist)
  {
   int handle = FileOpen(WHITELIST_FILE,FILE_TXT|FILE_WRITE);
   if(handle==INVALID_HANDLE)
      return false;
   FileWrite(handle,whitelist);
   FileClose(handle);
   return true;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Loads the whitelist from file, returns as string                 |
//+------------------------------------------------------------------+
string LoadWhitelist()
  {
   if(!FileIsExist(WHITELIST_FILE))
      return "";
   int handle = FileOpen(WHITELIST_FILE,FILE_TXT|FILE_READ);
   if(handle==INVALID_HANDLE)
      return "";
   string data = FileReadString(handle);
   FileClose(handle);
   return data;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Parses a comma‑separated whitelist into an array of symbols      |
//+------------------------------------------------------------------+
int ParseWhitelist(string list,string &result[])
  {
   ArrayResize(result,0);
   if(list=="")
      return 0;
   string parts[];
   int count = StringSplit(list,',',parts);
   for(int i=0; i<count; i++)
     {
      string trimmed = parts[i];
      StringTrimLeft(trimmed);
      StringTrimRight(trimmed);
      if(trimmed!="")
        {
         int sz = ArraySize(result);
         ArrayResize(result,sz+1);
         result[sz] = trimmed;
        }
     }
   return ArraySize(result);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Checks if a given symbol is in the whitelist                     |
//+------------------------------------------------------------------+
bool IsSymbolAllowed(string symbol)
  {
   string list = LoadWhitelist();
   string allowed[];
   ParseWhitelist(list,allowed);
   for(int i=0; i<ArraySize(allowed); i++)
      if(StringCompare(allowed[i],symbol,false)==0)
         return true;
   return false;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Appends a blocked attempt to the log file                        |
//+------------------------------------------------------------------+
void LogBlockedAttempt(datetime time,string symbol,string source)
  {
   int handle = FileOpen(LOG_FILE,FILE_TXT|FILE_READ|FILE_WRITE|FILE_CSV,',');
   if(handle==INVALID_HANDLE)
      return;
   FileSeek(handle,0,SEEK_END);
   FileWrite(handle,TimeToString(time),symbol,source);
   FileClose(handle);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Reads the last N log entries (most recent first)                 |
//+------------------------------------------------------------------+
int ReadLog(string &times[],string &symbols[],string &sources[],int max=10)
  {
   ArrayResize(times,0);
   ArrayResize(symbols,0);
   ArrayResize(sources,0);
   if(!FileIsExist(LOG_FILE))
      return 0;

   int handle = FileOpen(LOG_FILE,FILE_TXT|FILE_READ|FILE_CSV,',');
   if(handle==INVALID_HANDLE)
      return 0;

   string tmpTime[], tmpSym[], tmpSrc[];
   while(!FileIsEnding(handle))
     {
      string t = FileReadString(handle);
      string s = FileReadString(handle);
      string src = FileReadString(handle);
      if(t!="" && s!="")
        {
         int sz = ArraySize(tmpTime);
         ArrayResize(tmpTime,sz+1);
         ArrayResize(tmpSym,sz+1);
         ArrayResize(tmpSrc,sz+1);
         tmpTime[sz] = t;
         tmpSym[sz] = s;
         tmpSrc[sz] = src;
        }
     }
   FileClose(handle);

   int total = ArraySize(tmpTime);
   int start = (total>max) ? total-max : 0;
   for(int i=total-1; i>=start; i--)
     {
      int sz = ArraySize(times);
      ArrayResize(times,sz+1);
      ArrayResize(symbols,sz+1);
      ArrayResize(sources,sz+1);
      times[sz] = tmpTime[i];
      symbols[sz] = tmpSym[i];
      sources[sz] = tmpSrc[i];
     }
   return ArraySize(times);
  }
//+------------------------------------------------------------------+
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
