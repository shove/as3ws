package org.ds.websocket
{
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	
	import org.ds.logging.Logger;
	
	public class WebSocketDecoder extends EventDispatcher implements WebSocketProcessor
	{		
		private var fragmented:Boolean = false;
		private var buffer:ByteArray;
		
		public function WebSocketDecoder() {
		}
		
		public function process(socket:Socket):* {
			
			var h1:uint = socket.readUnsignedByte();
			var h2:uint = socket.readUnsignedByte();
			
			// Check if this is the final frame of the
			// set... which is should be.
			if((h1 & 0x80) != 0x80) {
				fragmented = true;
				buffer = new ByteArray();
			} else {
				fragmented = false;
			}
			
			var op:uint = (h1 & 0x0F);
			var len:uint = 0x7F & h2;
			var mask:uint = 0;
			var masked:Boolean = (h2 & 0x80) == 0x80;
			
			if(len > 125) {
				if(len == 126) {
					len = socket.readUnsignedShort();
				} else {
					throw new Error("Message is too large");
				}
			}
			
			// It should always be masked, get the key
			// from the stream before we continue
			if(masked) {
				mask = socket.readUnsignedInt();
			}
			
			// Handle incomplete frame error
			if(socket.bytesAvailable < len) {
				throw new Error("Incomplete buffer");
			}
			
			// Read the data into an allocated buffer
			// for unmasking... or not (must be though)
			var data:ByteArray = new ByteArray();
			socket.readBytes(data, 0, len);
			
			if(masked) {
				for(var i:uint = 0; i < data.length;i++) {
					data[i] = (data[i] ^ (mask >>> ((3 - (i % 4)) * 8)));
				}
			}

			switch(op) {
				case WebSocketOps.CONTINUATION:
					buffer.writeBytes(data);
					if(!fragmented) {
						var result:String = buffer.readUTFBytes(buffer.length);
						buffer.clear();
						return result;
					}
					break;
				case WebSocketOps.TEXT_FRAME:
					if(!fragmented) {
						data.position = 0;
						return data.readUTFBytes(data.length);
					}
					buffer.writeBytes(data);
					break;
				case WebSocketOps.BINARY_FRAME:
					//TODO: Implement Support
					break;
				case WebSocketOps.CLOSE:
					socket.close();
					break;
				case WebSocketOps.PING:
					socket.writeByte(WebSocketOps.PONG | 0x80);
					socket.writeByte(0);
					socket.flush();
					break;
				case WebSocketOps.PONG:
					break;
				default:
					socket.close();
					break;
			}
			
			return false;
		}
	}
}