defmodule IvroneDsl.Runtime.Enviornment do
  defstruct vars: %{},
            mod: IvroneDsl.Runtime.Enviornments.TestEnviornment,
            sys_vars: %{},
            agi: nil

  alias IvroneDsl.Processor.Program

  @type prog :: %Program{}
  @type env :: %__MODULE__{}

  @base_sound_path Application.get_env(:ivrone_dsl, :base_sound_path)

  @callback play(prog(), env(), binary(), binary()) :: {:ok, binary(), env()}

  @callback keycheck(
              prog(),
              env(),
              binary(),
              Integer.t(),
              Integer.t(),
              binary(),
              binary(),
              binary()
            ) :: {:ok, binary(), env()}

  @callback log(prog(), env(), binary() | Integer.t() | Number.t()) :: {:ok, nil, env()}

  @doc """
  Prepares enviornments data and returns the data
  """
  # TODO: get call info or test info
  def prepare_env do
    {:ok, %__MODULE__{}}
  end

  @doc """
  Prepares a filename with base_path and
  """
  def prepare_filename(prog, <<"/", file_name::binary>>) do
    Path.join(@base_sound_path, file_name)
  end

  def prepare_filename(prog, file_name) do
    Path.join([@base_sound_path, prog.sound_dir, file_name])
  end
end
