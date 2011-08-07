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
package org.ds.websocket
{
	import com.hurlant.crypto.tls.*;
	import com.hurlant.util.Base64;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	
	import mx.utils.StringUtil;
	
	import org.ds.fsm.StateMachine;
	import org.ds.logging.Logger;
	
	public class WebSocket extends StateMachine
	{
		/**
		 * Class Properties & Methods
		 */
		public  static const Closed     :String = "Closed";
		public  static const Connecting :String = "Connecting";
		private static const Negotiating:String = "Negotiating";
		public  static const Connected  :String = "Connected";
		
		
		/**
		 * Instance Properties & Methods
		 */ 
		
		private var socket:Socket;
		private var settings:Object;
		private var queue:Array = [];
		
		private var decoder:WebSocketDecoder = new WebSocketDecoder();
		private var negotiator:WebSocketNegotiator = new WebSocketNegotiator();
		private var processor:WebSocketProcessor = negotiator;
		
		
		public function WebSocket(host:String)
		{
			super(Closed);
			
			negotiator.addEventListener(WebSocketNegotiator.Complete, function():void {
				processor = decoder;
				state = Connected;
			});
			
			negotiator.addEventListener(WebSocketNegotiator.Failed, function():void {
				close();
			});
			
			decoder.addEventListener(WebSocketEvent.MESSAGE, function(e:WebSocketEvent):void {
				dispatchEvent(e);
			});
			
			defineTransition("*", Connected, flushQueue);
			settings = parseUri(host);
			
			connect();
		}
		
		
		public function get secure():Boolean {
			return settings.scheme == "wss";
		}
		
		/**
		 * Initiate closing handshake and close the connection
		 */ 
		public function close(message:String=null):void {
			if(message) {
				Logger.info(message);
			}
			if(socket.connected) {
				socket.writeByte(0x88);
				socket.writeByte(0);
				socket.flush();
				socket.close();
				state = Closed;
			}
		}
		
		/**
		 * Send a UTF encoded message to the server
		 */ 
		public function send(message:String):void {
			if(state == Connected) {
				var encoded:ByteArray = WebSocketEncoder.encode(message);
				if(encoded) {
					socket.writeBytes(encoded);
					socket.flush();
				}
			} else {
				queue.push(message);
			}
		}
		
		/**
		 * Take a nice WebSocket URI and break it into
		 * it's usable parts (domain, port, path)
		 */ 
		private function parseUri(uri:String):Object {
			
			var regex:RegExp = /^(wss?)\:\/\/([^\/|\:]+)(\:(\d+))?(\/.*)?$/i
			
			if(!regex.test(uri)) {
				throw new Error("Invalid WebSocket URI... Exiting");
			}
			
			var parsed:* = regex.exec(uri);
			var result:* = {
				scheme  : parsed[1],
				domain  : parsed[2],
				path  : parsed[5] || "/",
					port  : parsed[4] ? parsed[4] : (parsed[1] == "ws" ? 80 : 443),
					host  : parsed[2] + (parsed[4] ? ":" + parsed[4] : "")
			};
			
			return result;
		}
		
		/**
		 * Once the socket connection is open, we send
		 * out the HTTP headers to setup the websocket
		 * connection.  We delegate processing to the
		 * a WebSocketNegotiator.
		 */ 
		private function onOpen(e:Event):void {
			state = Negotiating;
			socket.writeUTFBytes(
				negotiator.buildRequest(settings.host, settings.path)
			);
			socket.flush();
		}
		
		/**
		 * Delegate the to current processor. Either the
		 * WebSocketNegotiator or the
		 * WebSocketDecoder
		 */ 
		private function onSocketEvent(e:ProgressEvent):void {
			while(socket.bytesAvailable) {
				var result:* = processor.process(socket); 
				if(!result) {
					continue;
				} else if(result is String) {
					dispatchEvent(new WebSocketEvent(WebSocketEvent.MESSAGE, result));
				}
			}
		}
		
		private function onClose(e:Event):void {
			state = Closed;
		}
		
		private function flushQueue():void {
			while(queue.length > 0) {
				send(queue.shift());
			}
		}
		
		private function connect():void {
			state = Connecting;
			
			//increases the size of the swf 30 fold :(
			/*if(secure) {
			var config:TLSConfig = new TLSConfig(TLSEngine.CLIENT);
			//config.trustSelfSignedCertificates = true;
			//config.ignoreCommonNameMismatch = true;
			socket = new TLSSocket(null, 0, config);
			} else {
			socket = new Socket();
			}*/
			
			socket = new Socket();
			socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketEvent);
			socket.addEventListener(Event.CONNECT, onOpen);
			socket.addEventListener(Event.CLOSE, onClose);
			socket.addEventListener(IOErrorEvent.IO_ERROR, onClose);
			socket.connect(settings.domain, int(settings.port));
		}
	}
}