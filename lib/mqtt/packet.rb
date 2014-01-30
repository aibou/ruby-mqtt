# encoding: BINARY
require 'mqtt/packet/connect'
require 'mqtt/packet/connack'
require 'mqtt/packet/publish'
require 'mqtt/packet/puback'
require 'mqtt/packet/pubrec'
require 'mqtt/packet/pubrel'
require 'mqtt/packet/pubcomp'
require 'mqtt/packet/subscribe'
require 'mqtt/packet/suback'
require 'mqtt/packet/unsubscribe'
require 'mqtt/packet/unsuback'
require 'mqtt/packet/pingreq'
require 'mqtt/packet/pingresp'
require 'mqtt/packet/disconnect'

module MQTT

  # Class representing a MQTT Packet
  # Performs binary encoding and decoding of headers
  class MQTT::Packet
    attr_reader :duplicate   # Duplicate delivery flag
    attr_reader :retain      # Retain flag
    attr_reader :qos         # Quality of Service level
    attr_reader :body_length # The length of the parsed packet body

    DEFAULTS = {
      :duplicate => false,
      :qos => 0,
      :retain => false,
      :body_length => nil
    }

    # Read in a packet from a socket
    def self.read(socket)
      # Read in the packet header and create a new packet object
      packet = create_from_header(
        read_byte(socket)
      )

      # Read in the packet length
      multiplier = 1
      body_length = 0
      pos = 1
      begin
        digit = read_byte(socket)
        body_length += ((digit & 0x7F) * multiplier)
        multiplier *= 0x80
        pos += 1
      end while ((digit & 0x80) != 0x00) and pos <= 4

      # Store the expected body length in the packet
      packet.instance_variable_set('@body_length', body_length)

      # Read in the packet body
      packet.parse_body( socket.read(body_length) )

      return packet
    end

    # Parse buffer into new packet object
    def self.parse(buffer)
      packet = parse_header(buffer)
      packet.parse_body(buffer)
      return packet
    end

    # Parse the header and create a new packet object of the correct type
    # The header is removed from the buffer passed into this function
    def self.parse_header(buffer)
      # Check that the packet is a long as the minimum packet size
      if buffer.bytesize < 2
        raise ProtocolException.new("Invalid packet: less than 2 bytes long")
      end

      # Create a new packet object
      bytes = buffer.unpack("C5")
      packet = create_from_header(bytes.first)

      # Parse the packet length
      body_length = 0
      multiplier = 1
      pos = 1
      begin
        if buffer.bytesize <= pos
          raise ProtocolException.new("The packet length header is incomplete")
        end
        digit = bytes[pos]
        body_length += ((digit & 0x7F) * multiplier)
        multiplier *= 0x80
        pos += 1
      end while ((digit & 0x80) != 0x00) and pos <= 4

      # Store the expected body length in the packet
      packet.instance_variable_set('@body_length', body_length)

      # Delete the fixed header from the raw packet passed in
      buffer.slice!(0...pos)

      return packet
    end

    # Create a new packet object from the first byte of a MQTT packet
    def self.create_from_header(byte)
      # Work out the class
      type_id = ((byte & 0xF0) >> 4)
      packet_class = MQTT::PACKET_TYPES[type_id]
      if packet_class.nil?
        raise ProtocolException.new("Invalid packet type identifier: #{type_id}")
      end

      # Create a new packet object
      packet_class.new(
        :duplicate => ((byte & 0x08) >> 3) == 0x01,
        :qos => ((byte & 0x06) >> 1),
        :retain => ((byte & 0x01) >> 0) == 0x01
      )
    end

    # Create a new empty packet
    def initialize(args={})
      update_attributes(DEFAULTS.merge(args))
    end

    def update_attributes(attr={})
      attr.each_pair do |k,v|
        send("#{k}=", v)
      end
    end

    # Get the identifer for this packet type
    def type_id
      index = MQTT::PACKET_TYPES.index(self.class)
      if index.nil?
        raise "Invalid packet type: #{self.class}"
      end
      return index
    end

    # Set the dup flag (true/false)
    def duplicate=(arg)
      if arg.kind_of?(Integer)
        @duplicate = (arg != 0)
      else
        @duplicate = arg
      end
    end

    # Set the retain flag (true/false)
    def retain=(arg)
      if arg.kind_of?(Integer)
        @retain = (arg != 0)
      else
        @retain = arg
      end
    end

    # Set the Quality of Service level (0/1/2)
    def qos=(arg)
      @qos = arg.to_i
      if @qos < 0 or @qos > 2
        raise "Invalid QoS value: #{@qos}"
      end
    end

    # Set the length of the packet body
    def body_length=(arg)
      @body_length = arg.to_i
    end

    # Parse the body (variable header and payload) of a packet
    def parse_body(buffer)
      if buffer.bytesize != body_length
        raise ProtocolException.new(
          "Failed to parse packet - input buffer (#{buffer.bytesize}) is not the same as the body length header (#{body_length})"
        )
      end
    end

    # Get serialisation of packet's body (variable header and payload)
    def encode_body
      '' # No body by default
    end


    # Serialise the packet
    def to_s
      # Encode the fixed header
      header = [
        ((type_id.to_i & 0x0F) << 4) |
        ((duplicate ? 0x1 : 0x0) << 3) |
        ((qos.to_i & 0x03) << 1) |
        (retain ? 0x1 : 0x0)
      ]

      # Get the packet's variable header and payload
      body = self.encode_body

      # Check that that packet isn't too big
      body_length = body.bytesize
      if body_length > 268435455
        raise "Error serialising packet: body is more than 256MB"
      end

      # Build up the body length field bytes
      begin
        digit = (body_length % 128)
        body_length = (body_length / 128)
        # if there are more digits to encode, set the top bit of this digit
        digit |= 0x80 if (body_length > 0)
        header.push(digit)
      end while (body_length > 0)

      # Convert header to binary and add on body
      header.pack('C*') + body
    end

    def inspect
      "\#<#{self.class}>"
    end

    protected

    # Encode an array of bytes and return them
    def encode_bytes(*bytes)
      bytes.pack('C*')
    end

    # Encode a 16-bit unsigned integer and return it
    def encode_short(val)
      [val.to_i].pack('n')
    end

    # Encode a UTF-8 string and return it
    # (preceded by the length of the string)
    def encode_string(str)
      str = str.to_s.encode('UTF-8')

      # Force to binary, when assembling the packet
      str.force_encoding('ASCII-8BIT')
      encode_short(str.bytesize) + str
    end

    # Remove a 16-bit unsigned integer from the front of buffer
    def shift_short(buffer)
      bytes = buffer.slice!(0..1)
      bytes.unpack('n').first
    end

    # Remove one byte from the front of the string
    def shift_byte(buffer)
      buffer.slice!(0...1).unpack('C').first
    end

    # Remove n bytes from the front of buffer
    def shift_data(buffer,bytes)
      buffer.slice!(0...bytes)
    end

    # Remove string from the front of buffer
    def shift_string(buffer)
      len = shift_short(buffer)
      str = shift_data(buffer,len)
      # Strings in MQTT v3.1 are all UTF-8
      str.force_encoding('UTF-8')
    end


    private

    # Read and unpack a single byte from a socket
    def self.read_byte(socket)
      byte = socket.read(1)
      if byte.nil?
        raise ProtocolException.new("Failed to read byte from socket")
      end
      byte.unpack('C').first
    end
  end

  # An enumeration of the MQTT packet types
  PACKET_TYPES = [
    nil,
    MQTT::Packet::Connect,
    MQTT::Packet::Connack,
    MQTT::Packet::Publish,
    MQTT::Packet::Puback,
    MQTT::Packet::Pubrec,
    MQTT::Packet::Pubrel,
    MQTT::Packet::Pubcomp,
    MQTT::Packet::Subscribe,
    MQTT::Packet::Suback,
    MQTT::Packet::Unsubscribe,
    MQTT::Packet::Unsuback,
    MQTT::Packet::Pingreq,
    MQTT::Packet::Pingresp,
    MQTT::Packet::Disconnect,
    nil
  ]

end
