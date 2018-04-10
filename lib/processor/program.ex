defmodule IvroneDsl.Processor.Program do
  @moduledoc """
  Program struct and functions
  """

  defstruct [:name, :version, :db, :sound_dir, procedures: []]
end
