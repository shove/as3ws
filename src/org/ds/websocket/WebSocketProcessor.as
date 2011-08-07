package org.ds.websocket
{
	import flash.events.ProgressEvent;
	import flash.net.Socket;
	
	public interface WebSocketProcessor
	{
		function process(e:ProgressEvent, socket:Socket):void;
	}
}