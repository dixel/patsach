-module(server).
-export([startserver/0,
         startserver/1]).

-define(PORT, 8115).

% Main chat server process - 
% react on user input
loop(ChatHistory, Users) ->
  receive
    {message, From, Msg} ->
      Name = proplists:get_value(From, Users, "anonymous"),
      Payload = <<"@", Name/binary, ": ", Msg/binary>>,
      % Go through all the user process ids and send them the new message
      % if it wasn't the same user that have sent it.
      lists:map(fun({Pid, _}) -> (Pid /= From) andalso (Pid ! Payload) end, Users),
      loop([Payload|ChatHistory], Users);
    {join, From, Name} ->
      Payload = <<"*", Name/binary, " joined the room\n">>,
      lists:map(fun({Pid, _}) -> (Pid /= From) andalso (Pid ! Payload) end, Users),
      % send the chat history to the users joined for the first time
      From ! string:join(lists:reverse(lists:map(fun(X) -> binary_to_list(X) end, ChatHistory)), "\n"),
      loop(ChatHistory, [{From, Name}|Users]);
    {leave, From} ->
      Name = proplists:get_value(From, Users, "anonymous"),
      Payload = <<"*", Name/binary, " left the room\n">>,
      lists:map(fun({Pid, _}) -> (Pid /= From) andalso (Pid ! Payload) end, Users),
      loop(ChatHistory, proplists:delete(From, Users));
    _ ->
      loop(ChatHistory, Users)
  end.

% Interaction with user process
user_interact(Main, Sock) ->
  receive
    Message ->
      gen_tcp:send(Sock, Message)
  end,
  user_interact(Main, Sock).

% When user connected for the first time - 
% create it's context.
serve(Listener, Main) ->
  {ok, Sock} = gen_tcp:accept(Listener),
  gen_tcp:send(Sock, <<"your nickname:> ">>),
  {ok, RawName} = gen_tcp:recv(Sock, 0),
  TrimmedSize = byte_size(RawName) - 2,
  <<Name:TrimmedSize/binary, _/binary>> = RawName,
  UserProc = spawn(fun() -> user_interact(Main, Sock) end),
  Main ! {join, UserProc, Name},
  ok = do_recv(Sock, Main, UserProc),
  Main ! {leave, UserProc},
  ok = gen_tcp:close(Sock),
  serve(Listener, Main).

do_recv(Sock, Main, UserProc) ->
  case gen_tcp:recv(Sock, 0) of
    {ok, Message} ->
      Main ! {message, UserProc, Message},
      do_recv(Sock, Main, UserProc);
    {error, closed} ->
      ok
  end.

startserver() ->
  startserver(?PORT).

startserver(Port) ->
  {ok, LSock} = gen_tcp:listen(Port,
                               [binary, {packet, 0},
                                {active, false}]),
  io:format("I am listening on ~B...~n", [Port]),
  MasterProcess = self(),
  Procs = [spawn(fun() -> serve(LSock, MasterProcess) end) || _ <- lists:seq(0, 10)],
  io:format("started ~w from ~w", [Procs, self()]),
  loop([], []).
