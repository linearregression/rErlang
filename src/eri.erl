-module(eri).

% API
-export([start/0, start/1, stop/0,init/1]).
-export([connect/0, parse/1, eval/1, sum/2]).


start()->	
	Path = case os:cmd("echo $SENSOR_PATH") of
			"\n" -> 
				".";
			SensorPath ->
				SensorPath--"\n"
		  end,
		  erlang:display(Path),
    start(Path++"/lib/rErlang/bin/ERI-0.1").
start(ExtPrg) ->
    register(?MODULE, spawn_link(?MODULE, init, [ExtPrg])).

stop() ->
    case call_port({stop}) of 
	{ok} ->
	    io:fwrite("terminate R session\n"),
	    ?MODULE ! stop;
	{error} -> 
	    io:fwrite("fail terminate R session\n"),
	    ?MODULE ! stop;
	_ ->
	    ?MODULE ! stop
    end.

connect() -> 
    call_port({setup}).

parse(X)->
    call_port({parse,X}).

    
eval(X)->    
    case parse(X) of
	{ok,Result} -> call_port({eval,Result});
	_ -> {error}
    end.

init(ExtPrg)->
    process_flag(trap_exit, true),
    Port = open_port({spawn, ExtPrg}, [{packet,2}, binary]),
    loop(Port).

sum(X,Y) -> call_port({sum, X, Y}).

call_port(Msg) ->
    %erlang:display("sending message: "),
    %erlang:display(Msg),
    ?MODULE ! {call, self(), Msg},
    receive
	{?MODULE, Result}->
	    Result
    end.

loop(Port) ->
    receive
	{call, Caller, Msg} ->
	    Port ! {self(), {command, term_to_binary(Msg)}},
	    receive
		{Port, {data, Data}} ->
		    %erlang:display(Data),
		    Caller ! {?MODULE, binary_to_term(Data)}
	    end,
	    loop(Port);
	stop ->
	    erlang:display("Now actually trying to stop"),
	    Port ! {self(), close},
	    receive
		{Port, closed} ->
		    exit(normal)
	    end;
	{'EXIT', Port, Reason} ->
	    exit({port_terminated, Reason})
    end.
