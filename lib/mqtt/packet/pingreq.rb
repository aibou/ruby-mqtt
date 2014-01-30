
module MQTT
  class Packet
    # Class representing an MQTT Ping Request packet
    class Pingreq < MQTT::Packet
      # Create a new Ping Request packet
      def initialize(args={})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Ping Request packet")
        end
      end
    end
  end
end
