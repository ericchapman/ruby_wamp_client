class FayeWebSocketClientStub
  class Event
    attr_accessor :data, :reason
  end

  attr_accessor :last_message

  def initialize
    EM.add_timer(1) {
      @on_open.call(Event.new) if @on_open != nil
    }
  end

  @on_open
  @on_message
  @on_close
  def on(event, &block)
    if event == :open
      @on_open = block
    elsif event == :close
      @on_close = block
    elsif event == :message
      @on_message = block
    end
  end

  def close
    event = Event.new
    event.reason = 'closed'
    @on_close.call(event) if @on_close != nil
  end

  def send(message)
    self.last_message = message
  end

  def receive(message)
    event = Event.new
    event.data = message
    @on_message.call(event) if @on_message != nil
  end

end
