//+------------------------------------------------------------------+
//|                                                   DataLogger.mqh |
//|                                                   Pavel Chigirev |
//|                                        https://pavelchigirev.com |
//+------------------------------------------------------------------+
#property copyright "Pavel Chigirev"
#property link      "https://pavelchigirev.com"

#include "..\\..\\Generic\\ArrayList.mqh"
#include <Files\FileTxt.mqh>
#include <Tools\DateTime.mqh>

#import "shlwapi.dll"
bool PathFileExistsW(string path);
#import

#include <WinAPI\fileapi.mqh>
#include <WinAPI\winbase.mqh>
#include <WinAPI\sysinfoapi.mqh>
#include <WinAPI\errhandlingapi.mqh>
   
#import "shell32.dll" 
int ShellExecuteW(int hwnd, string operation, string file, string parameters, string directory, int showCmd); 
#import

class DataLogger
{
private:
   string _prefix, _postfix;
   CArrayList<string> _data;
   
public:
   DataLogger(string prefix, string postfix) : _prefix(prefix), _postfix(postfix)
   {
   }
   
   void AddLine(string dataLine)
   {
      _data.Add(dataLine);
   }
  
   void WriteToFile(string pathToReportFolder)
   {
      CFileTxt reportFile;
      int res = reportFile.Open("report2.csv", FILE_CSV|FILE_ANSI|FILE_WRITE);
      if (res < 0)
      {
         Print(__FUNCTION__ + " " + IntegerToString(__LINE__) + ": Cannot open file for writing");
         return;
      }
      
      int cnt = _data.Count();
      for (int i = 0; i < cnt; ++i)
      {
         string row;
         _data.TryGetValue(i, row);
         row += "\n";
         reportFile.WriteString(row);
      }
      
      _data.Clear();
      reportFile.Close();
      
      // Rename and move
      #define INVALID_FILE_ATTRIBUTES (-1)
      #define FILE_ATTRIBUTE_DIRECTORY (0x10)
      
      string originalFileName = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\report2.csv";
      SYSTEMTIME system_time;            
      GetLocalTime(system_time);
      string timeStr = StringFormat
      (
         "%0.4d.%0.2d.%0.2d %0.2d.%0.2d.%0.2d", 
         system_time.wYear, system_time.wMonth, system_time.wDay, 
         system_time.wHour, system_time.wMinute, system_time.wSecond
      );
            
      string filePath = pathToReportFolder + "\\" + _prefix + timeStr + _postfix + ".csv";
      for(int i = 2; i < 1000000; i++)
      {
         if(!PathFileExistsW(filePath))
            break;

         string n = "_("+(string)(i) + ")";
         filePath = pathToReportFolder + "\\" + _prefix + timeStr + n + _postfix + ".csv";               
      }

      StringReplace(filePath, "\\\\", "\\");
      uint ftyp = GetFileAttributesW(pathToReportFolder);

      bool directoryExists = ((ftyp != 0xffffffff) && (bool)(ftyp & FILE_ATTRIBUTE_DIRECTORY));
      if(!directoryExists)
         CreateDirectoryW(pathToReportFolder, 0);   

      if(!CopyFileW(originalFileName, filePath, false))
      {
         uint errorCode = kernel32::GetLastError();
         Print(__FILE__," ", __FUNCTION__," CopyFileW error code: ", errorCode);
      }
      
      #undef INVALID_FILE_ATTRIBUTES
      #undef FILE_ATTRIBUTE_DIRECTORY
   }
};