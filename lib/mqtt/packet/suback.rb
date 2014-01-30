
module MQTT
  class Packet
    # Class representing an MQTT Subscribe Acknowledgment packet
    class Suback < MQTT::Packet
      attr_accessor :message_id
      attr_reader :granted_qos
      DEFAULTS = {:message_id => 0}

      # Create a new Subscribe Acknowledgment packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
        @granted_qos ||= []
      end

      # Set the granted QOS value for each of the topics that were subscribed to
      # Can either be an integer or an array or integers.
      def granted_qos=(value)
        if value.is_a?(Array)
          @granted_qos = value
        elsif value.is_a?(Integer)
          @granted_qos = [value]
        else
          raise "granted QOS should be an integer or an array of QOS levels"
        end
      end

      # Get serialisation of packet's body
      def encode_body
        if @granted_qos.empty?
          raise "no granted QOS given when serialising packet"
        end
        body = encode_short(@message_id)
        granted_qos.each { |qos| body += encode_bytes(qos) }
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        while(buffer.bytesize>0)
          @granted_qos << shift_byte(buffer)
        end
      end

      def inspect
        "\#<#{self.class}: 0x%2.2X, qos=%s>" % [message_id, granted_qos.join(',')]
      end
    end
  end
end
