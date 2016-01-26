defmodule Alchemist.Code.State do

  def new do
    %{
      namespace:  [:Elixir],
      scopes:     [:Elixir],
      imports:    [[]],
      aliases:    [[]],
      vars:       [[]],
      scope_vars: [[]],
      #TODO: rename to mod_fun_arity_to_line_map
      mods_funs_to_lines: %{},
      #TODO: rename to line_to_env_map
      lines_to_env: %{}
    }
  end

  def get_current_env(state) do
    current_module  = state.namespace  |> :lists.reverse |> Module.concat
    current_imports = state.imports    |> :lists.reverse |> List.flatten
    current_aliases = state.aliases    |> :lists.reverse |> List.flatten
    current_vars    = state.scope_vars |> :lists.reverse |> List.flatten
    %{imports: current_imports, aliases: current_aliases, module: current_module, vars: current_vars}
  end

  def add_current_env_to_line(state, line) do
    env = get_current_env(state)
    %{state | lines_to_env: Map.put(state.lines_to_env, line, env)}
  end

  def add_mod_fun_to_line(state, {module, fun, arity}, line) do
    %{state | mods_funs_to_lines: Map.put(state.mods_funs_to_lines, {module, fun, arity}, line)}
  end

  def new_namespace(state, module) do
    module_reversed = :lists.reverse(module)
    namespace = module_reversed ++ state.namespace
    scopes  = module_reversed ++ state.scopes
    %{state | namespace: namespace, scopes: scopes}
  end

  def remove_module_from_namespace(state, module) do
    outer_mods = Enum.drop(state.namespace, length(module))
    outer_scopes = Enum.drop(state.scopes, length(module))
    %{state | namespace: outer_mods, scopes: outer_scopes}
  end

  def new_named_func(state, name) do
    %{state | scopes: [name|state.scopes]}
  end

  def remove_last_scope_from_scopes(state) do
    %{state | scopes: tl(state.scopes)}
  end

  def add_current_module_to_index(state, line) do
    current_module = state.namespace |> :lists.reverse |> Module.concat
    add_mod_fun_to_line(state, {current_module, nil, nil}, line)
  end

  def add_func_to_index(state, func, arity, line) do
    current_module = state.namespace |> :lists.reverse |> Module.concat
    new_state = state |> add_mod_fun_to_line({current_module, func, arity}, line)

    if !Map.has_key?(state.mods_funs_to_lines, {current_module, func, nil}) do
      new_state = new_state |> add_mod_fun_to_line({current_module, func, nil}, line)
    end
    new_state
  end

  def new_alias_scope(state) do
    %{state | aliases: [[]|state.aliases]}
  end

  def create_alias_for_current_module(state) do
    if length(state.namespace) > 2 do
      current_module = state.namespace |> :lists.reverse |> Module.concat
      alias_tuple = {Module.concat([hd(state.namespace)]), current_module}
      state |> add_alias(alias_tuple)
    else
      state
    end
  end

  def remove_alias_scope(state) do
    %{state | aliases: tl(state.aliases)}
  end

  def new_vars_scope(state) do
    %{state | vars: [[]|state.vars], scope_vars: [[]|state.scope_vars]}
  end

  def new_func_vars_scope(state) do
    %{state | vars: [[]|state.vars], scope_vars: [[]]}
  end

  def remove_vars_scope(state) do
    %{state | vars: tl(state.vars), scope_vars: tl(state.scope_vars)}
  end

  def remove_func_vars_scope(state) do
    vars = tl(state.vars)
    %{state | vars: vars, scope_vars: vars}
  end

  def add_alias(state, alias_tuple) do
    [aliases_from_scope|inherited_aliases] = state.aliases
    %{state | aliases: [[alias_tuple|aliases_from_scope]|inherited_aliases]}
  end

  def new_import_scope(state) do
    %{state | imports: [[]|state.imports]}
  end

  def remove_import_scope(state) do
    %{state | imports: tl(state.imports)}
  end

  def add_import(state, module) do
    [imports_from_scope|inherited_imports] = state.imports
    %{state | imports: [[module|imports_from_scope]|inherited_imports]}
  end

  def add_var(state, var) do
    scope = hd(state.scopes) |> Atom.to_string
    [vars_from_scope|other_vars] = state.vars

    vars_from_scope =
      if var in vars_from_scope do
        vars_from_scope
      else
        case Atom.to_string(var) do
          "_" <> _ -> vars_from_scope
          ^scope   -> vars_from_scope
          _        -> [var|vars_from_scope]
        end
      end

    %{state | vars: [vars_from_scope|other_vars], scope_vars: [vars_from_scope|tl(state.scope_vars)]}
  end

  def add_vars(state, vars) do
    vars |> Enum.reduce(state, fn(var, state) -> add_var(state, var) end)
  end

end