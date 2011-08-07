package org.ds.websocket
{
	import com.hurlant.crypto.hash.SHA1;
	import com.hurlant.util.Base64;
	
	import flash.net.Socket;
	import flash.utils.ByteArray;
	
	import mx.utils.StringUtil;
	
	import org.ds.fsm.StateMachine;
	import org.ds.http.HttpHeaders;
	import org.ds.logging.Logger;
	
	public class WebSocketNegotiator extends StateMachine implements WebSocketProcessor
	{
		public static const Failed:String = "Failed";
		public static const Complete:String = "Complete";
		public static const Pending:String = "Pending";
		
		private var buffer:ByteArray = new ByteArray();
		private var quad:uint = 0;
		private var byte:uint = 0;
		
		private var key:String;
		
		public function WebSocketNegotiator() {
			super(Pending);
			
			defineTransition(Pending, Failed, onFail);
			defineTransition(Pending, Complete, onComplete);
		}
		
		public function process(socket:Socket):* {
			
			while(socket.bytesAvailable > 0) {
				
				byte = socket.readByte();
				quad = (quad << 8) | byte;
				
				// Add to our buffer
				buffer.writeByte(byte);
				
				// Check to see if we have 2x CRLF
				// signifying the end of the headers
				if(quad == 0x0d0a0d0a) {
					buffer.position = 0;
					
					var headers:HttpHeaders = new HttpHeaders(buffer);

					var valid:Boolean = 
						headers.existsAs("Connection", "Upgrade") &&
						headers.existsAs("Upgrade", "WebSocket") && 
						headers.existsAs("Sec-WebSocket-Accept", responseKey);
					
					state = valid ? Complete : Failed;
					
					return true;
				}
			}
			
			return false;
		}
		
		private function get responseKey():String {
			var buffer:ByteArray = new ByteArray();
			buffer.writeUTFBytes(key);
			buffer.writeUTFBytes("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
			return Base64.encodeByteArray(new SHA1().hash(buffer));
		}
		
		public function buildRequest(host:String, path:String):String {
			key = Base64.encode(new Date().getTime().toString(16));
			return StringUtil.substitute(""
				+ "GET {1} HTTP/1.1{0}"
				+ "Upgrade: websocket{0}"
				+ "Connection: Upgrade{0}"
				+ "Host: {2}{0}"
				+ "Sec-WebSocket-Key: {3}{0}"
				+ "Sec-WebSocket-Version: 8{0}"
				+ "Sec-WebSocket-Origin: null{0}{0}", "\r\n", path, host, key)
		}
		
		private function onFail():void {
			Logger.log("Handhsake failed due to invalid response");
		}
		
		private function onComplete():void {
			Logger.info("Handhsake completed");
		}
	}
}