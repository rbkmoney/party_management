-module(pm_party_tests_SUITE).

-include("claim_management.hrl").

-include_lib("party_management/test/pm_ct_domain.hrl").
-include_lib("party_management/include/party_events.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("damsel/include/dmsl_payment_processing_thrift.hrl").

-export([all/0]).
-export([groups/0]).
-export([init_per_suite/1]).
-export([end_per_suite/1]).
-export([init_per_group/2]).
-export([end_per_group/2]).
-export([init_per_testcase/2]).
-export([end_per_testcase/2]).

-export([party_creation/1]).
-export([party_not_found_on_retrieval/1]).
-export([party_already_exists/1]).
-export([party_retrieval/1]).

-export([claim_not_found_on_retrieval/1]).
-export([no_pending_claims/1]).

-export([party_revisioning/1]).
-export([party_get_initial_revision/1]).
-export([party_blocking/1]).
-export([party_unblocking/1]).
-export([party_already_blocked/1]).
-export([party_already_unblocked/1]).
-export([party_blocked_on_suspend/1]).
-export([party_suspension/1]).
-export([party_activation/1]).
-export([party_already_suspended/1]).
-export([party_already_active/1]).
-export([party_get_status/1]).

-export([party_meta_retrieval/1]).
-export([party_metadata_setting/1]).
-export([party_metadata_retrieval/1]).
-export([party_metadata_removing/1]).

-export([shop_creation/1]).
-export([shop_not_found_on_retrieval/1]).
-export([shop_aggregation/1]).
-export([shop_terms_retrieval/1]).
-export([shop_blocking/1]).
-export([shop_unblocking/1]).
-export([shop_already_blocked/1]).
-export([shop_already_unblocked/1]).
-export([shop_blocked_on_suspend/1]).
-export([shop_suspension/1]).
-export([shop_activation/1]).
-export([shop_already_suspended/1]).
-export([shop_already_active/1]).

-export([shop_account_set_retrieval/1]).
-export([shop_account_retrieval/1]).

-export([party_access_control/1]).

-export([contractor_creation/1]).

-export([contract_not_found/1]).
-export([contract_creation/1]).
-export([contract_terms_retrieval/1]).
-export([contract_p2p_terms/1]).
-export([contract_p2p_template_terms/1]).
-export([contract_w2w_terms/1]).

-export([compute_payment_institution_terms/1]).
-export([compute_payout_cash_flow/1]).

-export([compute_provider_ok/1]).
-export([compute_provider_not_found/1]).
-export([compute_provider_terminal_terms_ok/1]).
-export([compute_provider_terminal_terms_not_found/1]).
-export([compute_provider_terminal_terms_undefined_terms/1]).
-export([compute_globals_ok/1]).
-export([compute_payment_routing_ruleset_ok/1]).
-export([compute_payment_routing_ruleset_unreducable/1]).
-export([compute_payment_routing_ruleset_not_found/1]).

-export([compute_pred_w_irreducible_criterion/1]).
-export([compute_terms_w_criteria/1]).
-export([check_all_payment_methods/1]).

%% tests descriptions

-type config() :: pm_ct_helper:config().
-type test_case_name() :: pm_ct_helper:test_case_name().
-type group_name() :: pm_ct_helper:group_name().

-define(assert_different_term_sets(T1, T2),
    case T1 =:= T2 of
        true -> error({equal_term_sets, T1, T2});
        false -> ok
    end
).

cfg(Key, C) ->
    pm_ct_helper:cfg(Key, C).

-spec all() -> [{group, group_name()}].
all() ->
    [
        {group, party_access_control},
        {group, party_creation},
        {group, party_revisioning},
        {group, party_blocking_suspension},
        {group, party_meta},
        {group, party_status},
        {group, contract_management},
        {group, shop_management},
        {group, shop_account_lazy_creation},

        {group, compute},
        {group, terms}
    ].

-spec groups() -> [{group_name(), list(), [test_case_name()]}].
groups() ->
    [
        {party_creation, [sequence], [
            party_not_found_on_retrieval,
            party_creation,
            party_already_exists,
            party_retrieval
        ]},
        {party_access_control, [sequence], [
            party_creation,
            party_access_control
        ]},
        {party_revisioning, [sequence], [
            party_creation,
            party_get_initial_revision,
            party_revisioning
        ]},
        {party_blocking_suspension, [sequence], [
            party_creation,
            party_blocking,
            party_already_blocked,
            party_blocked_on_suspend,
            party_unblocking,
            party_already_unblocked,
            party_suspension,
            party_already_suspended,
            party_blocking,
            party_unblocking,
            party_activation,
            party_already_active
        ]},
        {party_meta, [sequence], [
            party_creation,
            party_metadata_setting,
            party_metadata_retrieval,
            party_metadata_removing,
            party_meta_retrieval
        ]},
        {party_status, [sequence], [
            party_creation,
            party_get_status
        ]},
        {contract_management, [sequence], [
            party_creation,
            contract_not_found,
            contractor_creation,
            contract_creation,
            contract_terms_retrieval,
            compute_payment_institution_terms,
            contract_p2p_terms,
            contract_p2p_template_terms,
            contract_w2w_terms
        ]},
        {shop_management, [sequence], [
            party_creation,
            contractor_creation,
            contract_creation,
            shop_not_found_on_retrieval,
            shop_creation,
            shop_aggregation,
            shop_terms_retrieval,
            compute_payout_cash_flow,
            {group, shop_blocking_suspension}
        ]},
        {shop_blocking_suspension, [sequence], [
            shop_blocking,
            shop_already_blocked,
            shop_blocked_on_suspend,
            shop_unblocking,
            shop_already_unblocked,
            shop_suspension,
            shop_already_suspended,
            shop_activation,
            shop_already_active
        ]},
        {shop_account_lazy_creation, [sequence], [
            party_creation,
            contractor_creation,
            contract_creation,
            shop_creation,
            shop_account_set_retrieval,
            shop_account_retrieval
        ]},

        {compute, [parallel], [
            compute_provider_ok,
            compute_provider_not_found,
            compute_provider_terminal_terms_ok,
            compute_provider_terminal_terms_not_found,
            compute_provider_terminal_terms_undefined_terms,
            compute_globals_ok,
            compute_payment_routing_ruleset_ok,
            compute_payment_routing_ruleset_unreducable,
            compute_payment_routing_ruleset_not_found
        ]},
        {terms, [sequence], [
            party_creation,
            contractor_creation,
            compute_pred_w_irreducible_criterion,
            compute_terms_w_criteria,
            check_all_payment_methods
        ]}
    ].

%% starting/stopping

-spec init_per_suite(config()) -> config().
init_per_suite(C) ->
    {Apps, _Ret} = pm_ct_helper:start_apps([woody, scoper, dmt_client, party_management]),
    _ = pm_domain:insert(construct_domain_fixture()),
    [{apps, Apps} | C].

-spec end_per_suite(config()) -> _.
end_per_suite(C) ->
    _ = pm_domain:cleanup(),
    [application:stop(App) || App <- cfg(apps, C)].

%% tests

-spec init_per_group(group_name(), config()) -> config().
init_per_group(shop_blocking_suspension, C) ->
    C;
init_per_group(Group, C) ->
    PartyID = list_to_binary(lists:concat([Group, ".", erlang:system_time()])),
    Context = pm_ct_helper:create_client(PartyID),
    Client = pm_client:start(PartyID, Context),
    [{party_id, PartyID}, {client, Client} | C].

-spec end_per_group(group_name(), config()) -> _.
end_per_group(_Group, C) ->
    pm_client:stop(cfg(client, C)).

-spec init_per_testcase(test_case_name(), config()) -> config().
init_per_testcase(_Name, C) ->
    C.

-spec end_per_testcase(test_case_name(), config()) -> _.
end_per_testcase(_Name, _C) ->
    ok.

%%

-define(party_w_status(ID, Blocking, Suspension), #domain_Party{
    id = ID,
    blocking = Blocking,
    suspension = Suspension
}).

-define(shop_w_status(ID, Blocking, Suspension), #domain_Shop{
    id = ID,
    blocking = Blocking,
    suspension = Suspension
}).

-define(wallet_w_status(ID, Blocking, Suspension), #domain_Wallet{
    id = ID,
    blocking = Blocking,
    suspension = Suspension
}).

-define(invalid_user(),
    {exception, #payproc_InvalidUser{}}
).

-define(invalid_request(Errors),
    {exception, #'InvalidRequest'{errors = Errors}}
).

-define(party_not_found(),
    {exception, #payproc_PartyNotFound{}}
).

-define(party_exists(),
    {exception, #payproc_PartyExists{}}
).

-define(invalid_party_revision(),
    {exception, #payproc_InvalidPartyRevision{}}
).

-define(party_blocked(Reason),
    {exception, #payproc_InvalidPartyStatus{status = {blocking, ?blocked(Reason, _)}}}
).

-define(party_unblocked(Reason),
    {exception, #payproc_InvalidPartyStatus{status = {blocking, ?unblocked(Reason, _)}}}
).

-define(party_suspended(),
    {exception, #payproc_InvalidPartyStatus{status = {suspension, ?suspended(_)}}}
).

-define(party_active(),
    {exception, #payproc_InvalidPartyStatus{status = {suspension, ?active(_)}}}
).

-define(namespace_not_found(),
    {exception, #payproc_PartyMetaNamespaceNotFound{}}
).

-define(contract_not_found(),
    {exception, #payproc_ContractNotFound{}}
).

-define(invalid_contract_status(Status),
    {exception, #payproc_InvalidContractStatus{status = Status}}
).

-define(payout_tool_not_found(),
    {exception, #payproc_PayoutToolNotFound{}}
).

-define(shop_not_found(),
    {exception, #payproc_ShopNotFound{}}
).

-define(shop_blocked(Reason),
    {exception, #payproc_InvalidShopStatus{status = {blocking, ?blocked(Reason, _)}}}
).

-define(shop_unblocked(Reason),
    {exception, #payproc_InvalidShopStatus{status = {blocking, ?unblocked(Reason, _)}}}
).

-define(shop_suspended(),
    {exception, #payproc_InvalidShopStatus{status = {suspension, ?suspended(_)}}}
).

-define(shop_active(),
    {exception, #payproc_InvalidShopStatus{status = {suspension, ?active(_)}}}
).

-define(wallet_not_found(),
    {exception, #payproc_WalletNotFound{}}
).

-define(wallet_blocked(Reason),
    {exception, #payproc_InvalidWalletStatus{status = {blocking, ?blocked(Reason, _)}}}
).

-define(wallet_unblocked(Reason),
    {exception, #payproc_InvalidWalletStatus{status = {blocking, ?unblocked(Reason, _)}}}
).

-define(wallet_suspended(),
    {exception, #payproc_InvalidWalletStatus{status = {suspension, ?suspended(_)}}}
).

-define(wallet_active(),
    {exception, #payproc_InvalidWalletStatus{status = {suspension, ?active(_)}}}
).

-define(claim(ID), #payproc_Claim{id = ID}).
-define(claim(ID, Status), #payproc_Claim{id = ID, status = Status}).
-define(claim(ID, Status, Changeset), #payproc_Claim{id = ID, status = Status, changeset = Changeset}).

-define(claim_not_found(),
    {exception, #payproc_ClaimNotFound{}}
).

-define(invalid_claim_status(Status),
    {exception, #payproc_InvalidClaimStatus{status = Status}}
).

-define(invalid_changeset(Reason),
    {exception, #payproc_InvalidChangeset{reason = Reason}}
).

-define(REAL_SHOP_ID, <<"SHOP1">>).
-define(REAL_CONTRACTOR_ID, <<"CONTRACTOR1">>).
-define(REAL_CONTRACT_ID, <<"CONTRACT1">>).
-define(REAL_WALLET_ID, <<"WALLET1">>).
-define(REAL_PAYOUT_TOOL_ID, <<"PAYOUTTOOL1">>).
-define(REAL_PARTY_PAYMENT_METHODS, [
    ?pmt(bank_card_deprecated, maestro),
    ?pmt(bank_card_deprecated, mastercard),
    ?pmt(bank_card_deprecated, visa)
]).

-define(WRONG_DMT_OBJ_ID, 99999).

-spec party_creation(config()) -> _ | no_return().
-spec party_not_found_on_retrieval(config()) -> _ | no_return().
-spec party_already_exists(config()) -> _ | no_return().
-spec party_retrieval(config()) -> _ | no_return().

-spec shop_not_found_on_retrieval(config()) -> _ | no_return().
-spec shop_creation(config()) -> _ | no_return().
-spec shop_aggregation(config()) -> _ | no_return().
-spec shop_terms_retrieval(config()) -> _ | no_return().

-spec party_get_initial_revision(config()) -> _ | no_return().
-spec party_revisioning(config()) -> _ | no_return().
-spec claim_not_found_on_retrieval(config()) -> _ | no_return().
-spec no_pending_claims(config()) -> _ | no_return().

-spec party_blocking(config()) -> _ | no_return().
-spec party_unblocking(config()) -> _ | no_return().
-spec party_already_blocked(config()) -> _ | no_return().
-spec party_already_unblocked(config()) -> _ | no_return().
-spec party_blocked_on_suspend(config()) -> _ | no_return().
-spec party_suspension(config()) -> _ | no_return().
-spec party_activation(config()) -> _ | no_return().
-spec party_already_suspended(config()) -> _ | no_return().
-spec party_already_active(config()) -> _ | no_return().
-spec party_get_status(config()) -> _ | no_return().

-spec party_meta_retrieval(config()) -> _ | no_return().
-spec party_metadata_setting(config()) -> _ | no_return().
-spec party_metadata_retrieval(config()) -> _ | no_return().
-spec party_metadata_removing(config()) -> _ | no_return().

-spec shop_blocking(config()) -> _ | no_return().
-spec shop_unblocking(config()) -> _ | no_return().
-spec shop_already_blocked(config()) -> _ | no_return().
-spec shop_already_unblocked(config()) -> _ | no_return().
-spec shop_blocked_on_suspend(config()) -> _ | no_return().
-spec shop_suspension(config()) -> _ | no_return().
-spec shop_activation(config()) -> _ | no_return().
-spec shop_already_suspended(config()) -> _ | no_return().
-spec shop_already_active(config()) -> _ | no_return().
-spec shop_account_set_retrieval(config()) -> _ | no_return().
-spec shop_account_retrieval(config()) -> _ | no_return().

-spec party_access_control(config()) -> _ | no_return().

-spec contract_not_found(config()) -> _ | no_return().
-spec contractor_creation(config()) -> _ | no_return().
-spec contract_creation(config()) -> _ | no_return().
-spec contract_terms_retrieval(config()) -> _ | no_return().
-spec compute_payment_institution_terms(config()) -> _ | no_return().
-spec compute_payout_cash_flow(config()) -> _ | no_return().
-spec contract_p2p_terms(config()) -> _ | no_return().
-spec contract_p2p_template_terms(config()) -> _ | no_return().
-spec contract_w2w_terms(config()) -> _ | no_return().

-spec compute_provider_ok(config()) -> _ | no_return().
-spec compute_provider_not_found(config()) -> _ | no_return().
-spec compute_provider_terminal_terms_ok(config()) -> _ | no_return().
-spec compute_provider_terminal_terms_not_found(config()) -> _ | no_return().
-spec compute_provider_terminal_terms_undefined_terms(config()) -> _ | no_return().
-spec compute_globals_ok(config()) -> _ | no_return().
-spec compute_payment_routing_ruleset_ok(config()) -> _ | no_return().
-spec compute_payment_routing_ruleset_unreducable(config()) -> _ | no_return().
-spec compute_payment_routing_ruleset_not_found(config()) -> _ | no_return().

-spec compute_pred_w_irreducible_criterion(config()) -> _ | no_return().
-spec compute_terms_w_criteria(config()) -> _ | no_return().

party_creation(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    ContactInfo = #domain_PartyContactInfo{email = <<?MODULE_STRING>>},
    ok = pm_client:create_party(make_party_params(ContactInfo), Client),
    [
        ?party_created(PartyID, ContactInfo, _),
        ?revision_changed(_, 0)
    ] = next_event(Client),
    Party = pm_client:get_party(Client),
    ?party_w_status(PartyID, ?unblocked(_, _), ?active(_)) = Party,
    #domain_Party{contact_info = ContactInfo, shops = Shops, contracts = Contracts} = Party,
    0 = maps:size(Shops),
    0 = maps:size(Contracts).

party_already_exists(C) ->
    ?party_exists() = pm_client:create_party(make_party_params(), cfg(client, C)).

party_not_found_on_retrieval(C) ->
    ?party_not_found() = pm_client:get_party(cfg(client, C)).

party_retrieval(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    #domain_Party{id = PartyID} = pm_client:get_party(Client).

party_get_initial_revision(C) ->
    % NOTE
    % This triggers `pm_party_machine:get_last_revision_old_way/1` codepath.
    Client = cfg(client, C),
    0 = pm_client:get_party_revision(Client).

party_revisioning(C) ->
    Client = cfg(client, C),
    % yesterday
    T0 = pm_datetime:add_interval(pm_datetime:format_now(), {undefined, undefined, -1}),
    ?invalid_party_revision() = pm_client:checkout_party({timestamp, T0}, Client),
    Party1 = pm_client:get_party(Client),
    R1 = Party1#domain_Party.revision,
    T1 = pm_datetime:format_now(),
    Party2 = party_suspension(C),
    R2 = Party2#domain_Party.revision,
    Party1 = pm_client:checkout_party({timestamp, T1}, Client),
    Party1 = pm_client:checkout_party({revision, R1}, Client),
    T2 = pm_datetime:format_now(),
    _ = party_activation(C),
    Party2 = pm_client:checkout_party({timestamp, T2}, Client),
    Party2 = pm_client:checkout_party({revision, R2}, Client),
    Party3 = pm_client:get_party(Client),
    R3 = Party3#domain_Party.revision,
    % tomorrow
    T3 = pm_datetime:add_interval(T2, {undefined, undefined, 1}),
    Party3 = pm_client:checkout_party({timestamp, T3}, Client),
    Party3 = pm_client:checkout_party({revision, R3}, Client),
    ?invalid_party_revision() = pm_client:checkout_party({revision, R3 + 1}, Client).

contract_not_found(C) ->
    ?contract_not_found() = pm_client:get_contract(<<"666">>, cfg(client, C)).

contractor_creation(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    ContractorID = ?REAL_CONTRACTOR_ID,
    ContractorParams = pm_ct_helper:make_battle_ready_contractor(),
    Modifications = [
        ?cm_contractor_creation(ContractorID, ContractorParams)
    ],
    Claim = create_claim(Modifications, PartyID),
    ok = accept_claim(Claim, Client),
    ok = commit_claim(Claim, Client),
    Party = pm_client:get_party(Client),
    #domain_PartyContractor{} = pm_party:get_contractor(ContractorID, Party).

contract_creation(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    ContractorID = ?REAL_CONTRACTOR_ID,
    ContractID = ?REAL_CONTRACT_ID,
    TemplateRef = undefined,
    PaymentInstitutionRef = ?pinst(2),
    ContractParams = #claim_management_ContractParams{
        contractor_id = ContractorID,
        template = TemplateRef,
        payment_institution = PaymentInstitutionRef
    },
    PayoutToolParams = #claim_management_PayoutToolParams{
        currency = ?cur(<<"RUB">>),
        tool_info =
            {russian_bank_account, #domain_RussianBankAccount{
                account = <<"4276300010908312893">>,
                bank_name = <<"SomeBank">>,
                bank_post_account = <<"123129876">>,
                bank_bik = <<"66642666">>
            }}
    },
    Modifications = [
        ?cm_contract_creation(ContractID, ContractParams),
        ?cm_contract_modification(ContractID, ?cm_payout_tool_creation(?REAL_PAYOUT_TOOL_ID, PayoutToolParams))
    ],
    Claim = create_claim(Modifications, PartyID),
    ok = accept_claim(Claim, Client),
    ok = commit_claim(Claim, Client),
    #domain_Contract{} = pm_client:get_contract(?REAL_CONTRACT_ID, Client).

contract_terms_retrieval(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    ContractID = ?REAL_CONTRACT_ID,
    Varset = #payproc_Varset{},
    PartyRevision = pm_client:get_party_revision(Client),
    DomainRevision1 = pm_domain:head(),
    Timstamp1 = pm_datetime:format_now(),
    TermSet1 = pm_client:compute_contract_terms(
        ContractID,
        Timstamp1,
        {revision, PartyRevision},
        DomainRevision1,
        Varset,
        Client
    ),
    #domain_TermSet{
        payments = #domain_PaymentsServiceTerms{
            payment_methods = {value, [?pmt(bank_card_deprecated, visa)]}
        }
    } = TermSet1,
    _ = pm_domain:update(construct_term_set_for_party(PartyID, undefined)),
    DomainRevision2 = pm_domain:head(),
    Timstamp2 = pm_datetime:format_now(),
    TermSet2 = pm_client:compute_contract_terms(
        ContractID,
        Timstamp2,
        {revision, PartyRevision},
        DomainRevision2,
        Varset,
        Client
    ),
    #domain_TermSet{
        payments = #domain_PaymentsServiceTerms{
            payment_methods = {value, ?REAL_PARTY_PAYMENT_METHODS}
        }
    } = TermSet2.

compute_payment_institution_terms(C) ->
    Client = cfg(client, C),
    TermsFun = fun(Type, Object) ->
        #domain_TermSet{} =
            pm_client:compute_payment_institution_terms(
                ?pinst(2),
                #payproc_Varset{payment_method = ?pmt(Type, Object)},
                Client
            )
    end,
    T1 =
        #domain_TermSet{} =
        pm_client:compute_payment_institution_terms(
            ?pinst(2),
            #payproc_Varset{},
            Client
        ),
    T2 = TermsFun(bank_card_deprecated, visa),
    T3 = TermsFun(payment_terminal_deprecated, euroset),
    T4 = TermsFun(empty_cvv_bank_card_deprecated, visa),

    ?assert_different_term_sets(T1, T2),
    ?assert_different_term_sets(T1, T3),
    ?assert_different_term_sets(T1, T4),
    ?assert_different_term_sets(T2, T3),
    ?assert_different_term_sets(T2, T4),
    ?assert_different_term_sets(T3, T4).

-spec check_all_payment_methods(config()) -> _.
check_all_payment_methods(C) ->
    Client = cfg(client, C),
    TermsFun = fun(Type, Object) ->
        #domain_TermSet{} =
            pm_client:compute_payment_institution_terms(
                ?pinst(2),
                #payproc_Varset{payment_method = ?pmt(Type, Object)},
                Client
            ),
        ok
    end,

    TermsFun(bank_card, ?bank_card(<<"visa-ref">>)),
    TermsFun(payment_terminal, ?pmt_srv(<<"alipay-ref">>)),
    TermsFun(digital_wallet, ?pmt_srv(<<"qiwi-ref">>)),
    TermsFun(mobile, ?mob(<<"mts-ref">>)),
    TermsFun(crypto_currency, ?crypta(<<"bitcoin-ref">>)),
    TermsFun(bank_card_deprecated, maestro),
    TermsFun(payment_terminal_deprecated, wechat),
    TermsFun(digital_wallet_deprecated, rbkmoney),
    TermsFun(tokenized_bank_card_deprecated, ?tkz_bank_card(visa, applepay)),
    TermsFun(empty_cvv_bank_card_deprecated, visa),
    TermsFun(crypto_currency_deprecated, litecoin),
    TermsFun(mobile_deprecated, yota).

compute_payout_cash_flow(C) ->
    Client = cfg(client, C),
    Params = #payproc_PayoutParams{
        id = ?REAL_SHOP_ID,
        amount = #domain_Cash{amount = 10000, currency = ?cur(<<"RUB">>)},
        timestamp = pm_datetime:format_now()
    },
    [
        #domain_FinalCashFlowPosting{
            source = #domain_FinalCashFlowAccount{account_type = {merchant, settlement}},
            destination = #domain_FinalCashFlowAccount{account_type = {merchant, payout}},
            volume = #domain_Cash{amount = 7500, currency = ?cur(<<"RUB">>)}
        },
        #domain_FinalCashFlowPosting{
            source = #domain_FinalCashFlowAccount{account_type = {merchant, settlement}},
            destination = #domain_FinalCashFlowAccount{account_type = {system, settlement}},
            volume = #domain_Cash{amount = 2500, currency = ?cur(<<"RUB">>)}
        }
    ] = pm_client:compute_payout_cash_flow(Params, Client).

contract_p2p_terms(C) ->
    Client = cfg(client, C),
    ContractID = ?REAL_CONTRACT_ID,
    PartyRevision = pm_client:get_party_revision(Client),
    DomainRevision1 = pm_domain:head(),
    Timstamp1 = pm_datetime:format_now(),
    BankCard = #domain_BankCard{
        token = <<"1OleNyeXogAKZBNTgxBGQE">>,
        payment_system_deprecated = visa,
        bin = <<"415039">>,
        last_digits = <<"0900">>,
        issuer_country = rus
    },
    Varset = #payproc_Varset{
        currency = ?cur(<<"RUB">>),
        amount = ?cash(2500, <<"RUB">>),
        p2p_tool = #domain_P2PTool{
            sender = {bank_card, BankCard},
            receiver = {bank_card, BankCard}
        }
    },
    #domain_TermSet{
        wallets = #domain_WalletServiceTerms{
            p2p = P2PServiceTerms
        }
    } = pm_client:compute_contract_terms(
        ContractID,
        Timstamp1,
        {revision, PartyRevision},
        DomainRevision1,
        Varset,
        Client
    ),
    #domain_P2PServiceTerms{fees = Fees} = P2PServiceTerms,
    {value, #domain_Fees{
        fees = #{surplus := {fixed, #domain_CashVolumeFixed{cash = ?cash(50, <<"RUB">>)}}}
    }} = Fees.

contract_p2p_template_terms(C) ->
    Client = cfg(client, C),
    ContractID = ?REAL_CONTRACT_ID,
    PartyRevision = pm_client:get_party_revision(Client),
    DomainRevision1 = pm_domain:head(),
    Timstamp1 = pm_datetime:format_now(),
    Varset = #payproc_Varset{
        currency = ?cur(<<"RUB">>),
        amount = ?cash(2500, <<"RUB">>)
    },
    #domain_TermSet{
        wallets = #domain_WalletServiceTerms{
            p2p = #domain_P2PServiceTerms{
                templates = TemplateTerms
            }
        }
    } = pm_client:compute_contract_terms(
        ContractID,
        Timstamp1,
        {revision, PartyRevision},
        DomainRevision1,
        Varset,
        Client
    ),
    #domain_P2PTemplateServiceTerms{allow = Allow} = TemplateTerms,
    {constant, true} = Allow.

contract_w2w_terms(C) ->
    Client = cfg(client, C),
    ContractID = ?REAL_CONTRACT_ID,
    PartyRevision = pm_client:get_party_revision(Client),
    DomainRevision1 = pm_domain:head(),
    Timstamp1 = pm_datetime:format_now(),
    Varset = #payproc_Varset{
        currency = ?cur(<<"RUB">>),
        amount = ?cash(2500, <<"RUB">>)
    },
    #domain_TermSet{
        wallets = #domain_WalletServiceTerms{
            w2w = W2WServiceTerms
        }
    } = pm_client:compute_contract_terms(
        ContractID,
        Timstamp1,
        {revision, PartyRevision},
        DomainRevision1,
        Varset,
        Client
    ),
    #domain_W2WServiceTerms{fees = Fees} = W2WServiceTerms,
    {value, #domain_Fees{
        fees = #{surplus := {fixed, #domain_CashVolumeFixed{cash = ?cash(50, <<"RUB">>)}}}
    }} = Fees.

shop_not_found_on_retrieval(C) ->
    Client = cfg(client, C),
    ?shop_not_found() = pm_client:get_shop(<<"666">>, Client).

shop_creation(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    Details = #domain_ShopDetails{
        name = <<"SOME SHOP NAME">>,
        description = <<"Very meaningfull description of the shop.">>
    },
    Category = ?cat(2),
    Location = {url, <<"https://example.com">>},
    ContractID = ?REAL_CONTRACT_ID,
    ShopID = ?REAL_SHOP_ID,
    PayoutToolID1 = ?REAL_PAYOUT_TOOL_ID,
    ShopParams = #claim_management_ShopParams{
        category = Category,
        location = Location,
        details = Details,
        contract_id = ContractID,
        payout_tool_id = PayoutToolID1
    },
    Schedule = ?bussched(1),
    ScheduleParams = #claim_management_ScheduleModification{schedule = Schedule},
    Modifications = [
        ?cm_shop_creation(ShopID, ShopParams),
        ?cm_shop_account_creation(ShopID, ?cur(<<"RUB">>)),
        ?cm_shop_modification(ShopID, {payout_schedule_modification, ScheduleParams})
    ],
    Claim = create_claim(Modifications, PartyID),
    ok = accept_claim(Claim, Client),
    ok = commit_claim(Claim, Client),
    #domain_Shop{
        id = ShopID,
        details = Details,
        location = Location,
        category = Category,
        account = #domain_ShopAccount{currency = ?cur(<<"RUB">>)},
        contract_id = ContractID,
        payout_tool_id = PayoutToolID1,
        payout_schedule = Schedule
    } = pm_client:get_shop(ShopID, Client).

shop_aggregation(C) ->
    Client = cfg(client, C),
    #payproc_ShopContract{
        shop = #domain_Shop{id = ?REAL_SHOP_ID},
        contract = #domain_Contract{id = ?REAL_CONTRACT_ID}
    } = pm_client:get_shop_contract(?REAL_SHOP_ID, Client).

shop_terms_retrieval(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    ShopID = ?REAL_SHOP_ID,
    Timestamp = pm_datetime:format_now(),
    VS = #payproc_Varset{
        shop_id = ShopID,
        party_id = PartyID,
        category = ?cat(2),
        currency = ?cur(<<"RUB">>),
        identification_level = full
    },
    TermSet1 = pm_client:compute_shop_terms(ShopID, Timestamp, {timestamp, Timestamp}, VS, Client),
    #domain_TermSet{
        payments = #domain_PaymentsServiceTerms{
            payment_methods = {value, [?pmt(bank_card_deprecated, visa)]}
        }
    } = TermSet1,
    _ = pm_domain:update(construct_term_set_for_party(PartyID, {shop_is, ShopID})),
    TermSet2 = pm_client:compute_shop_terms(ShopID, pm_datetime:format_now(), {timestamp, Timestamp}, VS, Client),
    #domain_TermSet{
        payments = #domain_PaymentsServiceTerms{
            payment_methods = {value, ?REAL_PARTY_PAYMENT_METHODS}
        }
    } = TermSet2.

claim_not_found_on_retrieval(C) ->
    Client = cfg(client, C),
    ?claim_not_found() = pm_client:get_claim(-666, Client).

no_pending_claims(C) ->
    Client = cfg(client, C),
    Claims = pm_client:get_claims(Client),
    [] = lists:filter(
        fun
            (?claim(_, ?pending())) ->
                true;
            (_) ->
                false
        end,
        Claims
    ),
    ok.

party_blocking(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    Reason = <<"i said so">>,
    ok = pm_client:block_party(Reason, Client),
    [?party_blocking(?blocked(Reason, _)), ?revision_changed(_, _)] = next_event(Client),
    ?party_w_status(PartyID, ?blocked(Reason, _), _) = pm_client:get_party(Client).

party_unblocking(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    Reason = <<"enough">>,
    ok = pm_client:unblock_party(Reason, Client),
    [?party_blocking(?unblocked(Reason, _)), ?revision_changed(_, _)] = next_event(Client),
    ?party_w_status(PartyID, ?unblocked(Reason, _), _) = pm_client:get_party(Client).

party_already_blocked(C) ->
    Client = cfg(client, C),
    ?party_blocked(_) = pm_client:block_party(<<"too much">>, Client).

party_already_unblocked(C) ->
    Client = cfg(client, C),
    ?party_unblocked(_) = pm_client:unblock_party(<<"too free">>, Client).

party_blocked_on_suspend(C) ->
    Client = cfg(client, C),
    ?party_blocked(_) = pm_client:suspend_party(Client).

party_suspension(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    ok = pm_client:suspend_party(Client),
    [?party_suspension(?suspended(_)), ?revision_changed(_, _)] = next_event(Client),
    ?party_w_status(PartyID, _, ?suspended(_)) = pm_client:get_party(Client).

party_activation(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    ok = pm_client:activate_party(Client),
    [?party_suspension(?active(_)), ?revision_changed(_, _)] = next_event(Client),
    ?party_w_status(PartyID, _, ?active(_)) = pm_client:get_party(Client).

party_already_suspended(C) ->
    Client = cfg(client, C),
    ?party_suspended() = pm_client:suspend_party(Client).

party_already_active(C) ->
    Client = cfg(client, C),
    ?party_active() = pm_client:activate_party(Client).

party_metadata_setting(C) ->
    Client = cfg(client, C),
    NS = pm_ct_helper:make_meta_ns(),
    Data = pm_ct_helper:make_meta_data(NS),
    ok = pm_client:set_party_metadata(NS, Data, Client),
    % lets check for idempotency
    ok = pm_client:set_party_metadata(NS, Data, Client).

party_metadata_retrieval(C) ->
    Client = cfg(client, C),
    ?namespace_not_found() = pm_client:get_party_metadata(<<"NoSuchNamespace">>, Client),
    NS = pm_ct_helper:make_meta_ns(),
    Data0 = pm_ct_helper:make_meta_data(),
    ok = pm_client:set_party_metadata(NS, Data0, Client),
    Data0 = pm_client:get_party_metadata(NS, Client),
    % lets change it and check again
    Data1 = pm_ct_helper:make_meta_data(NS),
    ok = pm_client:set_party_metadata(NS, Data1, Client),
    Data1 = pm_client:get_party_metadata(NS, Client).

party_metadata_removing(C) ->
    Client = cfg(client, C),
    ?namespace_not_found() = pm_client:remove_party_metadata(<<"NoSuchNamespace">>, Client),
    NS = pm_ct_helper:make_meta_ns(),
    ok = pm_client:set_party_metadata(NS, pm_ct_helper:make_meta_data(), Client),
    ok = pm_client:remove_party_metadata(NS, Client),
    ?namespace_not_found() = pm_client:remove_party_metadata(NS, Client).

party_meta_retrieval(C) ->
    Client = cfg(client, C),
    Meta0 = pm_client:get_party_meta(Client),
    NS = pm_ct_helper:make_meta_ns(),
    ok = pm_client:set_party_metadata(NS, pm_ct_helper:make_meta_data(), Client),
    Meta1 = pm_client:get_party_meta(Client),
    Meta0 =/= Meta1.

party_get_status(C) ->
    Client = cfg(client, C),
    Status0 = pm_client:get_party_status(Client),
    ?active(_) = Status0#domain_PartyStatus.suspension,
    ?unblocked(_) = Status0#domain_PartyStatus.blocking,
    ok = pm_client:block_party(<<"too much">>, Client),
    Status1 = pm_client:get_party_status(Client),
    ?active(_) = Status1#domain_PartyStatus.suspension,
    ?blocked(<<"too much">>, _) = Status1#domain_PartyStatus.blocking,
    Status1 =/= Status0.

shop_blocking(C) ->
    Client = cfg(client, C),
    ShopID = ?REAL_SHOP_ID,
    Reason = <<"i said so">>,
    ok = pm_client:block_shop(ShopID, Reason, Client),
    [?shop_blocking(ShopID, ?blocked(Reason, _)), ?revision_changed(_, _)] = next_event(Client),
    ?shop_w_status(ShopID, ?blocked(Reason, _), _) = pm_client:get_shop(ShopID, Client).

shop_unblocking(C) ->
    Client = cfg(client, C),
    ShopID = ?REAL_SHOP_ID,
    Reason = <<"enough">>,
    ok = pm_client:unblock_shop(ShopID, Reason, Client),
    [?shop_blocking(ShopID, ?unblocked(Reason, _)), ?revision_changed(_, _)] = next_event(Client),
    ?shop_w_status(ShopID, ?unblocked(Reason, _), _) = pm_client:get_shop(ShopID, Client).

shop_already_blocked(C) ->
    Client = cfg(client, C),
    ShopID = ?REAL_SHOP_ID,
    ?shop_blocked(_) = pm_client:block_shop(ShopID, <<"too much">>, Client).

shop_already_unblocked(C) ->
    Client = cfg(client, C),
    ShopID = ?REAL_SHOP_ID,
    ?shop_unblocked(_) = pm_client:unblock_shop(ShopID, <<"too free">>, Client).

shop_blocked_on_suspend(C) ->
    Client = cfg(client, C),
    ShopID = ?REAL_SHOP_ID,
    ?shop_blocked(_) = pm_client:suspend_shop(ShopID, Client).

shop_suspension(C) ->
    Client = cfg(client, C),
    ShopID = ?REAL_SHOP_ID,
    ok = pm_client:suspend_shop(ShopID, Client),
    [?shop_suspension(ShopID, ?suspended(_)), ?revision_changed(_, _)] = next_event(Client),
    ?shop_w_status(ShopID, _, ?suspended(_)) = pm_client:get_shop(ShopID, Client).

shop_activation(C) ->
    Client = cfg(client, C),
    ShopID = ?REAL_SHOP_ID,
    ok = pm_client:activate_shop(ShopID, Client),
    [?shop_suspension(ShopID, ?active(_)), ?revision_changed(_, _)] = next_event(Client),
    ?shop_w_status(ShopID, _, ?active(_)) = pm_client:get_shop(ShopID, Client).

shop_already_suspended(C) ->
    Client = cfg(client, C),
    ShopID = ?REAL_SHOP_ID,
    ?shop_suspended() = pm_client:suspend_shop(ShopID, Client).

shop_already_active(C) ->
    Client = cfg(client, C),
    ShopID = ?REAL_SHOP_ID,
    ?shop_active() = pm_client:activate_shop(ShopID, Client).

shop_account_set_retrieval(C) ->
    Client = cfg(client, C),
    ShopID = ?REAL_SHOP_ID,
    S = #domain_ShopAccount{} = pm_client:get_shop_account(ShopID, Client),
    {save_config, S}.

shop_account_retrieval(C) ->
    Client = cfg(client, C),
    {shop_account_set_retrieval, #domain_ShopAccount{guarantee = AccountID}} = ?config(saved_config, C),
    #payproc_AccountState{account_id = AccountID} = pm_client:get_account_state(AccountID, Client).

%% Access control tests

party_access_control(C) ->
    PartyID = cfg(party_id, C),
    % External Success
    GoodExternalClient = cfg(client, C),
    #domain_Party{id = PartyID} = pm_client:get_party(GoodExternalClient),

    % External Reject
    BadExternalClient0 = pm_client:start(
        #payproc_UserInfo{id = <<"FakE1D">>, type = {external_user, #payproc_ExternalUser{}}},
        PartyID,
        pm_client_api:new()
    ),
    ?invalid_user() = pm_client:get_party(BadExternalClient0),
    pm_client:stop(BadExternalClient0),

    % UserIdentity has priority
    UserIdentity = #{
        id => PartyID,
        realm => <<"internal">>
    },
    Context = woody_user_identity:put(UserIdentity, woody_context:new()),
    UserIdentityClient1 = pm_client:start(
        #payproc_UserInfo{id = <<"FakE1D">>, type = {external_user, #payproc_ExternalUser{}}},
        PartyID,
        pm_client_api:new(Context)
    ),
    #domain_Party{id = PartyID} = pm_client:get_party(UserIdentityClient1),
    pm_client:stop(UserIdentityClient1),

    % Internal Success
    GoodInternalClient = pm_client:start(
        #payproc_UserInfo{id = <<"F4KE1D">>, type = {internal_user, #payproc_InternalUser{}}},
        PartyID,
        pm_client_api:new()
    ),
    #domain_Party{id = PartyID} = pm_client:get_party(GoodInternalClient),
    pm_client:stop(GoodInternalClient),

    % Service Success
    GoodServiceClient = pm_client:start(
        #payproc_UserInfo{id = <<"fAkE1D">>, type = {service_user, #payproc_ServiceUser{}}},
        PartyID,
        pm_client_api:new()
    ),
    #domain_Party{id = PartyID} = pm_client:get_party(GoodServiceClient),
    pm_client:stop(GoodServiceClient),
    ok.

%% Compute providers

compute_provider_ok(C) ->
    Client = cfg(client, C),
    DomainRevision = pm_domain:head(),
    Varset = #payproc_Varset{
        currency = ?cur(<<"RUB">>)
    },
    CashFlow = ?cfpost(
        {system, settlement},
        {provider, settlement},
        {product,
            {min_of,
                ?ordset([
                    ?fixed(10, <<"RUB">>),
                    ?share_with_rounding_method(5, 100, operation_amount, round_half_towards_zero)
                ])}}
    ),
    #domain_Provider{
        terms = #domain_ProvisionTermSet{
            payments = #domain_PaymentsProvisionTerms{
                cash_flow = {value, [CashFlow]}
            },
            recurrent_paytools = #domain_RecurrentPaytoolsProvisionTerms{
                cash_value = {value, ?cash(1000, <<"RUB">>)}
            }
        }
    } = pm_client:compute_provider(?prv(1), DomainRevision, Varset, Client).

compute_provider_not_found(C) ->
    Client = cfg(client, C),
    DomainRevision = pm_domain:head(),
    {exception, #payproc_ProviderNotFound{}} =
        (catch pm_client:compute_provider(?prv(?WRONG_DMT_OBJ_ID), DomainRevision, #payproc_Varset{}, Client)).

compute_provider_terminal_terms_ok(C) ->
    Client = cfg(client, C),
    DomainRevision = pm_domain:head(),
    Varset = #payproc_Varset{
        currency = ?cur(<<"RUB">>)
    },
    CashFlow = ?cfpost(
        {system, settlement},
        {provider, settlement},
        {product,
            {min_of,
                ?ordset([
                    ?fixed(10, <<"RUB">>),
                    ?share_with_rounding_method(5, 100, operation_amount, round_half_towards_zero)
                ])}}
    ),
    PaymentMethods = ?ordset([?pmt(bank_card_deprecated, visa)]),
    #domain_ProvisionTermSet{
        payments = #domain_PaymentsProvisionTerms{
            cash_flow = {value, [CashFlow]},
            payment_methods = {value, PaymentMethods}
        },
        recurrent_paytools = #domain_RecurrentPaytoolsProvisionTerms{
            cash_value = {value, ?cash(1000, <<"RUB">>)}
        }
    } = pm_client:compute_provider_terminal_terms(?prv(1), ?trm(1), DomainRevision, Varset, Client).

compute_provider_terminal_terms_not_found(C) ->
    Client = cfg(client, C),
    DomainRevision = pm_domain:head(),
    {exception, #payproc_TerminalNotFound{}} =
        (catch pm_client:compute_provider_terminal_terms(
            ?prv(1),
            ?trm(?WRONG_DMT_OBJ_ID),
            DomainRevision,
            #payproc_Varset{},
            Client
        )),
    {exception, #payproc_ProviderNotFound{}} =
        (catch pm_client:compute_provider_terminal_terms(
            ?prv(?WRONG_DMT_OBJ_ID),
            ?trm(1),
            DomainRevision,
            #payproc_Varset{},
            Client
        )),
    {exception, #payproc_ProviderNotFound{}} =
        (catch pm_client:compute_provider_terminal_terms(
            ?prv(?WRONG_DMT_OBJ_ID),
            ?trm(?WRONG_DMT_OBJ_ID),
            DomainRevision,
            #payproc_Varset{},
            Client
        )).

compute_provider_terminal_terms_undefined_terms(C) ->
    Client = cfg(client, C),
    DomainRevision = pm_domain:head(),
    ?assertMatch(
        {exception, #payproc_ProvisionTermSetUndefined{}},
        pm_client:compute_provider_terminal_terms(
            ?prv(2),
            ?trm(4),
            DomainRevision,
            #payproc_Varset{},
            Client
        )
    ).

compute_globals_ok(C) ->
    Client = cfg(client, C),
    DomainRevision = pm_domain:head(),
    Varset = #payproc_Varset{},
    #domain_Globals{
        external_account_set = {value, ?eas(1)}
    } = pm_client:compute_globals(DomainRevision, Varset, Client).

compute_payment_routing_ruleset_ok(C) ->
    Client = cfg(client, C),
    DomainRevision = pm_domain:head(),
    Varset = #payproc_Varset{
        party_id = <<"67890">>
    },
    #domain_RoutingRuleset{
        name = <<"Rule#1">>,
        decisions =
            {candidates, [
                #domain_RoutingCandidate{
                    terminal = ?trm(2),
                    allowed = {constant, true}
                },
                #domain_RoutingCandidate{
                    terminal = ?trm(3),
                    allowed = {constant, true}
                },
                #domain_RoutingCandidate{
                    terminal = ?trm(1),
                    allowed = {constant, true}
                }
            ]}
    } = pm_client:compute_routing_ruleset(?ruleset(1), DomainRevision, Varset, Client).

compute_payment_routing_ruleset_unreducable(C) ->
    Client = cfg(client, C),
    DomainRevision = pm_domain:head(),
    Varset = #payproc_Varset{},
    #domain_RoutingRuleset{
        name = <<"Rule#1">>,
        decisions =
            {delegates, [
                #domain_RoutingDelegate{
                    allowed = {condition, {party, #domain_PartyCondition{id = <<"12345">>}}},
                    ruleset = ?ruleset(2)
                },
                #domain_RoutingDelegate{
                    allowed = {condition, {party, #domain_PartyCondition{id = <<"67890">>}}},
                    ruleset = ?ruleset(3)
                },
                #domain_RoutingDelegate{
                    allowed = {constant, true},
                    ruleset = ?ruleset(4)
                }
            ]}
    } = pm_client:compute_routing_ruleset(?ruleset(1), DomainRevision, Varset, Client).

compute_payment_routing_ruleset_not_found(C) ->
    Client = cfg(client, C),
    DomainRevision = pm_domain:head(),
    {exception, #payproc_RuleSetNotFound{}} =
        (catch pm_client:compute_routing_ruleset(?ruleset(5), DomainRevision, #payproc_Varset{}, Client)).

%%

compute_pred_w_irreducible_criterion(_) ->
    CritRef = ?crit(1),
    CritName = <<"HAHA GOT ME">>,
    pm_ct_domain:with(
        [
            pm_ct_fixture:construct_criterion(
                CritRef,
                CritName,
                {all_of, [
                    {constant, true},
                    {is_not, {condition, {currency_is, ?cur(<<"KZT">>)}}}
                ]}
            )
        ],
        fun(Revision) ->
            ?assertMatch(
                {criterion, #domain_Criterion{name = CritName, predicate = {all_of, [_]}}},
                pm_selector:reduce_predicate({criterion, CritRef}, #{}, Revision)
            )
        end
    ).

compute_terms_w_criteria(C) ->
    Client = cfg(client, C),
    PartyID = cfg(party_id, C),
    CritRef = ?crit(1),
    CritBase = ?crit(10),
    TemplateRef = ?tmpl(10),
    CashLimitHigh = ?cashrng(
        {inclusive, ?cash(10, <<"KZT">>)},
        {exclusive, ?cash(1000, <<"KZT">>)}
    ),
    CashLimitLow = ?cashrng(
        {inclusive, ?cash(10, <<"KZT">>)},
        {exclusive, ?cash(100, <<"KZT">>)}
    ),
    pm_ct_domain:with(
        [
            pm_ct_fixture:construct_criterion(
                CritBase,
                <<"Visas">>,
                {all_of,
                    ?ordset([
                        {condition,
                            {payment_tool,
                                {bank_card, #domain_BankCardCondition{
                                    definition =
                                        {payment_system, #domain_PaymentSystemCondition{
                                            payment_system_is_deprecated = visa
                                        }}
                                }}}},
                        {is_not,
                            {condition,
                                {payment_tool,
                                    {bank_card, #domain_BankCardCondition{
                                        definition = {empty_cvv_is, true}
                                    }}}}}
                    ])}
            ),
            pm_ct_fixture:construct_criterion(
                CritRef,
                <<"Kazakh Visas">>,
                {all_of,
                    ?ordset([
                        {condition, {currency_is, ?cur(<<"KZT">>)}},
                        {criterion, CritBase}
                    ])}
            ),
            pm_ct_fixture:construct_contract_template(
                TemplateRef,
                ?trms(10)
            ),
            pm_ct_fixture:construct_term_set_hierarchy(
                ?trms(10),
                ?trms(2),
                #domain_TermSet{
                    payments = #domain_PaymentsServiceTerms{
                        cash_limit =
                            {decisions, [
                                #domain_CashLimitDecision{
                                    if_ = {criterion, CritRef},
                                    then_ = {value, CashLimitHigh}
                                },
                                #domain_CashLimitDecision{
                                    if_ = {is_not, {criterion, CritRef}},
                                    then_ = {value, CashLimitLow}
                                }
                            ]}
                    }
                }
            )
        ],
        fun(Revision) ->
            ContractID = pm_utils:unique_id(),
            ok = create_contract(PartyID, ContractID, ?REAL_CONTRACTOR_ID, TemplateRef, ?pinst(1), Client),
            PartyRevision = pm_client:get_party_revision(Client),
            Timstamp = pm_datetime:format_now(),
            ?assertMatch(
                #domain_TermSet{
                    payments = #domain_PaymentsServiceTerms{cash_limit = {value, CashLimitHigh}}
                },
                pm_client:compute_contract_terms(
                    ContractID,
                    Timstamp,
                    {revision, PartyRevision},
                    Revision,
                    #payproc_Varset{
                        currency = ?cur(<<"KZT">>),
                        payment_method = ?pmt(bank_card_deprecated, visa)
                    },
                    Client
                )
            ),
            ?assertMatch(
                #domain_TermSet{
                    payments = #domain_PaymentsServiceTerms{cash_limit = {value, CashLimitLow}}
                },
                pm_client:compute_contract_terms(
                    ContractID,
                    Timstamp,
                    {revision, PartyRevision},
                    Revision,
                    #payproc_Varset{
                        currency = ?cur(<<"KZT">>),
                        payment_method = ?pmt(empty_cvv_bank_card_deprecated, visa)
                    },
                    Client
                )
            ),
            ?assertMatch(
                #domain_TermSet{
                    payments = #domain_PaymentsServiceTerms{cash_limit = {value, CashLimitLow}}
                },
                pm_client:compute_contract_terms(
                    ContractID,
                    Timstamp,
                    {revision, PartyRevision},
                    Revision,
                    #payproc_Varset{
                        currency = ?cur(<<"RUB">>),
                        payment_method = ?pmt(bank_card_deprecated, visa)
                    },
                    Client
                )
            )
        end
    ).

create_contract(PartyID, ContractID, ContractorID, TemplateRef, PaymentInstitutionRef, Client) ->
    ContractParams = #claim_management_ContractParams{
        contractor_id = ContractorID,
        template = TemplateRef,
        payment_institution = PaymentInstitutionRef
    },
    Modifications = [
        ?cm_contract_creation(ContractID, ContractParams)
    ],
    Claim = create_claim(Modifications, PartyID),
    ok = accept_claim(Claim, Client),
    ok = commit_claim(Claim, Client),
    ok.

%%

create_claim(Modifications, PartyID) ->
    pm_ct_helper:create_claim(Modifications, PartyID).

accept_claim(Claim, Client) ->
    ok = pm_ct_helper:accept_claim(Claim, Client),
    [] = next_event(Client),
    ok.

commit_claim(Claim, Client) ->
    ok = pm_ct_helper:commit_claim(Claim, Client),
    [
        ?claim_created(?claim(ClaimID)),
        ?claim_status_changed(ClaimID, ?accepted(_), _, _),
        ?revision_changed(_, _)
    ] = next_event(Client),
    ok.

%%

next_event(Client) ->
    case pm_client:pull_event(Client) of
        ?party_ev(Event) ->
            Event;
        Result ->
            Result
    end.

%%

make_party_params() ->
    make_party_params(#domain_PartyContactInfo{email = <<?MODULE_STRING>>}).

make_party_params(ContactInfo) ->
    #payproc_PartyParams{contact_info = ContactInfo}.

construct_term_set_for_party(PartyID, Def) ->
    TermSet = #domain_TermSet{
        payments = #domain_PaymentsServiceTerms{
            currencies =
                {value,
                    ordsets:from_list([
                        ?cur(<<"RUB">>),
                        ?cur(<<"USD">>)
                    ])},
            categories =
                {value,
                    ordsets:from_list([
                        ?cat(2),
                        ?cat(3)
                    ])},
            payment_methods =
                {decisions, [
                    #domain_PaymentMethodDecision{
                        if_ = ?partycond(PartyID, Def),
                        then_ = {value, ordsets:from_list(?REAL_PARTY_PAYMENT_METHODS)}
                    },
                    #domain_PaymentMethodDecision{
                        if_ = {constant, true},
                        then_ =
                            {value,
                                ordsets:from_list([
                                    ?pmt(bank_card_deprecated, visa)
                                ])}
                    }
                ]}
        }
    },
    {term_set_hierarchy, #domain_TermSetHierarchyObject{
        ref = ?trms(2),
        data = #domain_TermSetHierarchy{
            parent_terms = undefined,
            term_sets = [
                #domain_TimedTermSet{
                    action_time = #'TimestampInterval'{},
                    terms = TermSet
                }
            ]
        }
    }}.

-spec construct_domain_fixture() -> [pm_domain:object()].
construct_domain_fixture() ->
    TestTermSet = #domain_TermSet{
        payments = #domain_PaymentsServiceTerms{
            currencies = {value, ordsets:from_list([?cur(<<"RUB">>)])},
            categories = {value, ordsets:from_list([?cat(1)])}
        }
    },
    DefaultTermSet = #domain_TermSet{
        payments = #domain_PaymentsServiceTerms{
            currencies =
                {value,
                    ordsets:from_list([
                        ?cur(<<"RUB">>),
                        ?cur(<<"USD">>)
                    ])},
            categories =
                {value,
                    ordsets:from_list([
                        ?cat(2),
                        ?cat(3)
                    ])},
            payment_methods =
                {value,
                    ordsets:from_list([
                        ?pmt(bank_card_deprecated, visa)
                    ])}
        }
    },

    PayoutMDFun = fun(PaymentTool, PayoutMethods) ->
        #domain_PayoutMethodDecision{
            if_ = {condition, {payment_tool, PaymentTool}},
            then_ = {value, ordsets:from_list(PayoutMethods)}
        }
    end,

    TermSet = #domain_TermSet{
        payments = #domain_PaymentsServiceTerms{
            cash_limit =
                {value, #domain_CashRange{
                    lower = {inclusive, #domain_Cash{amount = 1000, currency = ?cur(<<"RUB">>)}},
                    upper = {exclusive, #domain_Cash{amount = 4200000, currency = ?cur(<<"RUB">>)}}
                }},
            fees =
                {value, [
                    ?cfpost(
                        {merchant, settlement},
                        {system, settlement},
                        ?share(45, 1000, operation_amount)
                    )
                ]}
        },
        payouts = #domain_PayoutsServiceTerms{
            payout_methods =
                {decisions, [
                    #domain_PayoutMethodDecision{
                        if_ =
                            {condition,
                                {payment_tool,
                                    {bank_card, #domain_BankCardCondition{
                                        definition = {issuer_bank_is, ?bank(1)}
                                    }}}},
                        then_ =
                            {value, ordsets:from_list([?pomt(russian_bank_account), ?pomt(international_bank_account)])}
                    },
                    #domain_PayoutMethodDecision{
                        if_ =
                            {condition,
                                {payment_tool,
                                    {bank_card, #domain_BankCardCondition{
                                        definition = {empty_cvv_is, true}
                                    }}}},
                        then_ = {value, ordsets:from_list([])}
                    },

                    PayoutMDFun(
                        {bank_card, #domain_BankCardCondition{definition = {issuer_bank_is, ?bank(1)}}},
                        [?pomt(russian_bank_account), ?pomt(international_bank_account)]
                    ),
                    PayoutMDFun(
                        {bank_card, #domain_BankCardCondition{definition = {empty_cvv_is, true}}},
                        []
                    ),

                    %% For check_all_payment_methods
                    PayoutMDFun(
                        {bank_card, #domain_BankCardCondition{
                            definition = {
                                payment_system,
                                #domain_PaymentSystemCondition{
                                    payment_system_is = ?pmt_sys(<<"visa-ref">>)
                                }
                            }
                        }},
                        [?pomt(russian_bank_account)]
                    ),
                    PayoutMDFun(
                        {payment_terminal, #domain_PaymentTerminalCondition{
                            definition = {
                                payment_service_is,
                                ?pmt_srv(<<"alipay-ref">>)
                            }
                        }},
                        []
                    ),
                    PayoutMDFun(
                        {digital_wallet, #domain_DigitalWalletCondition{
                            definition =
                                {payment_service_is, ?pmt_srv(<<"qiwi-ref">>)}
                        }},
                        []
                    ),
                    PayoutMDFun(
                        {mobile_commerce, #domain_MobileCommerceCondition{
                            definition = {operator_is, ?mob(<<"mts-ref">>)}
                        }},
                        []
                    ),
                    PayoutMDFun(
                        {crypto_currency, #domain_CryptoCurrencyCondition{
                            definition = {crypto_currency_is, ?crypta(<<"bitcoin-ref">>)}
                        }},
                        []
                    ),
                    PayoutMDFun(
                        {bank_card, #domain_BankCardCondition{definition = {payment_system_is, maestro}}},
                        []
                    ),
                    PayoutMDFun(
                        {payment_terminal, #domain_PaymentTerminalCondition{
                            definition = {provider_is_deprecated, wechat}
                        }},
                        []
                    ),
                    PayoutMDFun(
                        {bank_card, #domain_BankCardCondition{
                            definition =
                                {payment_system, #domain_PaymentSystemCondition{
                                    token_provider_is_deprecated = applepay
                                }}
                        }},
                        []
                    ),
                    PayoutMDFun(
                        {crypto_currency, #domain_CryptoCurrencyCondition{
                            definition = {crypto_currency_is_deprecated, litecoin}
                        }},
                        []
                    ),
                    PayoutMDFun(
                        {mobile_commerce, #domain_MobileCommerceCondition{definition = {operator_is_deprecated, yota}}},
                        []
                    ),
                    #domain_PayoutMethodDecision{
                        if_ = {condition, {payment_tool, {bank_card, #domain_BankCardCondition{}}}},
                        then_ = {value, ordsets:from_list([?pomt(russian_bank_account)])}
                    },
                    #domain_PayoutMethodDecision{
                        if_ = {condition, {payment_tool, {payment_terminal, #domain_PaymentTerminalCondition{}}}},
                        then_ = {value, ordsets:from_list([?pomt(international_bank_account)])}
                    },
                    #domain_PayoutMethodDecision{
                        if_ = {constant, true},
                        then_ = {value, ordsets:from_list([])}
                    }
                ]},
            fees =
                {value, [
                    ?cfpost(
                        {merchant, settlement},
                        {merchant, payout},
                        ?share(750, 1000, operation_amount)
                    ),
                    ?cfpost(
                        {merchant, settlement},
                        {system, settlement},
                        ?share(250, 1000, operation_amount)
                    )
                ]}
        },
        wallets = #domain_WalletServiceTerms{
            currencies = {value, ordsets:from_list([?cur(<<"RUB">>)])},
            wallet_limit =
                {decisions, [
                    #domain_CashLimitDecision{
                        if_ = {condition, {currency_is, ?cur(<<"RUB">>)}},
                        then_ =
                            {value,
                                ?cashrng(
                                    {inclusive, ?cash(0, <<"RUB">>)},
                                    {exclusive, ?cash(5000001, <<"RUB">>)}
                                )}
                    },
                    #domain_CashLimitDecision{
                        if_ = {condition, {currency_is, ?cur(<<"USD">>)}},
                        then_ =
                            {value,
                                ?cashrng(
                                    {inclusive, ?cash(0, <<"USD">>)},
                                    {exclusive, ?cash(10000001, <<"USD">>)}
                                )}
                    }
                ]},
            p2p = #domain_P2PServiceTerms{
                currencies = {value, ?ordset([?cur(<<"RUB">>)])},
                cash_limit =
                    {decisions, [
                        #domain_CashLimitDecision{
                            if_ = {condition, {currency_is, ?cur(<<"RUB">>)}},
                            then_ =
                                {value,
                                    ?cashrng(
                                        {inclusive, ?cash(0, <<"RUB">>)},
                                        {exclusive, ?cash(10000001, <<"RUB">>)}
                                    )}
                        }
                    ]},
                cash_flow =
                    {decisions, [
                        #domain_CashFlowDecision{
                            if_ =
                                {condition,
                                    {cost_in,
                                        ?cashrng(
                                            {inclusive, ?cash(0, <<"RUB">>)},
                                            {exclusive, ?cash(3000, <<"RUB">>)}
                                        )}},
                            then_ = {
                                value,
                                [
                                    #domain_CashFlowPosting{
                                        source = {wallet, receiver_destination},
                                        destination = {system, settlement},
                                        volume = ?fixed(50, <<"RUB">>)
                                    }
                                ]
                            }
                        },
                        #domain_CashFlowDecision{
                            if_ =
                                {condition,
                                    {cost_in,
                                        ?cashrng(
                                            {inclusive, ?cash(3001, <<"RUB">>)},
                                            {exclusive, ?cash(10000, <<"RUB">>)}
                                        )}},
                            then_ = {
                                value,
                                [
                                    #domain_CashFlowPosting{
                                        source = {wallet, receiver_destination},
                                        destination = {system, settlement},
                                        volume = ?share(1, 100, operation_amount)
                                    }
                                ]
                            }
                        }
                    ]},
                fees =
                    {decisions, [
                        #domain_FeeDecision{
                            if_ =
                                {condition,
                                    {p2p_tool, #domain_P2PToolCondition{
                                        sender_is =
                                            {bank_card, #domain_BankCardCondition{
                                                definition =
                                                    {payment_system, #domain_PaymentSystemCondition{
                                                        payment_system_is_deprecated = visa
                                                    }}
                                            }},
                                        receiver_is =
                                            {bank_card, #domain_BankCardCondition{
                                                definition =
                                                    {payment_system, #domain_PaymentSystemCondition{
                                                        payment_system_is_deprecated = visa
                                                    }}
                                            }}
                                    }}},
                            then_ =
                                {decisions, [
                                    #domain_FeeDecision{
                                        if_ =
                                            {condition,
                                                {cost_in,
                                                    ?cashrng(
                                                        {inclusive, ?cash(0, <<"RUB">>)},
                                                        {exclusive, ?cash(3000, <<"RUB">>)}
                                                    )}},
                                        then_ = {value, #domain_Fees{fees = #{surplus => ?fixed(50, <<"RUB">>)}}}
                                    },
                                    #domain_FeeDecision{
                                        if_ =
                                            {condition,
                                                {cost_in,
                                                    ?cashrng(
                                                        {inclusive, ?cash(3000, <<"RUB">>)},
                                                        {exclusive, ?cash(300000, <<"RUB">>)}
                                                    )}},
                                        then_ =
                                            {value, #domain_Fees{fees = #{surplus => ?share(4, 100, operation_amount)}}}
                                    }
                                ]}
                        }
                    ]},
                templates = #domain_P2PTemplateServiceTerms{
                    allow = {constant, true}
                }
            },
            w2w = #domain_W2WServiceTerms{
                currencies = {value, ?ordset([?cur(<<"RUB">>)])},
                cash_limit =
                    {decisions, [
                        #domain_CashLimitDecision{
                            if_ = {condition, {currency_is, ?cur(<<"RUB">>)}},
                            then_ =
                                {value,
                                    ?cashrng(
                                        {inclusive, ?cash(0, <<"RUB">>)},
                                        {exclusive, ?cash(10000001, <<"RUB">>)}
                                    )}
                        }
                    ]},
                cash_flow =
                    {decisions, [
                        #domain_CashFlowDecision{
                            if_ =
                                {condition,
                                    {cost_in,
                                        ?cashrng(
                                            {inclusive, ?cash(0, <<"RUB">>)},
                                            {exclusive, ?cash(3000, <<"RUB">>)}
                                        )}},
                            then_ = {
                                value,
                                [
                                    #domain_CashFlowPosting{
                                        source = {wallet, receiver_destination},
                                        destination = {system, settlement},
                                        volume = ?fixed(50, <<"RUB">>)
                                    }
                                ]
                            }
                        },
                        #domain_CashFlowDecision{
                            if_ =
                                {condition,
                                    {cost_in,
                                        ?cashrng(
                                            {inclusive, ?cash(3001, <<"RUB">>)},
                                            {exclusive, ?cash(10000, <<"RUB">>)}
                                        )}},
                            then_ = {
                                value,
                                [
                                    #domain_CashFlowPosting{
                                        source = {wallet, receiver_destination},
                                        destination = {system, settlement},
                                        volume = ?share(1, 100, operation_amount)
                                    }
                                ]
                            }
                        }
                    ]},
                fees =
                    {decisions, [
                        #domain_FeeDecision{
                            if_ = {condition, {currency_is, ?cur(<<"RUB">>)}},
                            then_ =
                                {decisions, [
                                    #domain_FeeDecision{
                                        if_ =
                                            {condition,
                                                {cost_in,
                                                    ?cashrng(
                                                        {inclusive, ?cash(0, <<"RUB">>)},
                                                        {exclusive, ?cash(3000, <<"RUB">>)}
                                                    )}},
                                        then_ = {value, #domain_Fees{fees = #{surplus => ?fixed(50, <<"RUB">>)}}}
                                    },
                                    #domain_FeeDecision{
                                        if_ =
                                            {condition,
                                                {cost_in,
                                                    ?cashrng(
                                                        {inclusive, ?cash(3000, <<"RUB">>)},
                                                        {exclusive, ?cash(300000, <<"RUB">>)}
                                                    )}},
                                        then_ =
                                            {value, #domain_Fees{fees = #{surplus => ?share(4, 100, operation_amount)}}}
                                    }
                                ]}
                        }
                    ]}
            }
        }
    },
    Decision1 =
        {delegates, [
            #domain_RoutingDelegate{
                allowed = {condition, {party, #domain_PartyCondition{id = <<"12345">>}}},
                ruleset = ?ruleset(2)
            },
            #domain_RoutingDelegate{
                allowed = {condition, {party, #domain_PartyCondition{id = <<"67890">>}}},
                ruleset = ?ruleset(3)
            },
            #domain_RoutingDelegate{
                allowed = {constant, true},
                ruleset = ?ruleset(4)
            }
        ]},
    Decision2 =
        {candidates, [
            #domain_RoutingCandidate{
                allowed = {constant, true},
                terminal = ?trm(1)
            }
        ]},
    Decision3 =
        {candidates, [
            #domain_RoutingCandidate{
                allowed = {condition, {party, #domain_PartyCondition{id = <<"67890">>}}},
                terminal = ?trm(2)
            },
            #domain_RoutingCandidate{
                allowed = {constant, true},
                terminal = ?trm(3)
            },
            #domain_RoutingCandidate{
                allowed = {constant, true},
                terminal = ?trm(1)
            }
        ]},
    Decision4 =
        {candidates, [
            #domain_RoutingCandidate{
                allowed = {constant, true},
                terminal = ?trm(3)
            }
        ]},
    [
        pm_ct_fixture:construct_currency(?cur(<<"RUB">>)),
        pm_ct_fixture:construct_currency(?cur(<<"USD">>)),
        pm_ct_fixture:construct_currency(?cur(<<"KZT">>)),

        pm_ct_fixture:construct_category(?cat(1), <<"Test category">>, test),
        pm_ct_fixture:construct_category(?cat(2), <<"Generic Store">>, live),
        pm_ct_fixture:construct_category(?cat(3), <<"Guns & Booze">>, live),
        pm_ct_fixture:construct_category(?cat(4), <<"Tech Store">>, live),
        pm_ct_fixture:construct_category(?cat(5), <<"Burger Boutique">>, live),

        pm_ct_fixture:construct_payment_system(?pmt_sys(<<"visa-ref">>), <<"Visa">>),
        pm_ct_fixture:construct_payment_service(?pmt_srv(<<"alipay-ref">>), <<"Euroset">>),
        pm_ct_fixture:construct_payment_service(?pmt_srv(<<"qiwi-ref">>), <<"Qiwi">>),
        pm_ct_fixture:construct_mobile_operator(?mob(<<"mts-ref">>), <<"MTS">>),
        pm_ct_fixture:construct_crypto_currency(?crypta(<<"bitcoin-ref">>), <<"Bitcoin">>),
        pm_ct_fixture:construct_tokenized_service(?token_srv(<<"applepay-ref">>), <<"Apple Pay">>),

        pm_ct_fixture:construct_payment_method(?pmt(bank_card, ?bank_card(<<"visa-ref">>))),
        pm_ct_fixture:construct_payment_method(?pmt(bank_card, ?bank_card(<<"mastercard-ref">>))),
        pm_ct_fixture:construct_payment_method(?pmt(bank_card, ?bank_card(<<"jcb-ref">>))),
        pm_ct_fixture:construct_payment_method(?pmt(bank_card, ?token_bank_card(<<"visa-ref">>, <<"applepay-ref">>))),
        pm_ct_fixture:construct_payment_method(?pmt(payment_terminal, ?pmt_srv(<<"alipay-ref">>))),
        pm_ct_fixture:construct_payment_method(?pmt(digital_wallet, ?pmt_srv(<<"qiwi-ref">>))),
        pm_ct_fixture:construct_payment_method(?pmt(mobile, ?mob(<<"mts-ref">>))),
        pm_ct_fixture:construct_payment_method(?pmt(crypto_currency, ?crypta(<<"bitcoin-ref">>))),

        pm_ct_fixture:construct_payment_method(?pmt(bank_card_deprecated, visa)),
        pm_ct_fixture:construct_payment_method(?pmt(bank_card_deprecated, mastercard)),
        pm_ct_fixture:construct_payment_method(?pmt(bank_card_deprecated, maestro)),
        pm_ct_fixture:construct_payment_method(?pmt(payment_terminal_deprecated, euroset)),
        pm_ct_fixture:construct_payment_method(?pmt(payment_terminal_deprecated, wechat)),
        pm_ct_fixture:construct_payment_method(?pmt(digital_wallet_deprecated, rbkmoney)),
        pm_ct_fixture:construct_payment_method(?pmt(tokenized_bank_card_deprecated, ?tkz_bank_card(visa, applepay))),
        pm_ct_fixture:construct_payment_method(?pmt(empty_cvv_bank_card_deprecated, visa)),
        pm_ct_fixture:construct_payment_method(?pmt(crypto_currency_deprecated, litecoin)),
        pm_ct_fixture:construct_payment_method(?pmt(mobile_deprecated, yota)),

        pm_ct_fixture:construct_payout_method(?pomt(russian_bank_account)),
        pm_ct_fixture:construct_payout_method(?pomt(international_bank_account)),

        pm_ct_fixture:construct_proxy(?prx(1), <<"Dummy proxy">>),
        pm_ct_fixture:construct_inspector(?insp(1), <<"Dummy Inspector">>, ?prx(1)),
        pm_ct_fixture:construct_system_account_set(?sas(1)),
        pm_ct_fixture:construct_system_account_set(?sas(2)),
        pm_ct_fixture:construct_external_account_set(?eas(1)),

        pm_ct_fixture:construct_business_schedule(?bussched(1)),

        pm_ct_fixture:construct_payment_routing_ruleset(?ruleset(1), <<"Rule#1">>, Decision1),
        pm_ct_fixture:construct_payment_routing_ruleset(?ruleset(2), <<"Rule#2">>, Decision2),
        pm_ct_fixture:construct_payment_routing_ruleset(?ruleset(3), <<"Rule#3">>, Decision3),
        pm_ct_fixture:construct_payment_routing_ruleset(?ruleset(4), <<"Rule#4">>, Decision4),

        {payment_institution, #domain_PaymentInstitutionObject{
            ref = ?pinst(1),
            data = #domain_PaymentInstitution{
                name = <<"Test Inc.">>,
                system_account_set = {value, ?sas(1)},
                default_contract_template = {value, ?tmpl(1)},
                providers = {value, ?ordset([])},
                inspector = {value, ?insp(1)},
                residences = [],
                realm = test
            }
        }},

        {payment_institution, #domain_PaymentInstitutionObject{
            ref = ?pinst(2),
            data = #domain_PaymentInstitution{
                name = <<"Chetky Payments Inc.">>,
                system_account_set = {value, ?sas(2)},
                default_contract_template = {value, ?tmpl(2)},
                providers = {value, ?ordset([])},
                inspector = {value, ?insp(1)},
                residences = [],
                realm = live
            }
        }},

        {payment_institution, #domain_PaymentInstitutionObject{
            ref = ?pinst(3),
            data = #domain_PaymentInstitution{
                name = <<"Chetky Payments Inc.">>,
                system_account_set = {value, ?sas(2)},
                default_contract_template = {value, ?tmpl(2)},
                providers = {value, ?ordset([])},
                inspector = {value, ?insp(1)},
                residences = [],
                realm = live
            }
        }},

        {globals, #domain_GlobalsObject{
            ref = #domain_GlobalsRef{},
            data = #domain_Globals{
                external_account_set =
                    {decisions, [
                        #domain_ExternalAccountSetDecision{
                            if_ = {constant, true},
                            then_ = {value, ?eas(1)}
                        }
                    ]},
                payment_institutions = ?ordset([?pinst(1), ?pinst(2)])
            }
        }},
        pm_ct_fixture:construct_contract_template(
            ?tmpl(1),
            ?trms(1)
        ),
        pm_ct_fixture:construct_contract_template(
            ?tmpl(2),
            ?trms(3)
        ),
        pm_ct_fixture:construct_contract_template(
            ?tmpl(3),
            ?trms(2),
            {interval, #domain_LifetimeInterval{years = -1}},
            {interval, #domain_LifetimeInterval{days = -1}}
        ),
        pm_ct_fixture:construct_contract_template(
            ?tmpl(4),
            ?trms(1),
            undefined,
            {interval, #domain_LifetimeInterval{months = 1}}
        ),
        pm_ct_fixture:construct_contract_template(
            ?tmpl(5),
            ?trms(4)
        ),
        pm_ct_fixture:construct_term_set_hierarchy(?trms(1), undefined, TestTermSet),
        pm_ct_fixture:construct_term_set_hierarchy(?trms(2), undefined, DefaultTermSet),
        pm_ct_fixture:construct_term_set_hierarchy(?trms(3), ?trms(2), TermSet),
        pm_ct_fixture:construct_term_set_hierarchy(
            ?trms(4),
            ?trms(3),
            #domain_TermSet{
                payments = #domain_PaymentsServiceTerms{
                    currencies =
                        {value,
                            ordsets:from_list([
                                ?cur(<<"RUB">>)
                            ])},
                    categories =
                        {value,
                            ordsets:from_list([
                                ?cat(2)
                            ])},
                    payment_methods =
                        {value,
                            ordsets:from_list([
                                ?pmt(bank_card_deprecated, visa)
                            ])}
                }
            }
        ),
        {bank, #domain_BankObject{
            ref = ?bank(1),
            data = #domain_Bank{
                name = <<"Test BIN range">>,
                description = <<"Test BIN range">>,
                bins = ordsets:from_list([<<"1234">>, <<"5678">>])
            }
        }},

        {provider, #domain_ProviderObject{
            ref = ?prv(1),
            data = #domain_Provider{
                name = <<"Brovider">>,
                description = <<"A provider but bro">>,
                terminal = {value, [?prvtrm(1)]},
                proxy = #domain_Proxy{ref = ?prx(1), additional = #{}},
                abs_account = <<"1234567890">>,
                accounts = pm_ct_fixture:construct_provider_account_set([?cur(<<"RUB">>)]),
                terms = #domain_ProvisionTermSet{
                    payments = #domain_PaymentsProvisionTerms{
                        currencies = {value, ?ordset([?cur(<<"RUB">>)])},
                        categories = {value, ?ordset([?cat(1)])},
                        payment_methods =
                            {value,
                                ?ordset([
                                    ?pmt(bank_card_deprecated, visa),
                                    ?pmt(bank_card_deprecated, mastercard)
                                ])},
                        cash_limit =
                            {value,
                                ?cashrng(
                                    {inclusive, ?cash(1000, <<"RUB">>)},
                                    {exclusive, ?cash(1000000000, <<"RUB">>)}
                                )},
                        cash_flow =
                            {decisions, [
                                #domain_CashFlowDecision{
                                    if_ = {condition, {currency_is, ?cur(<<"RUB">>)}},
                                    then_ =
                                        {value, [
                                            ?cfpost(
                                                {system, settlement},
                                                {provider, settlement},
                                                {product,
                                                    {min_of,
                                                        ?ordset([
                                                            ?fixed(10, <<"RUB">>),
                                                            ?share_with_rounding_method(
                                                                5,
                                                                100,
                                                                operation_amount,
                                                                round_half_towards_zero
                                                            )
                                                        ])}}
                                            )
                                        ]}
                                },
                                #domain_CashFlowDecision{
                                    if_ = {condition, {currency_is, ?cur(<<"USD">>)}},
                                    then_ =
                                        {value, [
                                            ?cfpost(
                                                {system, settlement},
                                                {provider, settlement},
                                                {product,
                                                    {min_of,
                                                        ?ordset([
                                                            ?fixed(10, <<"USD">>),
                                                            ?share_with_rounding_method(
                                                                5,
                                                                100,
                                                                operation_amount,
                                                                round_half_towards_zero
                                                            )
                                                        ])}}
                                            )
                                        ]}
                                }
                            ]}
                    },
                    recurrent_paytools = #domain_RecurrentPaytoolsProvisionTerms{
                        categories = {value, ?ordset([?cat(1)])},
                        payment_methods =
                            {value,
                                ?ordset([
                                    ?pmt(bank_card_deprecated, visa),
                                    ?pmt(bank_card_deprecated, mastercard)
                                ])},
                        cash_value =
                            {decisions, [
                                #domain_CashValueDecision{
                                    if_ = {condition, {currency_is, ?cur(<<"RUB">>)}},
                                    then_ = {value, ?cash(1000, <<"RUB">>)}
                                },
                                #domain_CashValueDecision{
                                    if_ = {condition, {currency_is, ?cur(<<"USD">>)}},
                                    then_ = {value, ?cash(1000, <<"USD">>)}
                                }
                            ]}
                    }
                }
            }
        }},

        {provider, #domain_ProviderObject{
            ref = ?prv(2),
            data = #domain_Provider{
                name = <<"Provider 2">>,
                description = <<"Provider without terms">>,
                terminal = {value, [?prvtrm(4)]},
                proxy = #domain_Proxy{ref = ?prx(1), additional = #{}},
                abs_account = <<"1234567890">>,
                accounts = pm_ct_fixture:construct_provider_account_set([?cur(<<"RUB">>)])
            }
        }},

        {terminal, #domain_TerminalObject{
            ref = ?trm(1),
            data = #domain_Terminal{
                name = <<"Brominal 1">>,
                description = <<"Brominal 1">>,
                terms = #domain_ProvisionTermSet{
                    payments = #domain_PaymentsProvisionTerms{
                        payment_methods =
                            {value,
                                ?ordset([
                                    ?pmt(bank_card_deprecated, visa)
                                ])}
                    }
                }
            }
        }},
        {terminal, #domain_TerminalObject{
            ref = ?trm(2),
            data = #domain_Terminal{
                name = <<"Brominal 2">>,
                description = <<"Brominal 2">>,
                terms = #domain_ProvisionTermSet{
                    payments = #domain_PaymentsProvisionTerms{
                        payment_methods =
                            {value,
                                ?ordset([
                                    ?pmt(bank_card_deprecated, visa)
                                ])}
                    }
                }
            }
        }},
        {terminal, #domain_TerminalObject{
            ref = ?trm(3),
            data = #domain_Terminal{
                name = <<"Brominal 3">>,
                description = <<"Brominal 3">>,
                terms = #domain_ProvisionTermSet{
                    payments = #domain_PaymentsProvisionTerms{
                        payment_methods =
                            {value,
                                ?ordset([
                                    ?pmt(bank_card_deprecated, visa)
                                ])}
                    }
                }
            }
        }},
        {terminal, #domain_TerminalObject{
            ref = ?trm(4),
            data = #domain_Terminal{
                name = <<"Terminal 4">>,
                description = <<"Terminal without terms">>
            }
        }}
    ].
