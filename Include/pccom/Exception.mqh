//+------------------------------------------------------------------+
//|                                                    Exception.mqh |
//|                                                   Pavel Chigirev |
//|                                        https://pavelchigirev.com |
//+------------------------------------------------------------------+
#property copyright "Pavel Chigirev"
#property link      "https://pavelchigirev.com"

class Exception
{
public:
   string reason;
   
   Exception(string pReason)
   {
      reason = pReason;
   }
};
Exception* exceptionPtr;

void StopEAOnError()
{
   TesterStop();
   exceptionPtr.reason = "Stop on error";
}
