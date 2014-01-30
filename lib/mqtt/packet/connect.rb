
module MQTT
  class Packet
    # Class representing an MQTT Publish message
    class Connect < MQTT::Packet
      attr_accessor :protocol_name
      attr_accessor :protocol_version
      attr_accessor :client_id
      attr_accessor :clean_session
      attr_accessor :keep_alive
      attr_accessor :will_topic
      attr_accessor :will_qos
      attr_accessor :will_retain
      attr_accessor :will_payload
      attr_accessor :username
      attr_accessor :password

      # OLD deprecated clean_start
      alias :clean_start :clean_session
      alias :clean_start= :clean_session=

      DEFAULTS = {
        :protocol_name => 'MQIsdp',
        :protocol_version => 0x03,
        :client_id => nil,
        :clean_session => true,
        :keep_alive => 15,
        :will_topic => nil,
        :will_qos => 0,
        :will_retain => false,
        :will_payload => '',
        :username => nil,
        :password => nil,
      }

      # Create a new Client Connect packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        if @client_id.nil? or @client_id.bytesize < 1 or @client_id.bytesize > 23
          raise "Invalid client identifier when serialising packet"
        end
        body += encode_string(@protocol_name)
        body += encode_bytes(@protocol_version.to_i)

        if @keep_alive < 0
          raise "Invalid keep-alive value: cannot be less than 0"
        end

        # Set the Connect flags
        @connect_flags = 0
        @connect_flags |= 0x02 if @clean_session
        @connect_flags |= 0x04 unless @will_topic.nil?
        @connect_flags |= ((@will_qos & 0x03) << 3)
        @connect_flags |= 0x20 if @will_retain
        @connect_flags |= 0x40 unless @password.nil?
        @connect_flags |= 0x80 unless @username.nil?
        body += encode_bytes(@connect_flags)

        body += encode_short(@keep_alive)
        body += encode_string(@client_id)
        unless will_topic.nil?
          body += encode_string(@will_topic)
          # The MQTT v3.1 specification says that the payload is a UTF-8 string
          body += encode_string(@will_payload)
        end
        body += encode_string(@username) unless @username.nil?
        body += encode_string(@password) unless @password.nil?
        return body
      end

      # Parse the body (variable header and payload) of a Connect packet
      def parse_body(buffer)
        super(buffer)
        @protocol_name = shift_string(buffer)
        @protocol_version = shift_byte(buffer).to_i

        if @protocol_name != 'MQIsdp'
          raise ProtocolException.new(
            "Unsupported protocol name: #{@protocol_name}"
          )
        end

        if @protocol_version != 3
          raise ProtocolException.new(
            "Unsupported protocol version: #{@protocol_version}"
          )
        end

        @connect_flags = shift_byte(buffer)
        @clean_session = ((@connect_flags & 0x02) >> 1) == 0x01
        @keep_alive = shift_short(buffer)
        @client_id = shift_string(buffer)
        if ((@connect_flags & 0x04) >> 2) == 0x01
          # Last Will and Testament
          @will_qos = ((@connect_flags & 0x18) >> 3)
          @will_retain = ((@connect_flags & 0x20) >> 5) == 0x01
          @will_topic = shift_string(buffer)
          # The MQTT v3.1 specification says that the payload is a UTF-8 string
          @will_payload = shift_string(buffer)
        end
        if ((@connect_flags & 0x80) >> 7) == 0x01 and buffer.bytesize > 0
          @username = shift_string(buffer)
        end
        if ((@connect_flags & 0x40) >> 6) == 0x01 and buffer.bytesize > 0
          @password = shift_string(buffer)
        end
      end

      def inspect
        str = "\#<#{self.class}: "
        str += "keep_alive=#{keep_alive}"
        str += ", clean" if clean_session
        str += ", client_id='#{client_id}'"
        str += ", username='#{username}'" unless username.nil?
        str += ", password=..." unless password.nil?
        str += ">"
      end
    end
  end
end
