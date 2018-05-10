defmodule IvroneDsl.Runtime.Enviornments.TestEnviornment do
  @moduledoc """
  Enviornment for console testing a program
  """

  @behaviour IvroneDsl.Runtime.Enviornment

  @doc """
  Writes a line in test console like `play([file_name], [escape_digits])`
  """
  @impl true
  def play(_prog, env, file_name, escape_digits \\ "") do
    IO.puts("play(#{file_name}, #{escape_digits})")
    {:ok, 0, env}
  end

  @impl true
  def keycheck(
        prog,
        env,
        file_name,
        digit_count,
        timeout,
        acc_digits,
        timeout_v,
        wrongkey_v
      ) do
    IO.puts(
      "keycheck(#{file_name}, #{digit_count}, #{timeout}, #{acc_digits}, #{
        timeout_v
      }, #{wrongkey_v})"
    )

    data = IO.gets("enter_keys timeout(#{timeout}s): ")

    data = norm_input(data)

    cond do
      input_ok_digits?(data, acc_digits) and String.length(data) <= digit_count ->
        {:ok, data, env}

      true ->
        play(prog, env, wrongkey_v)

        keycheck(
          prog,
          env,
          file_name,
          digit_count,
          timeout,
          acc_digits,
          timeout_v,
          wrongkey_v
        )
    end
  end

  defp norm_input(input) do
    String.replace(input, "\n", "")
  end

  defp input_ok_digits?(<<c::utf8, t::binary>>, accepted_digits) do
    if String.contains?(accepted_digits, c) do
      input_ok_digits?(t, accepted_digits)
    else
      false
    end
  end

  defp input_ok_digits?(<<>>, _) do
    true
  end
end
