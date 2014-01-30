
module MQTT
  class Packet
    # Class representing an MQTT Publish Complete packet
    class Pubcomp < MQTT::Packet
      attr_accessor :message_id
      DEFAULTS = {:message_id => 0}

      # Create a new Publish Complete packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Publish Complete packet")
        end
      end

      def inspect
        "\#<#{self.class}: 0x%2.2X>" % message_id
      end
    end
  end
end
