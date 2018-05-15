defmodule FusionDsl.Processor.Program do
  @moduledoc """
  Program struct
  """

  defstruct [:name, :version, config: [], fusion_version: nil, procedures: %{}]
end
