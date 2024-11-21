//+------------------------------------------------------------------+
//|                                           CollectPatternData.mq5 |
//|                                                   Pavel Chigirev |
//|                                        https://pavelchigirev.com |
//+------------------------------------------------------------------+
#property copyright "Pavel Chigirev"
#property link      "https://pavelchigirev.com"

#include "..\\..\\..\\Include\\Generic\\ArrayList.mqh"
#include "..\\..\\..\\Include\\pccom\\DL\\DataLogger.mqh"

input color Pattern1Color = clrRed; 
input color Pattern0Color = clrWhite;
input string PathToDataFolder = "c:\\Users\\PC\\Documents\\PC.com\\DL\\";

class PatternData 
{
public:

   string name;
   datetime startTime;
   datetime endTime;
   string patternClass;
   
   PatternData(string pName, datetime pStartTime, datetime pEndTime, string pPatternClass)
   {
      name = pName;
      startTime = pStartTime;
      endTime = pEndTime;
      patternClass = pPatternClass;
   }
};

class PatternDataComparer : public IComparer<PatternData*>
{
public:
   int Compare(PatternData* x, PatternData* y) 
   { 
      if(x.startTime > y.startTime)
         return(1);
      else if(x.startTime < y.startTime)
         return(-1);
      else
         return(0);
   }
};

void GetPatternStartEndDates
(
   datetime d0, 
   datetime d1,
   datetime d2,
   datetime d3,
   datetime& startTime, 
   datetime& endTime
)
{
   startTime = MathMin(MathMin(d0, d1), MathMin(d2, d3));
   endTime = MathMax(MathMax(d0, d1), MathMax(d2, d3));
}

void CollectData()
{
   DataLogger* dlTraining = new DataLogger("dataset_", "_training");
   DataLogger* dlTest = new DataLogger("dataset_", "_test");
 
   int totalObjects = ObjectsTotal(0, 0, OBJ_RECTANGLE); 
   string objectName;
   color objColor;
   string patternClass;
   datetime startTime, endTime;
   int barIndexEnd;

   CArrayList<PatternData*>* patterns = new CArrayList<PatternData*>();
   int count = 0;

   for(int i = 0; i < totalObjects; i++)
   {
      objectName = ObjectName(0, i, 0, OBJ_RECTANGLE);
      objColor = (color)ObjectGetInteger(0, objectName, OBJPROP_COLOR);
      if (objColor == Pattern1Color || objColor == Pattern0Color)
      {
         patternClass = objColor == Pattern1Color ? "1" : "0";
         datetime startTime, endTime;
         GetPatternStartEndDates((datetime)ObjectGetInteger(0, objectName, OBJPROP_TIME, 0), 
                                 (datetime)ObjectGetInteger(0, objectName, OBJPROP_TIME, 1),
                                 (datetime)ObjectGetInteger(0, objectName, OBJPROP_TIME, 2),
                                 (datetime)ObjectGetInteger(0, objectName, OBJPROP_TIME, 3),
                                 startTime, endTime);
         
         patterns.Add(new PatternData(objectName, startTime, endTime, patternClass));
      }
   }

   PatternDataComparer* pdc = new PatternDataComparer();
   patterns.Sort(0, patterns.Count(), pdc);
   delete pdc;

   int patternSize = INT_MAX;
   for(int i = 0; i < patterns.Count(); i++)
   {
      PatternData* pd;
      patterns.TryGetValue(i, pd);
      startTime = pd.startTime;
      endTime = pd.endTime;
      
      int size = 0;
      if (pd.patternClass == "1")
      {
         size = iBarShift(_Symbol, _Period, startTime, true) - iBarShift(_Symbol, _Period, endTime, true) + 1;
      
         if (size < patternSize)
            patternSize = size;
      }
      Print(TimeToString(startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + " -> " + TimeToString(endTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ": Class:" + pd.patternClass + " Length:" + (size > 0 ? IntegerToString(size) : "") + " " + pd.name);
   }

   Print("Pattern size is " + IntegerToString(patternSize) + " bars");
   Print("Patterns count is " + IntegerToString(patterns.Count()));

   int class1Cnt = 0, class0Cnt = 0;
   for(int i = 0; i < patterns.Count(); i++)
   {
      PatternData* pd;
      patterns.TryGetValue(i, pd);
   
      objectName = pd.name;
      endTime = pd.endTime;
      barIndexEnd = iBarShift(_Symbol, _Period, endTime, true);

      string tdDataLine = TimeToString(endTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "::["; 
      for (int k = barIndexEnd + patternSize; k >= barIndexEnd; k--) 
      {
         if (k >= 0 && k < Bars(_Symbol, _Period))
         {
            datetime barTime = iTime(_Symbol, _Period, k);
            double open = iOpen(_Symbol, _Period, k);
            double high = iHigh(_Symbol, _Period, k);
            double low = iLow(_Symbol, _Period, k);
            double close = iClose(_Symbol, _Period, k);
            tdDataLine += StringFormat("[%s, %g, %g, %g, %g],", TimeToString(barTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS), open, high, low, close);
         }
      }
       
      tdDataLine.Truncate(tdDataLine.Length() - 1);
      tdDataLine += "]::" + pd.patternClass;
      
      if (patternClass == "1")
      {
         class1Cnt++;
         if (class1Cnt % 5 == 0)
            dlTest.AddLine(tdDataLine);
         else
            dlTraining.AddLine(tdDataLine);
      }
      else
      {
         class0Cnt++;
         if (class0Cnt % 5 == 0)
            dlTest.AddLine(tdDataLine);
         else
            dlTraining.AddLine(tdDataLine);
      }
      
      delete pd;
   }
   
   dlTraining.WriteToFile(PathToDataFolder);
   dlTest.WriteToFile(PathToDataFolder);
   
   // Cleanup
   delete patterns;
   delete dlTraining;
   delete dlTest;
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   CollectData();
   ExpertRemove();
   
   return(INIT_SUCCEEDED);
}
