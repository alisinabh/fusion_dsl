# This file implements native elixir packages.
# Native elixir packages can be set in :packages config of
# :fusion_dsl. They have `type: :native` in their package
# opts. Please refer to docs for more info.

defmodule FusionDsl.NativeImpl do
  def create_native_packages(packages) do
    Enum.reduce(packages, [], fn package, acc ->
      {module, opts} = package

      case opts[:type] do
        :native ->
          pack_mod = String.to_atom("Elixir.FusionDsl.Dyn.#{module}")

          if not function_exported?(pack_mod, :__info__, 1) do
            IO.puts("module #{pack_mod} not found")
            create_fusion_module(module, pack_mod, opts)
          else
            IO.puts("#{pack_mod} found")
          end

          [{pack_mod, opts} | acc]

        _ ->
          [package | acc]
      end
    end)
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

    get_function_doc = fn module, function ->
      docs = Code.get_docs(module, :docs)

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

    # Quote implementation of each function
    impl_functions =
      Enum.reduce(module_functions, [], fn fn_name, acc ->
        data =
          quote do
            @doc "#{unquote(get_function_doc.(module, fn_name))}"
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
        def list_functions, do: unquote(module_functions)

        unquote(impl_functions)
      end

    IO.puts("Creating module #{pack_mod}")

    try do
      Module.create(pack_mod, impl_contents, Macro.Env.location(__ENV__))
    rescue
      CompileError -> :ok
    end

    # Test module
    if :erlang.apply(pack_mod, :list_functions, []) != module_functions do
      raise "Module #{pack_mod} is not returning list_function as expected!"
    end
  end
end
