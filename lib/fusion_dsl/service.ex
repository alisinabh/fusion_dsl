defmodule FusionDsl.Service do
  @moduledoc """
  Service behaviour for Fusion services.

  Using this behaviour, the developer:

   - Defines parameters of the service. (e.g port, url, etc)
   - Implements the function to start a new service.
   - Implements the function to update a previuosly started service.
   - Implements the function needed to stop a service.
  """

  @type service_config :: [{atom(), String.t()}]

  @doc """
  Should return list of parameters of service.

  ## Examples
  ```elixir
  [
    port: "Port number for http service", 
    domains: "domains for service. separeted by comma"
  ]
  ```
  """
  @callback list_parameters() :: service_config()

  @doc """
  Should start a new service.

  ## Parameters
   - first: Unique service name as atom.
   - second: Keyword list of parameters.
  """
  @callback start_service(atom(), service_config()) ::
              :ok | {:error, atom()} | {:error, atom(), String.t()}

  @doc """
  Should update the service configuration.

  ## Parameters
   - first: Unique name of service.
   - second: New configuration (only changes)
  """
  @callback update_service(atom(), service_config) ::
              :ok | {:error, atom()} | {:error, atom(), String.t()}

  @doc """
  Should stop a given service.

  ## Parameters
   - first: Unique name of service.
  """
  @callback stop_service(atom()) ::
              :ok | {:error, atom()} | {:error, atom(), String.t()}
end
