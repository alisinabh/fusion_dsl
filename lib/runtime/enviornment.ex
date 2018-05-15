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
            jump_c: 0

  alias FusionDsl.Processor.Program

  @type prog :: %Program{}
  @type env :: %__MODULE__{}

  @doc """
  Prepares enviornments data and returns the data
  """
  # TODO: get call info or test info
  def prepare_env do
    {:ok, %__MODULE__{}}
  end
end
