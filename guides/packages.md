# Packages

Fusion DSL is a pluggable domain specific language, Which means packages can be developed
to be used in Fusion code.

Every package is simply an elixir module implementing the `FusionDsl.Impl` behaviour.

## Using packages

To use packages you can add their dependency in `mix.exs` and reconfigure `:packages` config
parameter for `:fusion_dsl` OTP application.

For example imagine we have a package called `FusionPackage` and this package is in hex.pm by 
name of `:fusion_package`. To use this package, first we need to add the dependency.

```elixir
def deps do
  [
    {:fusion_package, "~> 0.1.0"} # Copy form package description on hex.pm
	...
  ]
end
```

Then we will need to add the package in packages list of FusionDSL config.
to do that we will enter change `config.exs` of our project to:

```elixir
use Mix.Config

config :fusion_dsl, packages: [
	{FusionPackage, [as: "DifferentName", type: :fusion]}
]
```

The first element of tuple is the package module we want to use and the second one
is the options keyword list.

### About the options

 - `:as`: A string to change the name of package in fusion code.
 - `:type`: Could be `:fusion` or `:native` if the module is not a fusion package module.
 - `:functions`: For native modules only. Determines list of exported functions for proxy
    fusion modules.

## Create a new package

To create a new FusionDsl package you will need to create a new elixir project.

```
mix new my_fusion_package
```

After that you will need to add FusionDSL as a dependency inside your project:

```elixir
defp deps do
  [
    {:fusion_dsl, ">= 0.0.0"} # Please use strict versioning instead
	...
  ]
end
```

Then create a new module and use `FusionDsl.Impl` in your module. This module should
hold data about the following:

 - What functions does your package provide?
 - Implementation of functions.
 - Documentation of functions and their arguments.

### Basic module

Each FusionDsl Package module should implement at least two functions. The first function 
is the `__list_fusion_functions__/0` functions. This function returns a list of function names
that this package provide as atoms. e.g. `[:foo, :bar]`

```elixir
defmodule FusionPackage do
  @moduledoc """
  Documentation of the package
  """
  use FusionDsl.Impl

  @impl true
  def __list_fusion_functions__ do
	[:foo, :bar]
	# These are function names that a fusion developer is allowed
	# allowed to call from your package. Implementation of these
	# functions should be in this same module.
  end

  @doc "Documentation for foo and its arguments"
  def foo(_ast, env) do
	{:ok, "I Am FOO!", env}
  end

  @doc "Documentation for bar and its arguments"
  def bar(_ast, env) do
    {:ok, "I Am BAR!", env}
  end
end
```

Here we have a simple module called `FusionPackage` which enables us to call `foo()` and `bar()`
functions from our fusion code. Lets dig into it.

### List functions

There should be a `__list_fusion_functions__/0` function in every fusion package module.
It should return a list of atoms which are function names that this package implements for
fusion. Each function name that you provide here should be implemented in this same module.

### Implementing functions

For implementing a function you should create a new function with the same name as you entered 
in `__list_fusion_functions__`. Like I've entered `:foo` and `:bar` as my function names.
so, I will be implementing two public functions called `def foo(...)` and `def bar(...)`.

Every fusion package function will have **only** two arguments. The first argument is the
AST (Abstract syntax tree which we will talk about later) of the call which user made 
and the second one is the environment which the program is running in.

The AST is the syntax tree of a call in fusion. The structure of an ast a 3 element tuple like
this: `{FunctionNameAtom, ContextKeywordList, ListOfArguments}`.

 - FunctionNameAtom: The atom name of the called function called. (rarely usable for packages)
 - ContextKeywordList: Information about the call. like `:ln` which is Line Number of the call in code
 - ListOfArguments: A List of arguments which user passed to the function. Could be immediate values like 
	`true | false | 1 | 'string' |...` or more ASTs.

So lets say we want `foo` to accept a single numeric argument and return the double of
that number.

We will change the implementation of `foo` into this.

```elixir
def foo({:foo, _ctx, [number]}, env) do
  result = number * 2
  {:ok, result, env}
end
```

In this function we first got the argument from the AST using pattern matching in function parameters.
Then we will double the number and return it in a tuple like `{:ok, ANYTHING_YOU_WANT_TO_RETURN, env}`.

It's a bit confusing but i promise it will get easy to understand :)

So there are a couple of questions

 - Why did we included `env` in arguments and function result?
 - Why did we returned the result in a tuple?

We included `env` because we will need it for:

 - Preparing the arguments. User will not always provide immediate values. They sometimes run another
   call in order to pass the value to your function. Like `foo(rand(1, 10))` (rand: generate a random 
   number in range)
 - Writing to assigns. Every fusion package can write their context data in env assigns. You can use
   `put_assign` and `get_assign` to do that. Somehow like how elixir plug works.
 - Manipulating variables. You can access all variables in the current environment.
 - Manipulating procedures. You can change codes live to any procedure **BUT** the current one.

We returned the result in a tuple just because we needed to return both `result` and `env`.

### Preparing arguments

There is a problem with the `foo` implementation in [FusionPackage](#basic-module). It works in the below situations:
```
$var = foo(1)
$var = foo(10)
$var = foo(452)
```

But it **wont work** in these situations:
```
$var = foo(rand(1, 2))
$var = foo(SomeModule.generate())
$var = foo(21 + 2)
```

The reason is, non of these values are immediate values like previous ones. But they are ASTs themselfs.

 - The first one is ast of a Kernel Fusion function which generates a random number in provided range.
 - The seconds one is another package function which generates a number.
 - The third one is a simple calculation.

Why is this happening?

The reason is in fusion, we want the package developer to have full control. So by default,
the ASTs of arguments will not be prepared as immediate values.

In order to do that there is a function called `prep_arg/2` implemented. We will need to change the foo
implementation to:

```elixir
def foo({:foo, _ctx, [_] = args}, env) do
  {:ok, [number], env} = prep_arg(env, args)
  result = number * 2
  {:ok, result, env}
end
```

For more information Visit `FusionDsl.Impl` docs.

## Package Bootstrap

This is a simple and minimal bootstrap for a fusion DSL package module.

```elixir
defmodule FusionPackage do
  @moduledoc "Add docs of your package!"

  use FusionDsl.Impl

  @functions [:add]

  @impl true
  def __list_fusion_functions__, do: @functions

  @doc "function documentation. should contain docs about arguments too!"
  def add({:add, _ctx, args}, env) do
    {:ok, [number1, number2], env} = prep_arg(env, args)
	
	{:ok, number1 + number2, env} # {:ok, RESULT_HERE(Or nil if no result), env}
  end	
end
```

## Existing elixir/erlang modules as Packages

Existing Elixir or Erlang modules can be used as fusion packages without building a separate
fusion module. They can be imported with `type: :native` in their opts.

### Example

```elixir
config :fusion_dsl, packages: [
    {String, [type: :native]}, # All functions
	{Enum, [type: :native, functions: [:sum, :sort]]} # Only sum and sort functions
]
```

The `type: :native` opt, A proxy module will be created during compile time and this module
will implement the `FusionDsl.Impl` behaviour.

Then you can use these packages as if they were fusion packages.
