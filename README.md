# SNTP

SNTP v4 client [RFC4330](https://tools.ietf.org/html/rfc4330) for Elixir

## Examples

```elixir
iex> SNTP.time()
{:ok, %Timestamp{}}

iex> SNTP.offset()
{:ok, offset}

iex> SNTP.now()
1504292984738

iex> SNTP.start()
#PID<0.000.0>

iex> SNTP.stop()
:ok
```

## Documentation

[hex documentation for sntp](https://hexdocs.pm/sntp)

## Installation

```elixir
def deps do
  [{:sntp, "~> 0.2.0"}]
end
```

## Acknowledgement

This client was made thanks to [sntp](https://github.com/hueniverse/sntp) as an implementation in Elixir.

## LICENSE

(The MIT License)

Copyright (c) 2017 Benjamin Schultzer

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS,' WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
