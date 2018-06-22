defmodule FusionDsl.Processor.Program do
  @moduledoc """
  Program struct
  """

  @typedoc """
  Structure of a compiled program. contains procedure, configs, name, software
  and runtime version.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          config: [Keyword.t()],
          fusion_version: Integer.t(),
          procedures: %{String.t() => List.t()}
        }

  defstruct [:name, :version, config: [], fusion_version: nil, procedures: %{}]
end
