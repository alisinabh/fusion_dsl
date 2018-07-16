defmodule FusionDsl.Processor.Program do
  @moduledoc """
  Program struct
  """

  @typedoc """
  Structure of a compiled program. contains procedure, configs, name, software
  and runtime version.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          config: [Keyword.t()],
          fusion_version: non_neg_integer(),
          procedures: %{String.t() => list(ast)}
        }

  @typedoc """
  AST structure of FusionDsl

  A tuple with three elements.

   - First: The calling function info.
   - Second: The context of the generated AST.
   - Third: List of arguments for current AST. 
  """
  @type ast :: {ast_fn, ast_ctx, [ast_arg]}

  @typedoc """
  A single atom in case of internal operations (such as jump, if, noop etc.)
  Or a tuple of {`module_atom`, `function_name_atom`} in case of foreign functions.

  Calls to foreign functions will NOT containt module atom and will be a single atom only.
  """
  @type ast_fn :: atom() | {atom(), atom()}

  @typedoc """
  Context of each AST, Holds data like Line number (`:ln`)
  """
  @type ast_ctx :: {:ln, integer}

  @typedoc """
  List of ast arguments. These args can be immediate values or AST

  `FusionDsl.Impl.prep_args/2` can be used to get immediate values of ASTs
  """
  @type ast_arg :: ast | integer | float | String.t() | map

  defstruct [:name, :version, config: [], fusion_version: nil, procedures: %{}]
end
