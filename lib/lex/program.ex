defmodule IvroneDsl.Lex.Program do
  @moduledoc """
  Program struct and functions
  """

  defstruct [:name, :version, :db, :sound_dir, :code, procedures: []]
end
