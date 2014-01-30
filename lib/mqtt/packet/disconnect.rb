module MQTT
  class Packet
    # Class representing an MQTT Client Disconnect packet
    class Disconnect < MQTT::Packet
      # Create a new Client Disconnect packet
      def initialize(args={})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Disconnect packet")
        end
      end
    end
  end
end
