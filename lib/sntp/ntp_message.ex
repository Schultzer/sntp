defmodule SNTP.NTPMessage do
  @moduledoc false

  defstruct [:data, :sent_at, :received_at, :ip]

  @type t :: %__MODULE__{}
end
