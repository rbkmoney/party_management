-module(pm_client_api).

-export([new/1]).
-export([new/2]).
-export([call/4]).

-export_type([t/0]).

%%

-type t() :: {woody:url(), woody_context:ctx()}.

-spec new(woody:url()) -> t().
new(RootUrl) ->
    new(RootUrl, woody_context:new()).

-spec new(woody:url(), woody_context:ctx()) -> t().
new(RootUrl, Context) ->
    {RootUrl, Context}.

-spec call(Name :: atom(), woody:func(), [any()], t()) -> {{ok, _Response} | {exception, _} | {error, _}, t()}.
call(ServiceName, Function, Args, {RootUrl, Context}) ->
    Service = pm_proto:get_service(ServiceName),
    Request = {Service, Function, list_to_tuple(Args)},
    Opts = get_opts(ServiceName),
    Result =
        try
            woody_client:call(Request, Opts, Context)
        catch
            error:Error:ST ->
                {error, {Error, ST}}
        end,
    {Result, {RootUrl, Context}}.

get_opts(ServiceName) ->
    EventHandlerOpts = genlib_app:env(party_management, scoper_event_handler_options, #{}),
    Opts0 = #{
        event_handler => {scoper_woody_event_handler, EventHandlerOpts}
    },
    case maps:get(ServiceName, genlib_app:env(party_management, services), undefined) of
        #{} = Opts ->
            maps:merge(Opts, Opts0);
        _ ->
            Opts0
    end.
