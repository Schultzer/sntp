# SNTP

SNTP client [RFC4330](https://tools.ietf.org/html/rfc4330) for Elixir

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sntp` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:sntp, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/sntp](https://hexdocs.pm/sntp).

## Methods

### `time/1`
```elixir
SNTP.time() = {:ok, timestamp} || {:error, reason}
```

### `time!/1`
```elixir
SNTP.time() = timestamp || reason
```

### `offset()`
```elixir
SNTP.offset() = %{expires: 1504379384471, offset: 12}`
```

### `now()`
```elixir
SNTP.now() = 1504292984738
```

## Acknowledgement

This client was made thanks to [sntp](https://github.com/hueniverse/sntp) as an implementation in Elixir.

## LICENSE

(The MIT License)

Copyright (c) 2017 Benjamin Schultzer

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
