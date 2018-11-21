=begin

Copyright (c) 2018 Eric Chapman

MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=end

module Wamp
  module Client
    module Defer

      class CallDefer
        attr_accessor :request, :registration

        @on_complete
        def on_complete(&on_complete)
          @on_complete = on_complete
        end

        @on_error
        def on_error(&on_error)
          @on_error = on_error
        end

        def succeed(result)
          @on_complete.call(self, result) if @on_complete
        end

        def fail(error)
          @on_error.call(self, error) if @on_error
        end

      end

      class ProgressiveCallDefer < CallDefer

        @on_progress
        def on_progress(&on_progress)
          @on_progress = on_progress
        end

        def progress(result)
          @on_progress.call(self, result) if @on_progress
        end

      end

    end
  end
end