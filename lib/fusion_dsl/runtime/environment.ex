defmodule FusionDsl.Runtime.Environment do
  @moduledoc """
  Envoirnment struct and behaviours for the programs
  """

  defstruct vars: %{},
            sys_vars: %{},
            cur_proc: [:main],
            jump_c: 0,
            assigns: %{},
            prog: nil

  alias FusionDsl.Processor.Program

  @typedoc """
  The enviornment structure of executing scripts which contains:

   - vars: Variables and their values.
   - sys_vars: Systematic variables and their values.
   - cur_proc: Stack of procedures.
   - assigns: Assigns which packages manipulated.
   - prog: Compiled program structure
   - jump_c: A safety integer counting number of jumps in code (Zombie detector)
  """
  @type t :: %__MODULE__{
          vars: %{String.t() => any()},
          sys_vars: %{String.t() => any()},
          cur_proc: [atom()],
          assigns: map(),
          prog: Program.t(),
          jump_c: integer()
        }

  @doc """
  Prepares enviornments data and returns the data
  """
  # TODO: get call info or test info
  def prepare_env(prog) do
    {:ok, %__MODULE__{prog: prog}}
  end
end
