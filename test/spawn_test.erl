-module(spawn_test).
-compile(export_all).

main(N) ->
	spawn(spawn_test, mfaspawn, [N]),
	process_flag(trap_exit, true),
	spawn_link(spawn_test, mfaspawnlink, [N]),
	receive
		{'EXIT', _Pid, N} -> ok;
		X -> X = N   %% deliberately throw an exception here so the test fails
	end,
	ok.

mfaspawn(N) ->
	io:format("Got mfaspawn ok ~p ~n", [N]).
	
mfaspawnlink(N) ->
	io:format("Got mfaspawnlink ok ~p ~n", [N]),
	exit(N).
	
	