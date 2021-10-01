-module(pm_client).

-include_lib("damsel/include/dmsl_payment_processing_thrift.hrl").
-include_lib("damsel/include/dmsl_claim_management_thrift.hrl").

-export([start/2]).
-export([start/3]).
-export([start_link/2]).
-export([stop/1]).

%% Party Management API

-export([create_party/2]).
-export([get_party/1]).
-export([get_party_revision/1]).
-export([checkout_party/2]).
-export([block_party/2]).
-export([unblock_party/2]).
-export([suspend_party/1]).
-export([activate_party/1]).
-export([get_party_status/1]).

-export([get_party_meta/1]).
-export([get_party_metadata/2]).
-export([set_party_metadata/3]).
-export([remove_party_metadata/2]).

-export([get_contract/2]).
-export([compute_contract_terms/6]).
-export([get_shop/2]).
-export([compute_shop_terms/5]).
-export([compute_payment_institution_terms/3]).
-export([compute_payout_cash_flow/2]).

-export([block_shop/3]).
-export([unblock_shop/3]).
-export([suspend_shop/2]).
-export([activate_shop/2]).

-export([get_claim/2]).
-export([get_claims/1]).

-export([get_account_state/2]).
-export([get_shop_account/2]).
-export([pull_event/1]).
-export([pull_event/2]).

-export([compute_provider/4]).
-export([compute_provider_terminal_terms/5]).
-export([compute_globals/3]).
-export([compute_routing_ruleset/4]).

%% Claim Committer API

-export([accept_claim/2]).
-export([commit_claim/2]).

%% GenServer

-behaviour(gen_server).

-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

%%

-type user_info() :: dmsl_payment_processing_thrift:'UserInfo'().
-type party_id() :: dmsl_domain_thrift:'PartyID'().
-type party_params() :: dmsl_payment_processing_thrift:'PartyParams'().
-type domain_revision() :: dmsl_domain_thrift:'DataRevision'().
-type contract_id() :: dmsl_domain_thrift:'ContractID'().
-type shop_id() :: dmsl_domain_thrift:'ShopID'().
-type claim_id() :: dmsl_payment_processing_thrift:'ClaimID'().
-type claim() :: dmsl_payment_processing_thrift:'Claim'().
-type shop_account_id() :: dmsl_domain_thrift:'AccountID'().
-type meta() :: dmsl_domain_thrift:'PartyMeta'().
-type meta_ns() :: dmsl_domain_thrift:'PartyMetaNamespace'().
-type meta_data() :: dmsl_domain_thrift:'PartyMetaData'().
-type timestamp() :: dmsl_base_thrift:'Timestamp'().

-type party_revision_param() :: dmsl_payment_processing_thrift:'PartyRevisionParam'().
-type payment_intitution_ref() :: dmsl_domain_thrift:'PaymentInstitutionRef'().
-type varset() :: dmsl_payment_processing_thrift:'Varset'().

-type provider_ref() :: dmsl_domain_thrift:'ProviderRef'().
-type terminal_ref() :: dmsl_domain_thrift:'TerminalRef'().
-type routing_ruleset_ref() :: dmsl_domain_thrift:'RoutingRulesetRef'().

-type cm_claim() :: dmsl_claim_management_thrift:'Claim'().

-spec start(party_id(), pm_client_api:t()) -> pid().
start(PartyID, ApiClient) ->
    start(start, undefined, PartyID, ApiClient).

-spec start(user_info(), party_id(), pm_client_api:t()) -> pid().
start(UserInfo, PartyID, ApiClient) ->
    start(start, UserInfo, PartyID, ApiClient).

-spec start_link(party_id(), pm_client_api:t()) -> pid().
start_link(PartyID, ApiClient) ->
    start(start_link, undefined, PartyID, ApiClient).

start(Mode, UserInfo, PartyID, ApiClient) ->
    {ok, Pid} = gen_server:Mode(?MODULE, {UserInfo, PartyID, ApiClient}, []),
    Pid.

-spec stop(pid()) -> ok.
stop(Client) ->
    _ = exit(Client, shutdown),
    ok.

%%

-spec create_party(party_params(), pid()) -> ok | woody_error:business_error().
create_party(PartyParams, Client) ->
    map_result_error(gen_server:call(Client, {call, 'Create', [PartyParams]})).

-spec get_party(pid()) -> dmsl_domain_thrift:'Party'() | woody_error:business_error().
get_party(Client) ->
    map_result_error(gen_server:call(Client, {call, 'Get', []})).

-spec get_party_revision(pid()) -> dmsl_domain_thrift:'Party'() | woody_error:business_error().
get_party_revision(Client) ->
    map_result_error(gen_server:call(Client, {call, 'GetRevision', []})).

-spec get_party_status(pid()) -> dmsl_domain_thrift:'PartyStatus'() | woody_error:business_error().
get_party_status(Client) ->
    map_result_error(gen_server:call(Client, {call, 'GetStatus', []})).

-spec checkout_party(party_revision_param(), pid()) -> dmsl_domain_thrift:'Party'() | woody_error:business_error().
checkout_party(PartyRevisionParam, Client) ->
    map_result_error(gen_server:call(Client, {call, 'Checkout', [PartyRevisionParam]})).

-spec block_party(binary(), pid()) -> ok | woody_error:business_error().
block_party(Reason, Client) ->
    map_result_error(gen_server:call(Client, {call, 'Block', [Reason]})).

-spec unblock_party(binary(), pid()) -> ok | woody_error:business_error().
unblock_party(Reason, Client) ->
    map_result_error(gen_server:call(Client, {call, 'Unblock', [Reason]})).

-spec suspend_party(pid()) -> ok | woody_error:business_error().
suspend_party(Client) ->
    map_result_error(gen_server:call(Client, {call, 'Suspend', []})).

-spec activate_party(pid()) -> ok | woody_error:business_error().
activate_party(Client) ->
    map_result_error(gen_server:call(Client, {call, 'Activate', []})).

-spec get_party_meta(pid()) -> meta() | woody_error:business_error().
get_party_meta(Client) ->
    map_result_error(gen_server:call(Client, {call, 'GetMeta', []})).

-spec get_party_metadata(meta_ns(), pid()) -> meta_data() | woody_error:business_error().
get_party_metadata(NS, Client) ->
    map_result_error(gen_server:call(Client, {call, 'GetMetaData', [NS]})).

-spec set_party_metadata(meta_ns(), meta_data(), pid()) -> ok | woody_error:business_error().
set_party_metadata(NS, Data, Client) ->
    map_result_error(gen_server:call(Client, {call, 'SetMetaData', [NS, Data]})).

-spec remove_party_metadata(meta_ns(), pid()) -> ok | woody_error:business_error().
remove_party_metadata(NS, Client) ->
    map_result_error(gen_server:call(Client, {call, 'RemoveMetaData', [NS]})).

-spec get_contract(contract_id(), pid()) -> dmsl_domain_thrift:'Contract'() | woody_error:business_error().
get_contract(ID, Client) ->
    map_result_error(gen_server:call(Client, {call, 'GetContract', [ID]})).

-spec compute_contract_terms(contract_id(), timestamp(), party_revision_param(), domain_revision(), varset(), pid()) ->
    dmsl_domain_thrift:'TermSet'() | woody_error:business_error().
compute_contract_terms(ID, Timestamp, PartyRevision, DomainRevision, Varset, Client) ->
    Args = [ID, Timestamp, PartyRevision, DomainRevision, Varset],
    map_result_error(gen_server:call(Client, {call, 'ComputeContractTerms', Args})).

-spec compute_payment_institution_terms(payment_intitution_ref(), varset(), pid()) ->
    dmsl_domain_thrift:'TermSet'() | woody_error:business_error().
compute_payment_institution_terms(Ref, Varset, Client) ->
    map_result_error(gen_server:call(Client, {call_without_party, 'ComputePaymentInstitutionTerms', [Ref, Varset]})).

-spec compute_payout_cash_flow(dmsl_payment_processing_thrift:'PayoutParams'(), pid()) ->
    dmsl_domain_thrift:'FinalCashFlow'() | woody_error:business_error().
compute_payout_cash_flow(Params, Client) ->
    map_result_error(gen_server:call(Client, {call, 'ComputePayoutCashFlow', [Params]})).

-spec get_shop(shop_id(), pid()) -> dmsl_domain_thrift:'Shop'() | woody_error:business_error().
get_shop(ID, Client) ->
    map_result_error(gen_server:call(Client, {call, 'GetShop', [ID]})).

-spec block_shop(shop_id(), binary(), pid()) -> ok | woody_error:business_error().
block_shop(ID, Reason, Client) ->
    map_result_error(gen_server:call(Client, {call, 'BlockShop', [ID, Reason]})).

-spec unblock_shop(shop_id(), binary(), pid()) -> ok | woody_error:business_error().
unblock_shop(ID, Reason, Client) ->
    map_result_error(gen_server:call(Client, {call, 'UnblockShop', [ID, Reason]})).

-spec suspend_shop(shop_id(), pid()) -> ok | woody_error:business_error().
suspend_shop(ID, Client) ->
    map_result_error(gen_server:call(Client, {call, 'SuspendShop', [ID]})).

-spec activate_shop(shop_id(), pid()) -> ok | woody_error:business_error().
activate_shop(ID, Client) ->
    map_result_error(gen_server:call(Client, {call, 'ActivateShop', [ID]})).

-spec compute_shop_terms(shop_id(), timestamp(), party_revision_param(), varset(), pid()) ->
    dmsl_domain_thrift:'TermSet'() | woody_error:business_error().
compute_shop_terms(ID, Timestamp, PartyRevision, VS, Client) ->
    map_result_error(gen_server:call(Client, {call, 'ComputeShopTerms', [ID, Timestamp, PartyRevision, VS]})).

-spec get_claim(claim_id(), pid()) -> claim() | woody_error:business_error().
get_claim(ID, Client) ->
    map_result_error(gen_server:call(Client, {call, 'GetClaim', [ID]})).

-spec get_claims(pid()) -> [claim()] | woody_error:business_error().
get_claims(Client) ->
    map_result_error(gen_server:call(Client, {call, 'GetClaims', []})).

-spec get_account_state(shop_account_id(), pid()) ->
    dmsl_payment_processing_thrift:'AccountState'() | woody_error:business_error().
get_account_state(AccountID, Client) ->
    map_result_error(gen_server:call(Client, {call, 'GetAccountState', [AccountID]})).

-spec get_shop_account(shop_id(), pid()) -> dmsl_domain_thrift:'ShopAccount'() | woody_error:business_error().
get_shop_account(ShopID, Client) ->
    map_result_error(gen_server:call(Client, {call, 'GetShopAccount', [ShopID]})).

-spec compute_provider(provider_ref(), domain_revision(), varset(), pid()) ->
    dmsl_domain_thrift:'Provider'() | woody_error:business_error().
compute_provider(ProviderRef, Revision, Varset, Client) ->
    map_result_error(gen_server:call(Client, {call_without_party, 'ComputeProvider', [ProviderRef, Revision, Varset]})).

-spec compute_provider_terminal_terms(
    provider_ref(),
    terminal_ref(),
    domain_revision(),
    varset(),
    pid()
) -> dmsl_domain_thrift:'ProvisionTermSet'() | woody_error:business_error().
compute_provider_terminal_terms(ProviderRef, TerminalRef, Revision, Varset, Client) ->
    map_result_error(
        gen_server:call(
            Client,
            {call_without_party, 'ComputeProviderTerminalTerms', [ProviderRef, TerminalRef, Revision, Varset]}
        )
    ).

-spec compute_globals(domain_revision(), varset(), pid()) ->
    dmsl_domain_thrift:'Globals'() | woody_error:business_error().
compute_globals(Revision, Varset, Client) ->
    map_result_error(gen_server:call(Client, {call_without_party, 'ComputeGlobals', [Revision, Varset]})).

-spec compute_routing_ruleset(routing_ruleset_ref(), domain_revision(), varset(), pid()) ->
    dmsl_domain_thrift:'RoutingRuleset'() | woody_error:business_error().
compute_routing_ruleset(RoutingRuleSetRef, Revision, Varset, Client) ->
    map_result_error(
        gen_server:call(
            Client,
            {call_without_party, 'ComputeRoutingRuleset', [RoutingRuleSetRef, Revision, Varset]}
        )
    ).

%%

-spec accept_claim(cm_claim(), pid()) -> ok | woody_error:business_error().
accept_claim(Claim, Client) ->
    map_result_error(gen_server:call(Client, {call_claim_committer, 'Accept', [Claim]})).

-spec commit_claim(cm_claim(), pid()) -> ok | woody_error:business_error().
commit_claim(Claim, Client) ->
    map_result_error(gen_server:call(Client, {call_claim_committer, 'Commit', [Claim]})).

%%

-define(DEFAULT_NEXT_EVENT_TIMEOUT, 5000).

-spec pull_event(pid()) -> tuple() | timeout | woody_error:business_error().
pull_event(Client) ->
    pull_event(?DEFAULT_NEXT_EVENT_TIMEOUT, Client).

-spec pull_event(timeout(), pid()) -> tuple() | timeout | woody_error:business_error().
pull_event(Timeout, Client) ->
    gen_server:call(Client, {pull_event, Timeout}, infinity).

map_result_error({ok, Result}) ->
    Result;
map_result_error({exception, _} = Exception) ->
    Exception;
map_result_error({error, Error}) ->
    error(Error).

%%

-type event() :: dmsl_payment_processing_thrift:'Event'().

-record(state, {
    user_info :: user_info(),
    party_id :: party_id(),
    poller :: pm_client_event_poller:st(event()),
    client :: pm_client_api:t()
}).

-type state() :: #state{}.
-type callref() :: {pid(), Tag :: reference()}.

-spec init({user_info(), party_id(), pm_client_api:t()}) -> {ok, state()}.
init({UserInfo, PartyID, ApiClient}) ->
    {ok, #state{
        user_info = UserInfo,
        party_id = PartyID,
        client = ApiClient,
        poller = pm_client_event_poller:new(
            {party_management, 'GetEvents', [UserInfo, PartyID]},
            fun(Event) -> Event#payproc_Event.id end
        )
    }}.

-spec handle_call(term(), callref(), state()) -> {reply, term(), state()} | {noreply, state()}.
handle_call({call, Function, Args0}, _From, St = #state{client = Client}) ->
    Args = [St#state.user_info, St#state.party_id | Args0],
    Result = pm_client_api:call(party_management, Function, Args, Client),
    {reply, Result, St};
handle_call({call_without_party, Function, Args0}, _From, St = #state{client = Client}) ->
    Args = [St#state.user_info | Args0],
    Result = pm_client_api:call(party_management, Function, Args, Client),
    {reply, Result, St};
handle_call({call_claim_committer, Function, Args}, _From, St = #state{client = Client}) ->
    Result = pm_client_api:call(claim_committer, Function, [St#state.party_id | Args], Client),
    {reply, Result, St};
handle_call({pull_event, Timeout}, _From, St = #state{poller = Poller, client = Client}) ->
    {Result, PollerNext} = pm_client_event_poller:poll(1, Timeout, Client, Poller),
    StNext = St#state{poller = PollerNext},
    case Result of
        [] ->
            {reply, timeout, StNext};
        [#payproc_Event{payload = Payload}] ->
            {reply, Payload, StNext};
        Error ->
            {reply, Error, StNext}
    end;
handle_call(Call, _From, State) ->
    _ = logger:warning("unexpected call received: ~tp", [Call]),
    {noreply, State}.

-spec handle_cast(_, state()) -> {noreply, state()}.
handle_cast(Cast, State) ->
    _ = logger:warning("unexpected cast received: ~tp", [Cast]),
    {noreply, State}.

-spec handle_info(_, state()) -> {noreply, state()}.
handle_info(Info, State) ->
    _ = logger:warning("unexpected info received: ~tp", [Info]),
    {noreply, State}.

-spec terminate(Reason, state()) -> ok when Reason :: normal | shutdown | {shutdown, term()} | term().
terminate(_Reason, _State) ->
    ok.

-spec code_change(Vsn | {down, Vsn}, state(), term()) -> {error, noimpl} when Vsn :: term().
code_change(_OldVsn, _State, _Extra) ->
    {error, noimpl}.
