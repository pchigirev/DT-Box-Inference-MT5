//+------------------------------------------------------------------+
//|                                                      Sockets.mqh |
//|                                                   Pavel Chigirev |
//|                                        https://pavelchigirev.com |
//+------------------------------------------------------------------+
#property copyright "Pavel Chigirev"
#property link      "https://pavelchigirev.com"

#include "..\\Exception.mqh"
#include "..\\socketlib.mqh" 

#include "..\\..\\..\\Include\\Generic\\ArrayList.mqh"

class SocketClient
{
private:
   string _host;
   ushort _port;
   SOCKET64 _client;
   bool _isConnected;
   
   void closeClean()
   {
      if (_client != INVALID_SOCKET64)
      {
         if (shutdown(_client, SD_BOTH) == SOCKET_ERROR) 
         {
            Print(__FUNCTION__ + ": Shutdown failed error: " + WSAErrorDescript(WSAGetLastError()));
         }
         closesocket(_client); 
         _client = INVALID_SOCKET64;
      }
      
      WSACleanup();
      Print("Connection closed");
   }
   
//+------------------------------------------------------------------+

template<typename TValue>
void serialize(const TValue &value, uchar &byte_array[], int start = 0)
{
   union _u
   {
      TValue      value;
      uchar       bytes[sizeof(TValue)];
   } u;
   u.value = value;
   
   ArrayCopy(byte_array, u.bytes, start);
}

//+------------------------------------------------------------------+

template<typename TValue>
void deserialize(const char &byte_array[], TValue &value, int start = 0)
{
   union _u
   {
      TValue value;
      uchar bytes[sizeof(TValue)];
   } u;

   ArrayCopy(u.bytes, byte_array, 0, start, sizeof(TValue));
   value = u.value;
}
   
public:
   SocketClient(string host, ushort port) : _host(host), _port(port)
   {
      _client = INVALID_SOCKET64;
      _isConnected = false;
   }
   
   ~SocketClient()
   {
      if (_isConnected)
         Disconnect();
   }
   
   bool IsConnected() 
   { 
      return _isConnected; 
   }
   
   void Connect()
   {
      if (_isConnected)
         return;
      
      char wsaData[]; 
      ArrayResize(wsaData, sizeof(WSAData));
      int res = WSAStartup(MAKEWORD(2, 2), wsaData);
      if (res != 0) 
      { 
         Print(__FUNCTION__ + ": WSAStartup failed with error: " + string(res)); 
         StopEAOnError();
      }

      _client = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
      if (_client == INVALID_SOCKET64) 
      { 
         Print(__FUNCTION__ + ": Create failed with error: " + WSAErrorDescript(WSAGetLastError())); 
         closeClean(); 
         return; 
      }

      char c[]; 
      StringToCharArray(_host, c);
      sockaddr_in addrIn;
      addrIn.sin_family = AF_INET;
      addrIn.sin_addr.u.S_addr = inet_addr(c);
      addrIn.sin_port = htons(_port);
      ref_sockaddr ref; 
      ref.in = addrIn;
      
      res = connect(_client, ref.ref, sizeof(addrIn));
      if (res == SOCKET_ERROR)
      {
         int err = WSAGetLastError();
         if (err != WSAEISCONN) 
         { 
            Print(__FUNCTION__ + ": Connect failed with error: " + WSAErrorDescript(err)); 
            closeClean(); 
            return; 
         }
      }

      int nonBlock = 1;
      res = ioctlsocket(_client, (int)FIONBIO, nonBlock);
      if (res != NO_ERROR) 
      { 
         Print(__FUNCTION__ + ": ioctlsocket function failed with error: " + string(res)); 
         closeClean(); 
         return; 
      }
      
      _isConnected = true;
   }
   
   void Disconnect()
   {
      _isConnected = false;
      closeClean();
   }
   
   bool SendStr(string str)
   {
      uchar msg[];
      StringToCharArray(str, msg);
      return SendData(msg);   
   }
   
   bool SendData(uchar& data[])
   {
   	long size = ArraySize(data);
   	uchar sizeBuffer[8];
   	serialize(size, sizeBuffer);
   
   	// Send size
   	int err = send(_client, sizeBuffer, 8, 0);
   	if (err == SOCKET_ERROR)
   	{
   		Print(__FUNCTION__ + ": SendData failed with error " + WSAErrorDescript(WSAGetLastError())); 
   		Disconnect();
   		return false;
   	}
   
   	// Send data
   	err = send(_client, data, (int)size, 0);
   	if (err == SOCKET_ERROR)
   	{
   		Print(__FUNCTION__ + ": SendData failed with error " + WSAErrorDescript(WSAGetLastError())); 
   		Disconnect();
   		return false;
   	}
   
   	return true;
   }

   #define DEFAULT_BUFLEN 1024
   uchar _data[];
   bool ReceiveData(CArrayList<string>& recvCmds)
   {
      int cnt = 0;
   	do
   	{
   		int res = 0;
   		char buffer[DEFAULT_BUFLEN];
   		res = recv(_client, buffer, DEFAULT_BUFLEN, 0);
   		if (res == 0)
   		{
   			Print(__FUNCTION__ + ": ReceiveData: Connection closed");
   			Disconnect();
   			return false;
   		}
   		if (res < 0)
   		{
   			// Nothing to read
   			return true;
   		}
   
   		ArrayCopy(_data, buffer, ArraySize(_data), 0, res);
   		decodeData(_data, recvCmds);

   		cnt++;
   
   	} while (true); 
   }
   
   void decodeData(uchar& data[], CArrayList<string>& recvCmds)
   {
      int dataLen = ArraySize(data);
      if (dataLen >= 8)
      {
         long msgSize;
         uchar sizeBuffer[];
  			ArrayCopy(sizeBuffer, data, 0, 0, 8);
  			deserialize(sizeBuffer, msgSize);
         if (dataLen >= msgSize + 8)
         {
            uchar msgBuffer[];
            ArrayCopy(msgBuffer, data, 0, 8, (int)msgSize);
  			   string msg = CharArrayToString(msgBuffer);
  			   recvCmds.Add(msg);
  			   ArrayRemove(data, 0, uint(msgSize + 8));
  			   decodeData(data, recvCmds);
  		   }
  		}
   }
   
   bool ReceiveData_old(uchar& data[])
   {
   	long msgSize = -1;
   	do
   	{
   		int res = 0;
   		char buffer[DEFAULT_BUFLEN];
   		res = recv(_client, buffer, DEFAULT_BUFLEN, 0);
   		if (res == 0)
   		{
   			Print(__FUNCTION__ + ": ReceiveData: Connection closed");
   			return false;
   		}
   		if (res < 0)
   		{
   			Print(__FUNCTION__ + ": ReceiveData failed: " + WSAErrorDescript(WSAGetLastError())); 
   			return false;
   		}
   
   		ArrayCopy(data, buffer, 0, 0, res);
   
   		if (msgSize < 0 && ArraySize(data) >= 8)
   		{
   			uchar sizeBuffer[];
   			ArrayCopy(sizeBuffer, data, 0, 0, 8);
   			deserialize(sizeBuffer, msgSize);
   			if (msgSize <= 0)
   			{
   				Print(__FUNCTION__ + ": Incorrect message size ");
   				return false;
   			}
            ArrayRemove(data, 0, 8);
   		}
   
   	} while (msgSize <= 0 || ArraySize(data) < msgSize);
   
   	return true;
   }
};