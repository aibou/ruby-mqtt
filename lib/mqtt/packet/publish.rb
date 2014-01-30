
module MQTT
  class Packet
    # Class representing an MQTT Publish message
    class Publish < MQTT::Packet
      attr_accessor :topic
      attr_accessor :message_id
      attr_accessor :payload

      DEFAULTS = {
          :topic => nil,
          :message_id => 0,
          :payload => ''
      }

      # Create a new Publish packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        if @topic.nil? or @topic.to_s.empty?
          raise "Invalid topic name when serialising packet"
        end
        body += encode_string(@topic)
        body += encode_short(@message_id) unless qos == 0
        body += payload.to_s.force_encoding('ASCII-8BIT')
        return body
      end

      # Parse the body (variable header and payload) of a Publish packet
      def parse_body(buffer)
        super(buffer)
        @topic = shift_string(buffer)
        @message_id = shift_short(buffer) unless qos == 0
        @payload = buffer
      end

      def inspect
        "\#<#{self.class}: " +
        "d#{duplicate ? '1' : '0'}, " +
        "q#{qos}, " +
        "r#{retain ? '1' : '0'}, " +
        "m#{message_id}, " +
        "'#{topic}', " +
        "#{inspect_payload}>"
      end

      protected
      def inspect_payload
        str = payload.to_s
        if str.bytesize < 16
          "'#{str}'"
        else
          "... (#{str.bytesize} bytes)"
        end
      end
    end
  end
end
