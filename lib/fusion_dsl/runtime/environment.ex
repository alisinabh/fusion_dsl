defmodule FusionDsl.Runtime.Environment do
  @moduledoc """
  Envoirnment struct and behaviours for the programs
  """

  defstruct vars: %{},
            sys_vars: %{},
            cur_proc: [],
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
  def prepare_env(compile_config, env \\ %__MODULE__{}) do
    prog = Map.put(compile_config.prog, :headers, compile_config.headers)
    {:ok, %{env | prog: prog}}
  end

  def get_info(env, :small) do
    "#{Map.get(env.prog.headers, :name, "NO-NAME")} v:#{
      Map.get(env.prog.headers, :version, "NO-VERSION")
    }"
  end

  def get_info(env, :full) do
    "#{get_info(env, :small)}\n" <>
      "ELixir version: #{System.version()}\n" <>
      "OPT version: #{:erlang.system_info(:opt_release)}\n" <>
      "ERTS: #{:erlang.system_info(:version)}\n" <>
      "TotalUsedMemory: #{:erlang.memory(:total)}"
  end
end
