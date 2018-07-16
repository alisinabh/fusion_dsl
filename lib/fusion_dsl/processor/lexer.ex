defmodule FusionDsl.Processor.Lexer do
  @moduledoc """
  Tokenizer and normalizer for FusionDsl
  """

  alias FusionDsl.Processor.CompileConfig

  @lang_ids [
    "continue",
    "return",
    "break",
    "while",
    "else",
    "end",
    "if"
  ]
  @lang_ops [
    ",",
    "+=",
    "-=",
    "*=",
    "/=",
    "%=",
    "+",
    "-",
    "*",
    "/",
    "%",
    "==",
    "!=",
    "=",
    ">=",
    "<=",
    ">",
    "<",
    "(",
    ")",
    "[",
    "]",
    "and",
    "or",
    "&&",
    "||"
  ]
  @lang_var ["$", "@", "."]

  @r_header ~r/\A([A-Za-z0-9\-_]+)\:[ ]*(.+)\n/
  @r_lable ~r/\Adef[ \t]+([A-Za-z0-9\-_]+)\:[ \t]*\n/
  @r_number ~r/\A[0-9]+[\.]?[0-9]*/
  @r_string ~r/[^\\](\')/
  @r_var ~r/\A[\_]?[A-Za-z]+[A-Za-z0-9.\_]*/
  @r_goto ~r/\Agoto[ \t]+([A-Za-z0-9\-_]+)/
  @r_fnclosoure ~r/\A[ \t]+\(/
  @r_eol ~r/\n/

  @packages FusionDsl.get_packages()

  defguard is_fn_complete(c) when c in [32, 9, 10, 41]

  @doc """
  Tokenizes a FusionDsl Code

  Lexical types:
   - strings begining with quote ('): immidiate string
   - strings begining with percent sign (%): json object
   - other strings: operators or identifires
   - numbers: Immidiate number. float or integer.
  """
  @spec tokenize(String.t()) :: {:ok, map(), list()} | {:error, String.t()}
  def tokenize(raw_code) do
    raw_code = normalize(raw_code)
    {:ok, config, code} = tokenize_headers(raw_code, CompileConfig.init(), 1)
    {:ok, config, tokens} = do_tokenize(code, [], config)
    {:ok, config, tokens}
  end

  @doc """
  Splits list of tokens to lists of lists by line with line number in beggining of each line
  """
  @spec split_by_lines(list, integer) :: list()
  def split_by_lines(tokens, start_code_line \\ 1) do
    do_split_by_lines(tokens, [start_code_line], [], start_code_line)
  end

  defp do_split_by_lines(["\n" | t], [], acc, ln) do
    do_split_by_lines(t, [ln + 1], acc, ln + 1)
  end

  defp do_split_by_lines(["\n" | t], [_], acc, ln) do
    do_split_by_lines(t, [ln + 1], acc, ln + 1)
  end

  defp do_split_by_lines(["\n" | t], split_acc, acc, ln) do
    split_acc = Enum.reverse(split_acc)
    do_split_by_lines(t, [ln + 1], [split_acc | acc], ln + 1)
  end

  defp do_split_by_lines([token | t], split_acc, acc, ln) do
    do_split_by_lines(t, [token | split_acc], acc, ln)
  end

  defp do_split_by_lines([], [], acc, _ln) do
    Enum.reverse(acc)
  end

  defp do_split_by_lines([], [_], acc, ln) do
    do_split_by_lines([], [], acc, ln)
  end

  defp do_split_by_lines([], split_acc, acc, ln) do
    do_split_by_lines([], [], [split_acc | acc], ln)
  end

  # Normalizes string (Such as line endings)
  defp normalize(code) do
    code = String.replace(code, "\r\n", "\n")

    if String.ends_with?(code, "\n") do
      code
    else
      code <> "\n"
    end
  end

  # Headers finished
  defp tokenize_headers(<<"\n", code::binary>>, config, ln),
    do: {:ok, CompileConfig.set_start_code(config, ln + 1), code}

  # Headers process
  defp tokenize_headers(code, config, ln) do
    case Regex.run(@r_header, code) do
      [full_header, name, value] ->
        code = String.slice(code, String.length(full_header)..-1)

        key =
          name
          |> String.downcase()
          |> String.to_atom()

        tokenize_headers(
          code,
          CompileConfig.process_header(config, key, value),
          ln + 1
        )

      _ ->
        if String.starts_with?(String.trim_leading(code), "#") do
          tokenize_headers(
            Regex.replace(~r/^.*\#.*\n/, code, ""),
            config,
            ln + 1
          )
        else
          {:error, :unknown_header, code}
        end
    end
  end

  # Tokenize finished!
  defp do_tokenize(<<>>, acc, config) do
    {:ok, config, Enum.reverse(acc)}
  end

  # Handle Lang identifires
  Enum.each(@lang_ids, fn id ->
    defp do_tokenize(<<unquote(id), "(", rest::binary>>, acc, config) do
      cond do
        Regex.match?(@r_fnclosoure, rest) ->
          do_tokenize(rest, [unquote(id) | acc], config)

        true ->
          do_tokenize(rest, [unquote(id), "(" | acc], config)
      end
    end

    defp do_tokenize(<<unquote(id), c::utf8, rest::binary>>, acc, config)
         when is_fn_complete(c) do
      rest = <<c>> <> rest

      cond do
        Regex.match?(@r_fnclosoure, rest) ->
          do_tokenize(rest, [unquote(id) | acc], config)

        true ->
          do_tokenize(inject_ending(rest), [unquote(id), "(" | acc], config)
      end
    end
  end)

  Enum.each(@packages, fn {module, opts} ->
    pack_ids = apply(module, :__list_fusion_functions__, [])

    pack_name =
      case opts[:as] do
        nil ->
          module
          |> to_string
          |> String.split(".")
          |> List.last()

        name ->
          name
      end

    Enum.each(pack_ids, fn atom_id ->
      id = to_string(atom_id)

      # imported function with scope
      defp do_tokenize(
             <<unquote(id), "(", rest::binary>>,
             acc,
             %{imports: %{unquote(pack_name) => true}} = config
           ) do
        cond do
          Regex.match?(@r_fnclosoure, rest) ->
            do_tokenize(
              rest,
              [
                "#{unquote(pack_name)}.#{unquote(id)}" | acc
              ],
              config
            )

          true ->
            do_tokenize(
              inject_ending(rest),
              [
                "#{unquote(pack_name)}.#{unquote(id)}",
                "(" | acc
              ],
              config
            )
        end
      end

      # imported function WITHOUT scope
      defp do_tokenize(
             <<unquote(id), c::utf8, rest::binary>>,
             acc,
             %{imports: %{unquote(pack_name) => true}} = config
           )
           when is_fn_complete(c) do
        rest = <<c>> <> rest

        cond do
          Regex.match?(@r_fnclosoure, rest) ->
            do_tokenize(
              rest,
              [
                "#{unquote(pack_name)}.#{unquote(id)}" | acc
              ],
              config
            )

          true ->
            do_tokenize(
              inject_ending(rest),
              [
                "#{unquote(pack_name)}.#{unquote(id)}",
                "(" | acc
              ],
              config
            )
        end
      end

      # NON-imported function with scope
      defp do_tokenize(
             <<unquote(pack_name), ".", unquote(id), "(", rest::binary>>,
             acc,
             config
           ) do
        cond do
          Regex.match?(@r_fnclosoure, rest) ->
            do_tokenize(
              rest,
              [
                "#{unquote(pack_name)}.#{unquote(id)}" | acc
              ],
              config
            )

          true ->
            do_tokenize(
              inject_ending(rest),
              [
                "#{unquote(pack_name)}.#{unquote(id)}",
                "(" | acc
              ],
              config
            )
        end
      end

      # NON-imported function WITHOUT scope
      defp do_tokenize(
             <<unquote(pack_name), ".", unquote(id), c::utf8, rest::binary>>,
             acc,
             config
           )
           when is_fn_complete(c) do
        rest = <<c>> <> rest

        cond do
          Regex.match?(@r_fnclosoure, rest) ->
            do_tokenize(
              rest,
              [
                "#{unquote(pack_name)}.#{unquote(id)}" | acc
              ],
              config
            )

          true ->
            do_tokenize(
              inject_ending(rest),
              [
                "#{unquote(pack_name)}.#{unquote(id)}",
                "(" | acc
              ],
              config
            )
        end
      end
    end)
  end)

  # Handle numbers
  Enum.each(0..9, fn num ->
    str = to_string(num)

    defp do_tokenize(<<"-", unquote(str), rest::binary>>, acc, config) do
      do_tokenize_num(unquote(str) <> rest, acc, true, config)
    end

    defp do_tokenize(<<unquote(str), rest::binary>>, acc, config) do
      do_tokenize_num(unquote(str) <> rest, acc, false, config)
    end
  end)

  # handle json objects
  defp do_tokenize(<<"%'", rest::binary>>, acc, config) do
    do_tokenize_string(rest, acc, "%'", config)
  end

  # Handle operators
  Enum.each(@lang_ops, fn op ->
    defp do_tokenize(<<unquote(op), rest::binary>>, acc, config) do
      do_tokenize(rest, [unquote(op) | acc], config)
    end
  end)

  # Variable indicators
  Enum.each(@lang_var, fn var ->
    defp do_tokenize(<<unquote(var), rest::binary>>, acc, config) do
      case Regex.run(@r_var, rest) do
        [var_name] ->
          rest = String.slice(rest, String.length(var_name)..-1)
          do_tokenize(rest, [unquote(var) <> var_name | acc], config)

        _ ->
          {:error, acc, rest, "Bad variable name!"}
      end
    end
  end)

  defp do_tokenize(<<"true", rest::binary>>, acc, config) do
    do_tokenize(rest, [true | acc], config)
  end

  defp do_tokenize(<<"false", rest::binary>>, acc, config) do
    do_tokenize(rest, [false | acc], config)
  end

  # handle empty strings
  defp do_tokenize(<<"''", rest::binary>>, acc, config) do
    do_tokenize(rest, ["''" | acc], config)
  end

  # handle strings
  defp do_tokenize(<<"'", rest::binary>>, acc, config) do
    do_tokenize_string(rest, acc, "'", config)
  end

  # Ignores space
  defp do_tokenize(<<" ", rest::binary>>, acc, config) do
    do_tokenize(rest, acc, config)
  end

  # Ignores tab
  defp do_tokenize(<<"\t", rest::binary>>, acc, config) do
    do_tokenize(rest, acc, config)
  end

  # Handles new line (Linux line ending)
  defp do_tokenize(<<"\n", rest::binary>>, acc, config) do
    do_tokenize(rest, ["\n" | acc], config)
  end

  # Ignores comment
  defp do_tokenize(<<"#", rest::binary>>, acc, config) do
    skip_line(rest, acc, config)
  end

  defp do_tokenize(<<"nil", rest::binary>>, acc, config) do
    do_tokenize(rest, ["nil" | acc], config)
  end

  # Unmatched binary
  defp do_tokenize(bin, acc, config) do
    cond do
      Regex.match?(@r_lable, bin) ->
        # Lable
        [_, lable] = Regex.run(@r_lable, bin)

        acc =
          acc
          |> inject("def")
          |> inject(lable)

        skip_line(bin, acc, config)

      Regex.match?(@r_goto, bin) ->
        # Goto instruction
        [_, destination] = Regex.run(@r_goto, bin)

        acc =
          acc
          |> inject("goto")
          |> inject(destination)

        skip_line(bin, acc, config)

      true ->
        # Unmatched code. error will be generated!
        {:error, acc, bin, "Unknown expression in line! #{Enum.count(acc)}"}
    end
  end

  defp do_tokenize_string(rest, acc, add, config) do
    case Regex.run(@r_string, rest, return: :index) do
      [_, {loc, _}] ->
        loc = loc + 1
        string = add <> String.slice(rest, 0, loc)

        if String.contains?(string, "\n") do
          {:error, acc, rest, "expected ' for end of string!"}
        else
          {cmp_string, _} =
            Code.eval_string(
              "\"" <> String.replace(string, "\"", "\\\"") <> "\""
            )

          rest
          |> String.slice(loc..-1)
          |> do_tokenize([cmp_string | acc], config)
        end

      _ ->
        {:error, acc, rest, "expected ' for end of string!"}
    end
  end

  defp do_tokenize_num(rest, acc, neg, config) do
    num_cnt =
      case Regex.run(@r_number, rest, return: :index) do
        [{0, num_cnt}] ->
          num_cnt

        _ ->
          0
      end

    r_num = String.slice(rest, 0, num_cnt)

    final_num =
      cond do
        String.contains?(r_num, ".") ->
          {f_num, ""} = Float.parse(r_num)
          f_num

        true ->
          {i_num, ""} = Integer.parse(r_num)
          i_num
      end

    final_num =
      if neg do
        -1 * final_num
      else
        final_num
      end

    do_tokenize(String.slice(rest, num_cnt..-1), [final_num | acc], config)
  end

  # Skips a line until line ending or empty binary
  defp skip_line(<<"\n", _::binary>> = bin, acc, config),
    do: do_tokenize(bin, acc, config)

  defp skip_line(<<>>, acc, config), do: do_tokenize(<<>>, acc, config)

  defp skip_line(<<_::utf8, rest::binary>>, acc, config),
    do: skip_line(rest, acc, config)

  defp inject(acc, x) do
    [x | acc]
  end

  defp inject_ending(string) do
    Regex.replace(@r_eol, string, ")\n", global: false)
  end

  @doc false
  def get_lang_ids, do: @lang_ids
  @doc false
  def get_lang_ops, do: @lang_ops
end
