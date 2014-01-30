
module MQTT
  class Packet
    # Class representing an MQTT Client Subscribe packet
    class Subscribe < MQTT::Packet
      attr_accessor :message_id
      attr_reader :topics
      DEFAULTS = {:message_id => 0}

      # Create a new Subscribe packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
        @topics ||= []
        @qos = 1 # Force a QOS of 1
      end

      # Set one or more topics for the Subscrible packet
      # The topics parameter should be one of the following:
      # * String: subscribe to one topic with QOS 0
      # * Array: subscribe to multiple topics with QOS 0
      # * Hash: subscribe to multiple topics where the key is the topic and the value is the QOS level
      #
      # For example:
      #   packet.topics = 'a/b'
      #   packet.topics = ['a/b', 'c/d']
      #   packet.topics = [['a/b',0], ['c/d',1]]
      #   packet.topics = {'a/b' => 0, 'c/d' => 1}
      #
      def topics=(value)
        # Get input into a consistent state
        if value.is_a?(Array)
          input = value.flatten
        else
          input = [value]
        end

        @topics = []
        while(input.length>0)
          item = input.shift
          if item.is_a?(Hash)
            # Convert hash into an ordered array of arrays
            @topics += item.sort
          elsif item.is_a?(String)
            # Peek at the next item in the array, and remove it if it is an integer
            if input.first.is_a?(Integer)
              qos = input.shift
              @topics << [item,qos]
            else
              @topics << [item,0]
            end
          else
            # Meh?
            raise "Invalid topics input: #{value.inspect}"
          end
        end
        @topics
      end

      # Get serialisation of packet's body
      def encode_body
        if @topics.empty?
          raise "no topics given when serialising packet"
        end
        body = encode_short(@message_id)
        topics.each do |item|
          body += encode_string(item[0])
          body += encode_bytes(item[1])
        end
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        @topics = []
        while(buffer.bytesize>0)
          topic_name = shift_string(buffer)
          topic_qos = shift_byte(buffer)
          @topics << [topic_name,topic_qos]
        end
      end

      def inspect
        str = "\#<#{self.class}: 0x%2.2X, %s>" % [
          message_id,
          topics.map {|t| "'#{t[0]}':#{t[1]}"}.join(', ')
        ]
      end
    end
  end
end
