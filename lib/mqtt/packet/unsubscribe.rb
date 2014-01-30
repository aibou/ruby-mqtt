
module MQTT
  class Packet
    # Class representing an MQTT Client Unsubscribe packet
    class Unsubscribe < MQTT::Packet
      attr_reader :topics
      attr_accessor :message_id
      DEFAULTS = {:message_id => 0}

      # Create a new Unsubscribe packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
        @topics ||= []
        @qos = 1 # Force a QOS of 1
      end

      def topics=(value)
        if value.is_a?(Array)
          @topics = value
        else
          @topics = [value]
        end
      end

      # Get serialisation of packet's body
      def encode_body
        if @topics.empty?
          raise "no topics given when serialising packet"
        end
        body = encode_short(@message_id)
        topics.each { |topic| body += encode_string(topic) }
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        while(buffer.bytesize>0)
          @topics << shift_string(buffer)
        end
      end

      def inspect
        str = "\#<#{self.class}: 0x%2.2X, %s>" % [
          message_id,
          topics.map {|t| "'#{t}'"}.join(', ')
        ]
      end
    end
  end
end
