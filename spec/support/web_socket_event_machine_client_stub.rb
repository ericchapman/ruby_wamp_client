class WebSocketEventMachineClientStub
  attr_accessor :last_message

  def initialize
    EM.add_timer(1) {
      @onopen.call if @onopen != nil
    }
  end

  @onopen
  def onopen(&onopen)
    @onopen = onopen
  end

  @onmessage
  def onmessage(&onmessage)
    @onmessage = onmessage
  end

  @onclose
  def onclose(&onclose)
    @onclose = onclose
  end

  def close
    @onclose.call if @onclose != nil
    true
  end

  def send(message, type)
    self.last_message = message
  end

  def receive(message)
    @onmessage.call(message, {type:'text'}) if @onmessage != nil
  end

end

