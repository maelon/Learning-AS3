package model.mp3
{
    import flash.events.EventDispatcher;
    import flash.events.ProgressEvent;
    import flash.net.URLRequest;
    import flash.net.URLStream;
    import flash.utils.ByteArray;

    //Special for MPEG1 Layer3
    public class SoundMp3Calc extends EventDispatcher
    {
        private const BitRateEnum:Vector.<int> = new <int>[-1 , 32 , 40 , 48 , 56 , 64 , 80 , 96 , 112 , 128 , 160 , 192 , 224 , 256 , 320 , -1];

        private var _urlStream_:URLStream;
        private var _bytesTotal_:Number;
        private var _D3V2Size_:uint;
        private var _bitRate_:Number;
        private var _isOK_:Boolean;
        private var _isClose_:Boolean;
        private var _isD3V2Ready_:Boolean;
        private var _isD3V2OK_:Boolean;

        public function SoundMp3Calc()
        {
            
        }
		
		public function CalcTotalTime($urlrequest:URLRequest):void
		{
			if($urlrequest)
			{
				trace("load mp3", $urlrequest.url);
				_urlStream_ = new URLStream();
				_urlStream_.addEventListener(ProgressEvent.PROGRESS , urlStreamProgressHandler);
				_urlStream_.load($urlrequest);
			}
		}

        public function urlStreamProgressHandler($event:ProgressEvent):void
        {
			trace(" progress");
            if(_isOK_)
            {
				if(_urlStream_.connected)
					_urlStream_.close();
                _urlStream_.removeEventListener(ProgressEvent.PROGRESS , urlStreamProgressHandler);
                return ;
            }

            _bytesTotal_ = $event.bytesTotal;
            if(_isD3V2OK_)
            {
                if(_isClose_)
                {
                    if(calcBitRate())
                    {
                        sendNotification(SoundEvent.CALC_SOUND_LENGTH);
                        _isOK_ = true;
                    }
                }
                else
                {
                    if(calcFirstFrame())
                    {
                        _isClose_ = true;
                        if(calcBitRate())
                        {
                            sendNotification(SoundEvent.CALC_SOUND_LENGTH);
                            _isOK_ = true;
                        }
                    }
                }
            }
            else
            {
                if(calcD3V2())
                {
                    _isD3V2OK_ = true;

                    if(calcFirstFrame())
                    {
                        _isClose_ = true;
                        if(calcBitRate())
                        {
                            sendNotification(SoundEvent.CALC_SOUND_LENGTH);
                            _isOK_ = true;
                        }
                    }
                }
            }
        }

        private function calcD3V2():Boolean
        {
            if(_isD3V2Ready_)
            {
                if(_urlStream_.bytesAvailable >= _D3V2Size_)
                    _urlStream_.readBytes(new ByteArray() , 0 , _D3V2Size_);
                return true;
            }
            else
            {
                if(_urlStream_.bytesAvailable > 10)
                {
                    _urlStream_.readUTFBytes(3); //D3V2 header "ID3"
                    _urlStream_.readUTFBytes(1); //D3V2 version
                    _urlStream_.readUTFBytes(1); //D3V2 reversion
                    _urlStream_.readUTFBytes(1); //D3V2 flag
                    _D3V2Size_ = (_urlStream_.readUnsignedByte() & 0x7F) * 0x200000 + 
                        (_urlStream_.readUnsignedByte() & 0x7F) * 0x4000 + 
                        (_urlStream_.readUnsignedByte() & 0x7F) * 0x80 + 
                        (_urlStream_.readUnsignedByte() & 0x7F);
                    _isD3V2Ready_ = true;
                    if(_urlStream_.bytesAvailable >= _D3V2Size_)
                    {
                        _urlStream_.readBytes(new ByteArray() , 0 , _D3V2Size_);
                        return true;
                    }
                }
            }
            return false;
        }

        private function calcFirstFrame():Boolean
        {
            if(_urlStream_.bytesAvailable)
            {
                if(_urlStream_.readUnsignedByte() == 255)
                    return true;
                else
                    return false;
            }
            else
                return false;
        }

        private function calcBitRate():Boolean
        {
            if(_urlStream_.bytesAvailable)
            {
                if((_urlStream_.readUnsignedByte() >> 1) == 125)
                {
                    var mRateIndex:int = (_urlStream_.readUnsignedByte() >> 4);
                    if(mRateIndex > 0 && mRateIndex < BitRateEnum.length)
                        _bitRate_ = BitRateEnum[mRateIndex];
                    else
                        _bitRate_ = -1;
                    return true;
                }
                else
                    return false;
            }
            else
                return false;
        }
		
		private function closeURLStream():void
		{
			if(_urlStream_.connected)
				_urlStream_.close();
			_urlStream_.removeEventListener(ProgressEvent.PROGRESS , urlStreamProgressHandler);
		}

        private function sendNotification($type:String):void
        {
            var mEvent:SoundEvent;
            switch($type)
            {
                case SoundEvent.CALC_SOUND_LENGTH:
					trace("calc time =>", _bytesTotal_ * 0.008 / _bitRate_);
					closeURLStream();
                    mEvent = new SoundEvent(SoundEvent.CALC_SOUND_LENGTH);
                    mEvent.Data = _bytesTotal_ * 0.008 / _bitRate_;
                    break;
            }
            this.dispatchEvent(mEvent);
        }
    }
}
