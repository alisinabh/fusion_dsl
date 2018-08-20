defmodule FusionDsl.Service.Registry do
  @moduledoc """
  Registry of fusion dsl services.
  """

  use GenServer

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  ## Client

  @doc """
  Adds and runs a new service
  """
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
  def handle_call({:add_service, module}, _from, services) do
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
end
