# This file implements native elixir packages.
# Native elixir packages can be set in :packages config of
# :fusion_dsl. They have `type: :native` in their package
# opts. Please refer to docs for more info.

Enum.each(Application.get_env(:fusion_dsl, :packages, []), fn package ->
  {pack_mod, opts} = package

  case opts[:type] do
    :native ->
      module = opts[:module]

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

                {:ok, :erlang.apply(unquote(module), unquote(fn_name), args),
                 env}
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

      # Define module
      Module.create(pack_mod, impl_contents, Macro.Env.location(__ENV__))

      # Test module
      if :erlang.apply(pack_mod, :list_functions, []) != module_functions do
        raise "Module #{pack_mod} is not returning list_function as expected!"
      end

    _ ->
      :ok
  end
end)
