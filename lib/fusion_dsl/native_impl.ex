defmodule FusionDsl.NativeImpl do
  @moduledoc """
  This module helps with building proxy Fusion modules to native erlang/elixir
  modules.

  A native package has `type: :native` in its opts.

  Example:
  ```
  config :fusion_dsl, packages: [{String, [type: :native]}, ...]
  ```

  Refer to [packages](packages.html#existing-elixir-erlang-modules-as-packages)
  docs for more info.
  """

  require Logger

  @doc """
  Creates proxy modules for native packages.

  Returns a new list of all packages and manipulates the native
  package list with new module names.
  """
  @spec create_native_packages(List.t()) :: List.t()
  def create_native_packages(packages) do
    Enum.reduce(packages, [], fn package, acc ->
      {module, opts} = package

      case opts[:type] do
        :native ->
          pack_mod = String.to_atom("Elixir.FusionDsl.Dyn.#{module}")

          create_module_not_exists(module, pack_mod, opts)

          [{pack_mod, opts} | acc]

        _ ->
          [package | acc]
      end
    end)
  end

  # Creates module if module does not exist
  defp create_module_not_exists(module, pack_mod, opts) do
    if not function_exported?(pack_mod, :__info__, 1) do
      create_fusion_module(module, pack_mod, opts)
    end
  end

  defp create_fusion_module(module, pack_mod, opts) do
    # Get functions names of module
    module_functions =
      case opts[:functions] do
        nil ->
          # All functions of a module
          module
          |> :erlang.apply(:__info__, [:functions])
          |> Enum.reduce([], fn {name, _}, acc -> [name | acc] end)
          |> Enum.uniq()

        list when is_list(list) ->
          # Specific user set functions
          list
      end

    # Quote implementation of each function
    impl_functions =
      Enum.reduce(module_functions, [], fn fn_name, acc ->
        data =
          quote do
            @doc "#{unquote(get_function_doc(module, fn_name))}"
            def unquote(fn_name)({unquote(fn_name), _ctx, args}, env) do
              {:ok, args, env} = prep_arg(env, args)

              {:ok, :erlang.apply(unquote(module), unquote(fn_name), args), env}
            end
          end

        [data | acc]
      end)

    # Quote implementation of module
    impl_contents =
      quote do
        use FusionDsl.Impl

        @impl true
        def __list_fusion_functions__, do: unquote(module_functions)

        unquote(impl_functions)
      end

    try do
      Module.create(pack_mod, impl_contents, Macro.Env.location(__ENV__))
    rescue
      CompileError ->
        # As get_packages in FusionDsl module will get called async,
        # Sometimes this method would be called twice.
        # To fix this problem we will ignore module exists exception
        # and rely on the Tests below for the module.
        :ok
    end

    # Test module and raise if its not returning function list as expected.
    if :erlang.apply(pack_mod, :__list_fusion_functions__, []) !=
         module_functions do
      raise "Module #{pack_mod} is not returning __list_fusion_function__ as expected!"
    end
  end

  # Returns documentation of native functions with argument lists
  defp get_function_doc(module, function) do
    version =
      System.version()
      |> String.split(".", parts: 3)

    case version do
      ["1", x, _] ->
        {x, _} = Integer.parse(x)

        if x >= 7 do
          do_get_func_doc_post_17(module, function)
        else
          do_get_func_doc_pre_17(module, function)
        end

      _ ->
        do_get_func_doc_post_17(module, function)
    end
  end

  defp do_get_func_doc_pre_17(module, function) do
    docs =
      case Code.get_docs(module, :docs) do
        arr when is_list(arr) ->
          arr

        other ->
          Logger.error(
            "Bad get_docs for #{inspect(module)} -> #{inspect(other)}"
          )

          []
      end

    doc =
      Enum.find(docs, fn {{name, _}, _, kind, _, _} ->
        name == function and kind == :def
      end)

    case doc do
      {{^function, _}, _, _, args, doc} when is_binary(doc) ->
        arg_docs =
          Enum.reduce(args, "## Arguments\n", fn {name, _, _}, acc ->
            acc <> "\n  - #{name}"
          end)

        doc <> "\n" <> arg_docs

      _ ->
        "No native documentation available!"
    end
  end

  defp do_get_func_doc_post_17(module, function) do
    docs =
      case Code.fetch_docs(module) do
        {:docs_v1, _anno, _lang, _format, _module_doc, _meta, docs} ->
          docs

        error ->
          Logger.error(
            "Error reading docs for module #{inspect(module)} -> #{
              inspect(error)
            }"
          )

          []
      end

    doc =
      Enum.find(docs, fn {{kind, name, _}, _, _, _, _} ->
        name == function and kind == :function
      end)

    case doc do
      {{_, ^function, _}, _, _, doc, _} when is_binary(doc) ->
        # TODO: Fix arg docs in elixir >= 1.7
        doc

      _ ->
        "No native documentation available!"
    end
  end
end
