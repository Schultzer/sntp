defmodule SNTP.RetrieverError do
  @moduledoc """
  Exception raised when the retriever is not started.
  """

  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end
