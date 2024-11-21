//+------------------------------------------------------------------+
//|                                               DT-MLIndicator.mq5 |
//|                                                   Pavel Chigirev |
//|                                        https://pavelchigirev.com |
//+------------------------------------------------------------------+
#property copyright "Pavel Chigirev"
#property link      "https://pavelchigirev.com"

#property indicator_separate_window
#property indicator_buffers       1
#property indicator_plots         1
#property indicator_type1         DRAW_LINE
#property indicator_color1        LightSeaGreen
#property indicator_minimum       -0.2
#property indicator_maximum       1.2
#property indicator_level1        0.0
#property indicator_level2        0.5
#property indicator_level3        1.0

#include "..\\..\\..\\Include\\pccom\\DL\\Sockets v1.1.mqh"
SocketClient* _sc;

input ushort ModelServingPort = 16505;
input int PrecalculateBars = 10000;

//--- indicator buffers
double ExtMLBuffer[];

const string cmd_new_connection = "cmd_nc";
const string cmd_init_data = "cmd_id";
const string cmd_next_data_point = "cmd_ndp";
const string cmd_close_connection = "cmd_cc";
const string cmd_heartbeat = "cmd_hb";
const string server_delim = ";";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ExtMLBuffer); 
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   UpdateShortName("DT-MLIndicator(Connecting to localhost:" + IntegerToString(ModelServingPort) + ")");
   
   _sc = new SocketClient("127.0.0.1", ModelServingPort);
   _sc.Connect();
   if (_sc.IsConnected())
   {
      bool isBacktest = (bool)MQLInfoInteger(MQL_TESTER) || (bool)MQLInfoInteger(MQL_VISUAL_MODE) || (bool)MQLInfoInteger(MQL_VISUAL_MODE);
      if (!isBacktest)
      {
         EventSetTimer(5);
      }
      
      UpdateShortName("DT-MLIndicator(Connected to localhost:" + IntegerToString(ModelServingPort) + ") " + (!isBacktest ? "Use HB" : "No HB"));
   }
   else
   {
      UpdateShortName("DT-MLIndicator(Connection failed...)");
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

void UpdateShortName(string name)
{
   IndicatorSetString(INDICATOR_SHORTNAME, name);
}

void OnTimer()
{
   if (_sc.IsConnected())
   {
      if (_sc.SendStr(cmd_heartbeat + server_delim))
      {   
         CArrayList<string> recvData;
         while(true)
         {
            if (!_sc.ReceiveData(recvData))
               break;
                  
            if (recvData.Count() > 0)
            {
               string predictionStr;
               if (recvData.TryGetValue(0, predictionStr))
               {
                  if (predictionStr != cmd_heartbeat)
                  {
                     UpdateShortName("DT-MLIndicator(Connection failed...)");
                     _sc.Disconnect();
                  }
               }
               break;
            }
         }
      }
   }
   else
   {
      UpdateShortName("DT-MLIndicator(Connection failed...)");
   }
}

void OnDeinit(const int reason)
{
   Print("Deinit called");
   EventKillTimer();
   _sc.SendStr(cmd_close_connection + server_delim);
   _sc.Disconnect();
   delete _sc;
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   if (_sc.IsConnected())
   {
      string mlRequest = "";
      if (prev_calculated == 0)
      {
         int startIdx = (rates_total - 1) - PrecalculateBars;
         if (startIdx < 0) startIdx = 0;
         for (int i = startIdx; i < rates_total - 1 && !IsStopped(); i++)
         {
            mlRequest += DoubleToString((high[i] + low[i]) / 2.0) + ",";
         }
         mlRequest = cmd_init_data + server_delim + mlRequest.Substr(0, mlRequest.Length() - 1);// + "]";
         
         if (_sc.SendStr(mlRequest))
         {
            CArrayList<string> recvData;
            while(true)
            {
               if (!_sc.ReceiveData(recvData))
                  break;
               if (recvData.Count() > 0)
               {
                  string predictionStr;
                  if (recvData.TryGetValue(0, predictionStr))
                  {
                     if (predictionStr == cmd_close_connection)
                     {
                        _sc.Disconnect();
                        break;
                     }
                  
                     string vals[];
                     int len = StringSplit(predictionStr, ',', vals);
                     for (int i = 0; i < len; ++i)
                     {
                        double prediction = StringToDouble(vals[i]);
                        ExtMLBuffer[startIdx + i] = prediction;
                     }
                  }
                  break;
               }
            }
         }
         ExtMLBuffer[rates_total - 1] = ExtMLBuffer[rates_total - 2];
         return rates_total - 1;
      }
      
      for (int i = prev_calculated; i < rates_total - 1 && !IsStopped(); i++)
      {
         string mlRequest = cmd_next_data_point + server_delim + DoubleToString((high[i] + low[i]) / 2.0);
         uint startMs = GetTickCount();
         if (_sc.SendStr(mlRequest))
         {
            CArrayList<string> recvData;
            while(true)
            {
               if (!_sc.ReceiveData(recvData))
                  break;
               if (recvData.Count() > 0)
               {
                  string predictionStr;
                  if (recvData.TryGetValue(0, predictionStr))
                  {
                     if (predictionStr == cmd_close_connection)
                     {
                        _sc.Disconnect();
                        break;
                     }
                  
                     double prediction = StringToDouble(predictionStr);
                     ExtMLBuffer[i] = prediction;
                  }
                  break;
               }
            }
         }
         uint endMs = GetTickCount();
         //Print(IntegerToString(endMs - startMs));
         ExtMLBuffer[rates_total - 1] = ExtMLBuffer[rates_total - 2];
      }
      return rates_total - 1;
   }
   else
   {
      UpdateShortName("DT-MLIndicator(Connection failed...)");
      ExtMLBuffer[rates_total - 1] = 0.0;
      return rates_total - 1;
   }
}
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
