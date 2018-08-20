defmodule FusionDsl.Service.ServiceManager do
  @moduledoc """
  Service Manager Module
  """

  use GenServer

  @type service_info :: %{
          module: atom(),
          name: String.t(),
          params: [{String.t(), String.t()}],
          program: {program_type, String.t() | integer}
        }

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  ## Client

  @doc """
  Adds and runs a new service
  """
  @spec add_service(service_info) :: {:ok, service_id}
  def add_service(service_info) do
    GenServer.call(__MODULE__, {:add_service, service_info})
  end

  def update_service(service_id, new_info) do
    GenServer.call(__MODULE__, {:update_service, service_id, new_info})
  end

  def stop_service(service_id) do
    GenServer.call(__MODULE__, {:stop_service, service_id})
  end

  def list_services do
    GenServer.call(__MODULE__, :list_services)
  end

  ## GenServer API

  @impl true
  def init(services) do
    {:ok, services}
  end

  @impl true
  def handle_call({:add_service, srv_info}, _from, services) do
    module = service_info.module
    mod_params = module.list_parameters()

    with {:ok, params} <- cast_params(srv_info.params, mod_params),
         {:ok, service_id} <- create_service_id(module, srv_info.name),
         :ok <- module.start_service(service_id, %{srv_info | params: params}) do
      :ok
    else
      _ ->
        :error
    end
  end

  @impl true
  def handle_call({:update_service, service_id, new_info}, _from, services) do
  end

  @impl true
  def handle_call({:stop_service, service_id}, _from, services) do
  end

  @impl true
  def handle_call(:list_services, _from, services) do
    {:reply, services, services}
  end

  @doc """
  Converts a program service information to AST
  """
  def fetch_env({:file, path}) do
    FusionDsl.compile_file(path)
  end

  def fetch_env({:raw, code}) do
    FusionDsl.compile(code)
  end

  def fetch_env({:db, id}) do
    # TODO: Implement DB
    raise "Not Implemented"
  end
end
