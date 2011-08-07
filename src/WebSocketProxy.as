/**
 ---------------------------------------------------------------------------
 
 Copyright (c) 2009 Dan Simpson
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 ---------------------------------------------------------------------------
 **/

package {
  
  import flash.display.Sprite;
  import flash.external.ExternalInterface;
  import flash.system.Security;
  
  import org.ds.fsm.StateEvent;
  import org.ds.logging.LogEvent;
  import org.ds.logging.Logger;
  import org.ds.websocket.WebSocket;
  import org.ds.websocket.WebSocketEvent;

  public class WebSocketProxy extends Sprite
  {
    private var logger :Logger = new Logger(1);
    private var socket :WebSocket;
    
    public function WebSocketProxy()
    {     
      Security.allowDomain("*");
      Security.allowInsecureDomain("*");
      
      if(ExternalInterface.available) {
        
        logger.addEventListener(LogEvent.ENTRY, function(e:LogEvent):void {
          ExternalInterface.call("WebSocketProxy.onlog", e.toString());
        });
        
        ExternalInterface.addCallback("open", this.open);
        ExternalInterface.addCallback("close", this.close);
        ExternalInterface.addCallback("send", this.send);
        
        ExternalInterface.call("WebSocketProxy.ready");
        
      } else {
        throw new Error("Unable to access External Interface");
      }     
    }
    
    private function open(uri:String):void {
	    try {
	      socket = new WebSocket(uri);
	      socket.addEventListener(WebSocketEvent.MESSAGE, onMessage);
	      socket.addEventListener(WebSocket.Closed, onClose);
	      socket.addEventListener(WebSocket.Connected, onOpen);
	    } catch(e:Error) {
	      Logger.info("Error creating websocket for URI", uri);
	      Logger.debug(e.getStackTrace());
	    }
    }
    
    private function close():void {
      if(socket) {
        socket.close();
	  }
    }
    
    private function send(message:String):void {
      if(socket) {
        socket.send(message);
      }
    }
    
    private function onOpen(e:StateEvent):void {
      ExternalInterface.call("WebSocketProxy.onopen");
    }
        
    private function onMessage(e:WebSocketEvent):void {
      ExternalInterface.call("WebSocketProxy.onmessage", e.data);
    }
    
    private function onClose(e:StateEvent):void {
      ExternalInterface.call("WebSocketProxy.onclose");
    }
  }
}
