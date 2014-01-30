
module MQTT
  class Packet
    # Class representing an MQTT Connect Acknowledgment Packet
    class Connack < MQTT::Packet
      attr_accessor :return_code
      DEFAULTS = {:return_code => 0x00}

      # Create a new Client Connect packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get a string message corresponding to a return code
      def return_msg
        case return_code
          when 0x00
            "Connection Accepted"
          when 0x01
            "Connection refused: unacceptable protocol version"
          when 0x02
            "Connection refused: client identifier rejected"
          when 0x03
            "Connection refused: broker unavailable"
          when 0x04
            "Connection refused: bad user name or password"
          when 0x05
            "Connection refused: not authorised"
          else
            "Connection refused: error code #{return_code}"
        end
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        body += encode_bytes(0) # Unused
        body += encode_bytes(@return_code.to_i) # Return Code
        return body
      end

      # Parse the body (variable header and payload) of a Connect Acknowledgment packet
      def parse_body(buffer)
        super(buffer)
        _unused = shift_byte(buffer)
        @return_code = shift_byte(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Connect Acknowledgment packet")
        end
      end

      def inspect
        "\#<#{self.class}: 0x%2.2X>" % return_code
      end
    end
  end
end
