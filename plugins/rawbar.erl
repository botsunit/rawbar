-module(rawbar).

-export([rawbarize/2]).

rawbarize(Config, _App) -> 
  Deps = rebar_config:get_local(Config, deps, []),
  BaseDir = rebar_utils:base_dir(Config),
  Conf = rebar_config:get_local(Config, ?MODULE, []),
  lists:foreach(fun({App, Path}) ->
                    Options = case lists:keyfind(App, 1, Conf) of
                                {App, O} when is_list(O) -> O;
                                _ -> []
                              end,
                    io:format("=== rawbarize : ~p~n", [App]),
                    Dest = filename:join([BaseDir, priv, App]),
                    filelib:ensure_dir(filename:join([Dest, "."])),
                    recursive_copy(Path, Dest, Options)
                end, get_raw(Deps, [], Config)).

get_raw([], Raws, _) -> Raws;
get_raw([{_, _, _}|Rest], Raws, Config) -> get_raw(Rest, Raws, Config);
get_raw([{Name, _, _, Options}|Rest], Raws, Config) ->
  Raws2 = case proplists:get_value(raw, Options, false) of
            true -> 
              BaseDir = rebar_utils:base_dir(Config),
              DepsDir = rebar_config:get_xconf(Config, deps_dir, "deps"),
              DepsDir2 = filename:join([BaseDir, DepsDir, Name]),
              case filelib:is_dir(DepsDir2) of
                true -> [{Name, DepsDir2}|Raws];
                false ->
                  io:format("Missing deps ~p~n", [Name]),
                  Raws
              end;
            false -> Raws
          end,
  get_raw(Rest, Raws2, Config).

recursive_copy(From, To, Options) ->
  {ok, Files} = file:list_dir(From),
  [ok = rec_copy(From, To, X, Options) || X <- Files],
  ok.

rec_copy(_From, _To, [$. | _T], _Options) -> %% Ignore Hidden
  ok; 
rec_copy(From, To, File, Options) ->
  Ignore = case lists:keyfind(ignore, 1, Options) of
             {ignore, I} -> 
               re:run(File, I) =/= nomatch;
             _ -> false
           end,
  if
    Ignore -> ok;
    true ->
      NewFrom = filename:join(From, File),
      NewTo   = filename:join(To, File),
      case filelib:is_dir(NewFrom) of
        true  ->
          ok = filelib:ensure_dir(NewTo),
          recursive_copy(NewFrom, NewTo, Options);
        false ->
          case filelib:is_file(NewFrom) of                
            true  ->
              ok = filelib:ensure_dir(NewTo),
              {ok, _} = file:copy(NewFrom, NewTo),
              ok;
            false ->
              ok            
          end
      end
  end.
