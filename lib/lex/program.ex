defmodule IvroneDsl.Lex.Program do
  @moduledoc """
  Program struct and functions
  """

  defstruct [:name, :version, :db, :sound_dir, procedures: []]
end

defmodule IvroneDsl.Lex.Action do
  @moduledoc """
  Executable actions of IVRONE
  """

  defstruct [:name, args: [], line: 0, output: nil]
end
