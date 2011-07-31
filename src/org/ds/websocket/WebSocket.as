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
	import flash.events.Event;
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
		private static const MaxBytes	:uint	= 20 * 1024 * 1024;
		public  static const Closed	    :String = "Closed";
		public  static const Connecting	:String = "Connecting";
		private static const Negotiating:String = "Negotiating";
		public 	static const Connected	:String = "Connected";
		private static const Matcher	:RegExp	= /^(wss?)\:\/\/([^\/|\:]+)(\:(\d+))?(\/.*)?$/i;
		
		private static const Unknown	:uint	= 1;
		private static const FixedLen	:uint	= 2;
		private static const HighOrder	:uint	= 3;
		
		public static function isValidURI(uri:String):Boolean {
			return Matcher.test(uri);
		}
		
		/**
		 * Instance Properties & Methods
		 */ 
		
		private var socket		:Socket;
		private var settings	:Object;
		private var headers		:Object     = {};
		private var headersum	:uint		= 0;
		private var queue		:Array      = [];
		private var buffer		:ByteArray	= new ByteArray();
		private var byte		:uint		= 0;
		private var frameType	:uint		= Unknown;

		public function WebSocket(host:String)
		{
			super(Closed);

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
				socket.writeByte(0xFF);
				socket.writeByte(0x00);
				socket.flush();
				socket.close();
			}
		}
		
		/**
		 * Send a UTF encoded message to the server
		 */ 
		public function send(message:String):void {
			if(state == Connected) {
				socket.writeByte(0x00);
				socket.writeUTFBytes(message);
				socket.writeByte(0xff);
				socket.flush();
			} else {
				queue.push(message);
			}
		}
		
		/**
		 * Take a nice WebSocket URI and break it into
		 * it's usable parts (domain, port, path)
		 */ 
		private function parseUri(uri:String):Object {
			if(!isValidURI(uri)) {
				throw new Error("Invalid WebSocket URI... Exiting");
			}
			
			var parsed:* = Matcher.exec(uri);
			var result:* = {
				scheme	: parsed[1],
				domain	: parsed[2],
				path	: parsed[5] || "/",
				port	: parsed[4] ? parsed[4] : (parsed[1] == "ws" ? 80 : 443),
				host	: parsed[2] + (parsed[4] ? ":" + parsed[4] : "")
			};
				
			return result;
		}
		
		/**
		 * Once the socket connection is open, we send
		 * out the HTTP style headers to handshake and
		 * negotiate the connection
		 */ 
		private function onOpen(e:Event):void {
			state = Negotiating;
			socket.writeUTFBytes(
				StringUtil.substitute(""
					+ "GET {1} HTTP/1.1{0}"
					+ "Upgrade: WebSocket{0}"
					+ "Connection: Upgrade{0}"
					+ "Host: {2}{0}"
					+ "Origin: null{0}{0}", "\r\n", settings.path, settings.host)
			);
			socket.flush();
		}
		
		/**
		 * If the state is Negotiating, then we expect a
		 * http style header response, and we parse it out.
		 * Otherwise, we treat the data as web socket frames
		 * and parse the data out based on the frame type
		 */ 
		private function onSocketEvent(e:ProgressEvent):void {
			
			if(state == Negotiating) {				
				completeHandshake();
				if(state == Negotiating) {
					return;
				}
			}

			while (socket.connected && socket.bytesAvailable > 0) {
									
				byte = socket.readUnsignedByte();
				
				if(frameType == Unknown) {

					buffer.clear();
					buffer.position = 0;
					
					if((byte & 0x80) == 0x80)  {
						
						/*frameType = FixedLen;
						
						var len	:uint = 0;
						var bv  :uint = 0;
						
						while(true) {
							byte = socket.readUnsignedByte();
							bv   = byte & 0x7f;
							len	 = len * 128 + bv;
							if((byte & 0x80) != 0x80) {
								break;
							}
						}

						if(len > MaxBytes) {
							return close("Max Frame Size exceeded!  Exiting");
						}
						
						if(byte == 0xff && len == 0) {
							close();
						}

						bytesLeft = len;*/
						
					} else if(byte == 0x00) {
						frameType = HighOrder;
					} else {
						Logger.debug("Invalid byte, expected 0x00 or 0x80+");
					}
					
				} else if(frameType == FixedLen) {

					/*if(bytesLeft > 0 && socket.bytesAvailable > 0) {
						
						var bytes:uint = Math.min(bytesLeft, socket.bytesAvailable);
						
						bytesLeft = bytesLeft - bytes;
						buffer.writeBytes(socket, 0, bytes);
						
						if(bytesLeft == 0) {
							dispatchEvent(new WebSocketEvent(WebSocketEvent.MESSAGE, buffer.readUTFBytes(buffer.length), this));
							frameType = Unknown;
						}
					} else {
						frameType = Unknown;
					}*/
				
				} else if(frameType == HighOrder) {

					if(byte == 0xFF) {
						buffer.position = 0;
						dispatchEvent(new WebSocketEvent(WebSocketEvent.MESSAGE, buffer.readUTFBytes(buffer.length), this));
						frameType = Unknown;
					} else {
						buffer.writeByte(byte);
					}
				}
			}
			
		}

		private function completeHandshake():void {

			while(socket.bytesAvailable > 0) {
				
				byte = socket.readByte();
				buffer.writeByte(byte);

				if(byte == 0x0a || byte == 0x0d) { //\n or \r
					headersum += byte;
				} else {
					headersum = 0;
				}
				
				if(headersum == 0x2e) { //\r\n\r\n

					buffer.position = 0;
					
					var response:String = buffer.readUTFBytes(buffer.length);
					var entries	:Array  = response.split(/\r\n/);
					
					if(!entries[0].match(/HTTP\/1.1 101/)) {
						return close("Invalid Response Header");
					}
					
					//get 2nd to last header (omit empties)
					for(var i:int = 1;i < entries.length - 2;i++) {
						var kvp:Array = entries[i].match(/^(\S+):\s+(.+)$/);
						if(!kvp) {
							return close("Invalid header: " + entries[i]);
						}
						headers[kvp[1]] = kvp[2];
					}

					if(headers["Connection"] != "Upgrade") {
						return close("Invalid connection!");
					}
					
					if(headers["Upgrade"] != "WebSocket") {
						return close("Invalid upgrade!");
					}

					state = Connected;

					return;
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
				config.trustSelfSignedCertificates = true;
				config.ignoreCommonNameMismatch = true;
				socket = new TLSSocket(null, 0, config);
			} else {*/
			//}
			
			socket = new Socket();
			socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketEvent);
			socket.addEventListener(Event.CONNECT, onOpen);
			socket.addEventListener(Event.CLOSE, onClose);
			socket.addEventListener(IOErrorEvent.IO_ERROR, onClose);
			socket.connect(settings.domain, int(settings.port));
		}
	}
}