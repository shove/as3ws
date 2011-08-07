package org.ds.websocket
{
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	
	public class WebSocketDecoder extends EventDispatcher implements WebSocketProcessor
	{
		private static const OP_CONTINUATION:uint = 0x0;
		private static const OP_TEXT_FRAME:uint = 0x1;
		private static const OP_BINARY_FRAME:uint = 0x2;
		private static const OP_CLOSE:uint = 0x8;
		private static const OP_PING:uint = 0x9;
		private static const OP_PONG:uint = 0xA;
		
		private var fragmented:Boolean = false;
		private var buffer:ByteArray;
		
		public function WebSocketDecoder() {
		}
		
		/*
		+-+-+-+-+-------+-+-------------+-------------------------------+
		|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
		|I|S|S|S|  (4)  |A|     (7)     |             (16/63)           |
		|N|V|V|V|       |S|             |   (if payload len==126/127)   |
		| |1|2|3|       |K|             |                               |
		+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
		|     Extended payload length continued, if payload len == 127  |
		+ - - - - - - - - - - - - - - - +-------------------------------+
		|                               |Masking-key, if MASK set to 1  |
		+-------------------------------+-------------------------------+
		| Masking-key (continued)       |          Payload Data         |
		+-------------------------------- - - - - - - - - - - - - - - - +
		:                     Payload Data continued ...                :
		+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
		|                     Payload Data continued ...                |
		+---------------------------------------------------------------+
		*/
		public function process(e:ProgressEvent, socket:Socket):void {
			
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
			socket.readBytes(data);
			
			if(masked) {
				for(var i:uint = 0; i < data.length;i++) {
					data[i] = (data[i] ^ (mask >>> ((3 - (i % 4)) * 8)));
				}
			}
			
			switch(op) {
				case OP_CONTINUATION:
					buffer.writeBytes(data);
					if(!fragmented) {
						//dispatchEvent(new Event("message", buffer));
					}
					break;
				case OP_TEXT_FRAME:
					if(!fragmented) {
						data.position = 0;
						dispatchEvent(new WebSocketEvent(WebSocketEvent.MESSAGE, data.readUTFBytes(data.length)));
						return;
					}
					buffer.writeBytes(data);
					break;
				case OP_BINARY_FRAME:
					//TODO: Implement Support
					break;
				case OP_CLOSE:
					socket.close();
					break;
				case OP_PING:
					socket.writeByte(OP_PONG | 0x80);
					socket.writeByte(0);
					socket.flush();
					break;
				case OP_PONG:
					break;
				default:
					socket.close();
					break;
			}
			
		}
	}
}