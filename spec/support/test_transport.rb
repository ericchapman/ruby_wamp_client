class TestTransport < Wamp::Client::Transport::EventMachineBase
  @@event_machine_on = false
  attr_accessor :messages

  def initialize(options)
    super(options)
    @connected = true
    self.messages = []
  end

  def connect
    self.add_timer(1000) do
      trigger :open
    end
  end

  def disconnect
    @connected = false
    trigger :close
  end

  def self.start_event_machine(&block)
    @@event_machine_on = true
    block.call
  end

  def self.stop_event_machine
    @@event_machine_on = false
  end

  def self.event_machine_on?
    @@event_machine_on
  end

  def send_message(msg)
    self.messages.push(msg)
  end

  def receive_message(msg)

    # Emulate serialization/deserialization
    serialize = self.serializer.serialize(msg)
    deserialize = self.serializer.deserialize(serialize)

    # Call the received message
    trigger :message, deserialize
  end

end

