defmodule FusionDsl.Runtime.Enviornment do
  @moduledoc """
  Envoirnment struct and behaviours for the programs
  """

  defstruct vars: %{},
            mod: FusionDsl.Runtime.Enviornments.TestEnviornment,
            sys_vars: %{},
            agi: nil,
            last_user_action: DateTime.utc_now(),
            cur_proc: [:main],
            jump_c: 0,
            assigns: %{},
            prog: nil

  alias FusionDsl.Processor.Program

  @type prog :: %Program{}
  @type env :: %__MODULE__{}

  @doc """
  Prepares enviornments data and returns the data
  """
  # TODO: get call info or test info
  def prepare_env(prog) do
    {:ok, %__MODULE__{prog: prog}}
  end
end
