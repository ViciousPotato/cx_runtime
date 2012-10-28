-module(concurix_compile).
-export([string_to_form/1, string_to_form/2, handle_spawn/3, get_arg_n/2, handle_memo/4]).

string_to_form(String) ->
	{ok, Tokens, _} = erl_scan:string(String),
	{ok, Forms} = erl_parse:parse_exprs(Tokens),
	Forms.
	
string_to_form(String, CallArgs) ->
	Forms = string_to_form(String),
	replace_args(Forms, CallArgs).
	
	
handle_spawn(Line, [{atom, Line2, Module}, {atom, Line3, Fun}, CallArgs], Type) ->
	case ets:lookup(concurix_config_spawn, {Module, Fun}) of
		[{_, Expr }] ->
			SpawnFun = {atom, Line, spawn_opt},
			SpawnOpt = "[" ++ type_to_string(Type) ++ "{min_heap_size," ++ Expr ++ "}].",
			ArgsNew = [{atom, Line2, Module}, {atom, Line3, Fun}, CallArgs] ++ string_to_form(SpawnOpt, CallArgs),
			io:format("concurix_compile: Computed Spawn Opt for ~p:~p with expression ~p ~n",  [Module, Fun, Expr]),
			{SpawnFun, ArgsNew};			
		_X -> 
			{{atom, Line, Type}, [{atom, Line2, Module}, {atom, Line3, Fun}, CallArgs]}
	end;

handle_spawn(Line, Args, Type) ->
	Fun = {atom, Line, Type},
	{Fun, Args}.


handle_memo(Line, MFLookup, Fun, Args) ->
	case ets:lookup(concurix_config_memo, MFLookup) of
		[{_, local}] ->
			io:format("concurix_compile: trying to memoize Line ~p M:F ~p ~p ~n", [Line, MFLookup, Fun]),
			generate_call_local_memo(Line, Fun, Args);
		_X -> 
			{Fun, Args}
	end.
	
generate_call_local_memo(Line, Fun, Args) ->
	{{remote, Line, {atom, Line, concurix_memo}, {atom, Line, local_memoize}},
		[{'fun', Line, {clauses, [{clause, Line, [], [], [{call, Line, Fun, Args}]}]}}]}.
	
get_arg_n(CallArgs, 1) ->
	{cons, _Line, Arg, _Remainder} = CallArgs,
	Arg;
get_arg_n(CallArgs, N) ->
	{cons, _Line, _Arg, Remainder} = CallArgs,
	get_arg_n(Remainder, N-1).

%% If it's the kind of record I'm looking for, replace it.
replace_args({call, _, {atom, _, arg}, [{integer, _, Index}]}, CallArgs) ->
	get_arg_n(CallArgs, Index);

%% If it's a list, recurse into the head and tail
replace_args([Hd|Tl], CallArgs) ->
    [replace_args(Hd, CallArgs)|replace_args(Tl, CallArgs)];

%% If it's a tuple, which of course includes records, recurse into the
%% fields
replace_args(Tuple, CallArgs) when is_tuple(Tuple) ->
    list_to_tuple([replace_args(E, CallArgs) || E <- tuple_to_list(Tuple)]);

%% Otherwise, return the original.
replace_args(Leaf, _CallArgs) ->
    Leaf.

type_to_string(Type) ->
	case Type of
		spawn -> "";
		spawn_link -> "link,";
		spawn_monitor ->"monitor,"
	end.
	
