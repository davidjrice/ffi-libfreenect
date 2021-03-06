
require 'ffi/freenect'
require 'freenect/context'

module Freenect
  RawTiltState = FFI::Freenect::RawTiltState

  class DeviceError < StandardError
  end

  class Device
    # Returns a device object tracked by its ruby object reference ID stored
    # in user data.
    #
    # This method is intended for internal use.
    def self.by_reference(devp)
      unless devp.null? or (refp=FFI::Freenect.freenect_get_user(devp)).null?
        obj=ObjectSpace._id2ref(refp.read_long_long)
        return obj if obj.is_a?(Device)
      end
    end

    def initialize(ctx, idx)
      dev_p = ::FFI::MemoryPointer.new(:pointer)
      @ctx = ctx

      if ::FFI::Freenect.freenect_open_device(@ctx.context, dev_p, idx) != 0
        raise DeviceError, "unable to open device #{idx} from #{ctx.inspect}"
      end

      @dev = dev_p.read_pointer
      save_object_id!()
    end

    def closed?
      @ctx.closed? or (@dev_closed == true)
    end

    def close
      unless closed?
        if ::FFI::Freenect.freenect_close_device(@dev) == 0
          @dev_closed = true
        end
      end
    end

    def device
      if closed?
        raise DeviceError, "this device is closed and can no longer be used"
      else
        return @dev
      end
    end

    def context
      @ctx
    end

    def get_tilt_state
      unless (p=::FFI::Freenect.freenect_get_tilt_state(self.device)).null?
        return RawTiltState.new(p)
      else
        raise DeviceError, "freenect_get_tilt_state() returned a NULL tilt_state"
      end
    end

    alias tilt_state get_tilt_state

    # Returns the current tilt angle
    def get_tilt_degrees
      ::FFI::Freenect.freenect_get_tilt_degs(self.device)
    end

    alias tilt get_tilt_degrees

    # Sets the tilt angle.
    # Maximum tilt angle range is between +30 and -30
    def set_tilt_degrees(angle)
      ::FFI::Freenect.freenect_set_tilt_degs(self.device, angle)
      return(update_tilt_state() < 0) # based on libfreenect error cond. as of 12-21-10
    end

    alias tilt= set_tilt_degrees

    # Defines a handler for depth events.
    #
    # @yield [device, depth_buf, timestamp]
    # @yieldparam device     A pointer to the device that generated the event.
    # @yieldparam depth_buf  A pointer to the buffer containing the depth data.
    # @yieldparam timestamp  A timestamp for the event?
    def set_depth_callback(&block)
      @depth_callback = block
      ::FFI::Freenect.freenect_set_depth_callback(self.device, @depth_callback)
    end

    alias on_depth set_depth_callback

    # Defines a handler for video events.
    #
    # @yield [device, video_buf, timestamp]
    # @yieldparam device     A pointer to the device that generated the event.
    # @yieldparam video_buf  A pointer to the buffer containing the video data.
    # @yieldparam timestamp  A timestamp for the event?
    def set_video_callback(&block)
      @video_callback = block
      ::FFI::Freenect.freenect_set_video_callback(self.device, @video_callback)
    end

    alias on_video set_video_callback

    def start_depth
      unless(::FFI::Freenect.freenect_start_depth(self.device) == 0)
        raise DeviceError, "Error in freenect_start_depth()"
      end
    end

    def stop_depth
      unless(::FFI::Freenect.freenect_stop_depth(self.device) == 0)
        raise DeviceError, "Error in freenect_stop_depth()"
      end
    end

    def start_video
      unless(::FFI::Freenect.freenect_start_video(self.device) == 0)
        raise DeviceError, "Error in freenect_start_video()"
      end
    end

    def stop_video
      unless(::FFI::Freenect.freenect_stop_video(self.device) == 0)
        raise DeviceError, "Error in freenect_stop_video()"
      end
    end

    def set_depth_format(fmt)
      l_fmt = fmt.is_a?(Numeric)? fmt : Freenect::DEPTH_FORMATS[fmt]
      ret = ::FFI::Freenect.freenect_set_depth_mode(self.device, l_fmt)
      if (ret== 0)
        init_depth_buffer(fmt)
        @depth_format = fmt
      else
        raise DeviceError, "Error calling freenect_set_depth_format(self, #{fmt})"
      end
    end

    alias depth_format= set_depth_format

    # returns the symbolic constant for the current depth format
    def depth_format
      (@depth_format.is_a?(Numeric))? Freenect::DEPTH_FORMATS[@depth_format] : @depth_format
    end

    # Sets the video format to one of the following accepted values:
    #
    def set_video_format(fmt)
      l_fmt = fmt.is_a?(Numeric)? fmt : Freenect::VIDEO_FORMATS[fmt]
      ret = ::FFI::Freenect.freenect_set_video_mode(self.device, l_fmt)
      if (ret== 0)
        init_video_buffer(fmt)
        @video_format = fmt
      else
        raise DeviceError, "Error calling freenect_set_video_format(self, #{fmt})"
      end
    end

    alias video_format= set_video_format

    def video_format
      (@video_format.is_a?(Numeric))? ::Freenect::VIDEO_FORMATS[@video_format] : @video_format
    end

    # Sets the led to one of the following accepted values:
    #   :off,               Freenect::LED_OFF
    #   :green,             Freenect::LED_GREEN
    #   :red,               Freenect::LED_RED
    #   :yellow,            Freenect::LED_YELLOW
    #   :blink_yellow,      Freenect::LED_BLINK_YELLOW
    #   :blink_green,       Freenect::LED_BLINK_GREEN
    #   :blink_red_yellow,  Freenect::LED_BLINK_RED_YELLOW
    #
    # Either the symbol or numeric constant can be specified.
    def set_led(mode)
      return(::FFI::Freenect.freenect_set_led(self.device, mode) == 0)
    end

    alias led= set_led

    def reference_id
      unless (p=::FFI::Freenect.freenect_get_user(device)).null?
        p.read_long_long
      end
    end

    def video_buffer
      if @video_buffer and @video_buf_size
        @video_buffer.read_string_length(@video_buf_size)
      end
    end

    def depth_buffer
      if @depth_buffer and @depth_buf_size
        @depth_buffer.read_string_length(@depth_buf_size)
      end
    end

    private
    def init_depth_buffer(fmt=:depth_11bit)
      if (sz = Freenect.lookup_depth_size(fmt)).nil?
        raise(Freenect::FormatError, "invalid depth format: #{fmt.inspect}")
      end
      @depth_buf_size = sz
      @depth_buffer = FFI::MemoryPointer.new(@depth_buf_size)
      FFI::Freenect.freenect_set_depth_buffer(self.device, @depth_buffer)
    end

    def init_video_buffer(fmt)
      if (sz = Freenect.lookup_video_size(fmt)).nil?
        raise(Freenect::FormatError, "invalid video format: #{fmt.inspect}")
      end
      @video_buf_size = sz
      @video_buffer = FFI::MemoryPointer.new(@video_buf_size)
      FFI::Freenect.freenect_set_video_buffer(self.device, @video_buffer)
    end

    def save_object_id!
      @objid_p = FFI::MemoryPointer.new(:long_long)
      @objid_p.write_long_long(self.object_id)
      ::FFI::Freenect.freenect_set_user(self.device, @objid_p)
    end

    def update_tilt_state
      ::FFI::Freenect.freenect_update_tilt_state(self.device)
    end

  end
end
