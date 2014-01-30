
module MQTT
  class Packet
    # Class representing an MQTT Ping Response packet
    class Pingresp < MQTT::Packet
      # Create a new Ping Response packet
      def initialize(args={})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Ping Response packet")
        end
      end
    end
  end
end
