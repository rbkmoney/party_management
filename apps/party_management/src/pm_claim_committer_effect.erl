-module(pm_claim_committer_effect).

-include("claim_management.hrl").
-include("party_events.hrl").

-include_lib("damsel/include/dmsl_claim_management_thrift.hrl").
-include_lib("damsel/include/dmsl_payment_processing_thrift.hrl").

-export([make/3]).
-export([make_safe/3]).
-export([apply_claim_effect/3]).
-export([apply_effects/3]).
-export([squash_effects/1]).
-export([make_modifications_effects/3]).
-export([make_modifications_safe_effects/3]).

-export_type([effect/0]).

%% Interface

-type modification() :: pm_claim_committer:modification().
-type modifications() :: pm_claim_committer:modifications().
-type effect() :: dmsl_payment_processing_thrift:'ClaimEffect'().
-type timestamp() :: pm_datetime:timestamp().
-type revision() :: pm_domain:revision().
-type party() :: pm_party:party().
-type effects() :: dmsl_payment_processing_thrift:'ClaimEffects'().

-spec make(modification(), timestamp(), revision()) -> effect() | no_return().
make(?cm_contractor_modification(ID, Modification), Timestamp, Revision) ->
    ?contractor_effect(ID, make_contractor_effect(ID, Modification, Timestamp, Revision));
make(?cm_contract_modification(ID, Modification), Timestamp, Revision) ->
    try
        ?contract_effect(ID, make_contract_effect(ID, Modification, Timestamp, Revision))
    catch
        throw:{payment_institution_invalid, Ref} ->
            raise_invalid_object_ref({contract, ID}, make_optional_domain_ref(payment_institution, Ref));
        throw:{template_invalid, Ref} ->
            raise_invalid_object_ref({contract, ID}, make_optional_domain_ref(contract_template, Ref))
    end;
make(?cm_shop_modification(ID, Modification), Timestamp, Revision) ->
    ?shop_effect(ID, make_shop_effect(ID, Modification, Timestamp, Revision));
make(?cm_wallet_modification(ID, Modification), Timestamp, _Revision) ->
    ?wallet_effect(ID, make_wallet_effect(ID, Modification, Timestamp)).

%% NOTE Заглушка для пропуска фазы создания счетов для магазинов и кошельков на этапе проверки (Accept)
%% TODO Придумать имя получше/отрефакторить
-spec make_safe(modification(), timestamp(), revision()) -> effect() | no_return().
make_safe(?cm_shop_account_creation(ID, Currency), _Timestamp, _Revision) ->
    ?shop_effect(
        ID,
        {account_created, #domain_ShopAccount{
            currency = Currency,
            settlement = 0,
            guarantee = 0,
            payout = 0
        }}
    );
make_safe(?cm_wallet_account_creation(ID, Currency), _, _) ->
    ?wallet_effect(
        ID,
        {account_created, #domain_WalletAccount{
            currency = Currency,
            settlement = 0,
            payout = 0
        }}
    );
make_safe(Change, Timestamp, Revision) ->
    make(Change, Timestamp, Revision).

%% Implementation

make_contractor_effect(ID, {creation, Contractor}, _, _) ->
    {created, pm_party_contractor:create(ID, Contractor)};
make_contractor_effect(_, {identification_level_modification, Level}, _, _) ->
    {identification_level_changed, Level}.

make_contract_effect(ID, {creation, ContractParams}, Timestamp, Revision) ->
    {created, pm_contract:create(ID, ContractParams, Timestamp, Revision)};
make_contract_effect(_, ?cm_contract_termination(_), Timestamp, _) ->
    {status_changed, {terminated, #domain_ContractTerminated{terminated_at = Timestamp}}};
make_contract_effect(_, ?cm_adjustment_creation(AdjustmentID, Params), Timestamp, Revision) ->
    {adjustment_created, pm_contract:create_adjustment(AdjustmentID, Params, Timestamp, Revision)};
make_contract_effect(_, ?cm_payout_tool_creation(PayoutToolID, Params), Timestamp, _) ->
    {payout_tool_created, pm_payout_tool:create(PayoutToolID, Params, Timestamp)};
make_contract_effect(_, ?cm_payout_tool_info_modification(PayoutToolID, Info), _, _) ->
    {payout_tool_info_changed, #payproc_PayoutToolInfoChanged{
        payout_tool_id = PayoutToolID,
        info = Info
    }};
make_contract_effect(_, {legal_agreement_binding, LegalAgreement}, _, _) ->
    {legal_agreement_bound, LegalAgreement};
make_contract_effect(ID, {report_preferences_modification, ReportPreferences}, _, Revision) ->
    _ = assert_report_schedule_valid(ID, ReportPreferences, Revision),
    {report_preferences_changed, ReportPreferences};
make_contract_effect(_, {contractor_modification, ContractorID}, _, _) ->
    {contractor_changed, ContractorID}.

make_shop_effect(ID, {creation, ShopParams}, Timestamp, _) ->
    {created, pm_party:create_shop(ID, ShopParams, Timestamp)};
make_shop_effect(_, {category_modification, Category}, _, _) ->
    {category_changed, Category};
make_shop_effect(_, {details_modification, Details}, _, _) ->
    {details_changed, Details};
make_shop_effect(_, ?cm_shop_contract_modification(ContractID, PayoutToolID), _, _) ->
    {contract_changed, #payproc_ShopContractChanged{
        contract_id = ContractID,
        payout_tool_id = PayoutToolID
    }};
make_shop_effect(_, {payout_tool_modification, PayoutToolID}, _, _) ->
    {payout_tool_changed, PayoutToolID};
make_shop_effect(_, {location_modification, Location}, _, _) ->
    {location_changed, Location};
make_shop_effect(_, {shop_account_creation, Params}, _, _) ->
    {account_created, create_shop_account(Params)};
make_shop_effect(ID, ?cm_payout_schedule_modification(PayoutScheduleRef), _, Revision) ->
    _ = assert_payout_schedule_valid(ID, PayoutScheduleRef, Revision),
    ?payout_schedule_changed(PayoutScheduleRef).

make_wallet_effect(ID, {creation, Params}, Timestamp) ->
    {created, pm_wallet:create(ID, Params, Timestamp)};
make_wallet_effect(_, {account_creation, Params}, _) ->
    {account_created, pm_wallet:create_account(Params)}.

assert_report_schedule_valid(_, #domain_ReportPreferences{service_acceptance_act_preferences = undefined}, _) ->
    ok;
assert_report_schedule_valid(
    ID,
    #domain_ReportPreferences{
        service_acceptance_act_preferences = #domain_ServiceAcceptanceActPreferences{
            schedule = BusinessScheduleRef
        }
    },
    Revision
) ->
    assert_valid_object_ref({contract, ID}, {business_schedule, BusinessScheduleRef}, Revision).

assert_payout_schedule_valid(ID, #domain_BusinessScheduleRef{} = BusinessScheduleRef, Revision) ->
    assert_valid_object_ref({shop, ID}, {business_schedule, BusinessScheduleRef}, Revision);
assert_payout_schedule_valid(_, undefined, _) ->
    ok.

assert_valid_object_ref(Prefix, Ref, Revision) ->
    case pm_domain:exists(Revision, Ref) of
        true ->
            ok;
        false ->
            raise_invalid_object_ref(Prefix, Ref)
    end.

-spec raise_invalid_object_ref(
    {shop, dmsl_domain_thrift:'ShopID'()} | {contract, dmsl_domain_thrift:'ContractID'()},
    pm_domain:ref()
) -> no_return().
raise_invalid_object_ref(Prefix, Ref) ->
    Ex = {invalid_object_reference, #claim_management_InvalidObjectReference{ref = Ref}},
    raise_invalid_object_ref_(Prefix, Ex).

-spec raise_invalid_object_ref_(term(), term()) -> no_return().
raise_invalid_object_ref_({shop, ID}, Ex) ->
    pm_claim_committer:raise_invalid_changeset(?cm_invalid_shop(ID, Ex), []);
raise_invalid_object_ref_({contract, ID}, Ex) ->
    pm_claim_committer:raise_invalid_changeset(?cm_invalid_contract(ID, Ex), []).

create_shop_account(#claim_management_ShopAccountParams{currency = Currency}) ->
    create_shop_account(Currency);
create_shop_account(#domain_CurrencyRef{symbolic_code = SymbolicCode} = CurrencyRef) ->
    GuaranteeID = pm_accounting:create_account(SymbolicCode),
    SettlementID = pm_accounting:create_account(SymbolicCode),
    PayoutID = pm_accounting:create_account(SymbolicCode),
    #domain_ShopAccount{
        currency = CurrencyRef,
        settlement = SettlementID,
        guarantee = GuaranteeID,
        payout = PayoutID
    }.

make_optional_domain_ref(_, undefined) ->
    undefined;
make_optional_domain_ref(Type, Ref) ->
    {Type, Ref}.

-spec apply_claim_effect(effect(), timestamp(), party()) -> party().
apply_claim_effect(?contractor_effect(ID, Effect), _, Party) ->
    apply_contractor_effect(ID, Effect, Party);
apply_claim_effect(?contract_effect(ID, Effect), Timestamp, Party) ->
    apply_contract_effect(ID, Effect, Timestamp, Party);
apply_claim_effect(?shop_effect(ID, Effect), _, Party) ->
    apply_shop_effect(ID, Effect, Party);
apply_claim_effect(?wallet_effect(ID, Effect), _, Party) ->
    apply_wallet_effect(ID, Effect, Party).

apply_contractor_effect(_, {created, PartyContractor}, Party) ->
    pm_party:set_contractor(PartyContractor, Party);
apply_contractor_effect(ID, Effect, Party) ->
    PartyContractor = pm_party:get_contractor(ID, Party),
    pm_party:set_contractor(update_contractor(Effect, PartyContractor), Party).

update_contractor({identification_level_changed, Level}, PartyContractor) ->
    PartyContractor#domain_PartyContractor{status = Level};
update_contractor(
    {identity_documents_changed, #payproc_ContractorIdentityDocumentsChanged{
        identity_documents = Docs
    }},
    PartyContractor
) ->
    PartyContractor#domain_PartyContractor{identity_documents = Docs}.

apply_contract_effect(_, {created, Contract}, Timestamp, Party) ->
    pm_party:set_new_contract(Contract, Timestamp, Party);
apply_contract_effect(ID, Effect, _, Party) ->
    Contract = pm_party:get_contract(ID, Party),
    pm_party:set_contract(update_contract(Effect, Contract), Party).

update_contract({status_changed, Status}, Contract) ->
    Contract#domain_Contract{status = Status};
update_contract({adjustment_created, Adjustment}, Contract) ->
    Adjustments = Contract#domain_Contract.adjustments ++ [Adjustment],
    Contract#domain_Contract{adjustments = Adjustments};
update_contract({payout_tool_created, PayoutTool}, Contract) ->
    PayoutTools = Contract#domain_Contract.payout_tools ++ [PayoutTool],
    Contract#domain_Contract{payout_tools = PayoutTools};
update_contract(
    {payout_tool_info_changed, #payproc_PayoutToolInfoChanged{payout_tool_id = PayoutToolID, info = Info}},
    Contract
) ->
    PayoutTool = pm_contract:get_payout_tool(PayoutToolID, Contract),
    pm_contract:set_payout_tool(PayoutTool#domain_PayoutTool{payout_tool_info = Info}, Contract);
update_contract({legal_agreement_bound, LegalAgreement}, Contract) ->
    Contract#domain_Contract{legal_agreement = LegalAgreement};
update_contract({report_preferences_changed, ReportPreferences}, Contract) ->
    Contract#domain_Contract{report_preferences = ReportPreferences};
update_contract({contractor_changed, ContractorID}, Contract) ->
    Contract#domain_Contract{contractor_id = ContractorID}.

apply_shop_effect(_, {created, Shop}, Party) ->
    pm_party:set_shop(Shop, Party);
apply_shop_effect(ID, Effect, Party) ->
    Shop = pm_party:get_shop(ID, Party),
    pm_party:set_shop(update_shop(Effect, Shop), Party).

update_shop({category_changed, Category}, Shop) ->
    Shop#domain_Shop{category = Category};
update_shop({details_changed, Details}, Shop) ->
    Shop#domain_Shop{details = Details};
update_shop(
    {contract_changed, #payproc_ShopContractChanged{contract_id = ContractID, payout_tool_id = PayoutToolID}},
    Shop
) ->
    Shop#domain_Shop{contract_id = ContractID, payout_tool_id = PayoutToolID};
update_shop({payout_tool_changed, PayoutToolID}, Shop) ->
    Shop#domain_Shop{payout_tool_id = PayoutToolID};
update_shop({location_changed, Location}, Shop) ->
    Shop#domain_Shop{location = Location};
update_shop({proxy_changed, _}, Shop) ->
    % deprecated
    Shop;
update_shop(?payout_schedule_changed(BusinessScheduleRef), Shop) ->
    Shop#domain_Shop{payout_schedule = BusinessScheduleRef};
update_shop({account_created, Account}, Shop) ->
    Shop#domain_Shop{account = Account}.

apply_wallet_effect(_, {created, Wallet}, Party) ->
    pm_party:set_wallet(Wallet, Party);
apply_wallet_effect(ID, Effect, Party) ->
    Wallet = pm_party:get_wallet(ID, Party),
    pm_party:set_wallet(update_wallet(Effect, Wallet), Party).

update_wallet({account_created, Account}, Wallet) ->
    Wallet#domain_Wallet{account = Account}.

-spec squash_effects([effect()]) -> [effect()].
squash_effects(Effects) ->
    squash_effects(Effects, []).

squash_effects([?contract_effect(_, _) = Effect | Others], Squashed) ->
    squash_effects(Others, squash_contract_effect(Effect, Squashed));
squash_effects([?shop_effect(_, _) = Effect | Others], Squashed) ->
    squash_effects(Others, squash_shop_effect(Effect, Squashed));
squash_effects([Effect | Others], Squashed) ->
    squash_effects(Others, Squashed ++ [Effect]);
squash_effects([], Squashed) ->
    Squashed.

squash_contract_effect(?contract_effect(_, {created, _}) = Effect, Squashed) ->
    Squashed ++ [Effect];
squash_contract_effect(?contract_effect(ContractID, Mod) = Effect, Squashed) ->
    % Try to find contract creation in squashed effects
    {ReversedEffects, AppliedFlag} = lists:foldl(
        fun
            (?contract_effect(ID, {created, Contract}), {Acc, false}) when ID =:= ContractID ->
                % Contract creation found, lets update it with this claim effect
                {[?contract_effect(ID, {created, update_contract(Mod, Contract)}) | Acc], true};
            (?contract_effect(ID, {created, _}), {_, true}) when ID =:= ContractID ->
                % One more created contract with same id - error.
                pm_claim_committer:raise_invalid_changeset(?cm_invalid_contract_already_exists(ID), []);
            (E, {Acc, Flag}) ->
                {[E | Acc], Flag}
        end,
        {[], false},
        Squashed
    ),
    case AppliedFlag of
        true ->
            lists:reverse(ReversedEffects);
        false ->
            % Contract creation not found, so this contract created earlier and we should just
            % add this claim effect to the end of squashed effects
            lists:reverse([Effect | ReversedEffects])
    end.

squash_shop_effect(?shop_effect(_, {created, _}) = Effect, Squashed) ->
    Squashed ++ [Effect];
squash_shop_effect(?shop_effect(ShopID, Mod) = Effect, Squashed) ->
    % Try to find shop creation in squashed effects
    {ReversedEffects, AppliedFlag} = lists:foldl(
        fun
            (?shop_effect(ID, {created, Shop}), {Acc, false}) when ID =:= ShopID ->
                % Shop creation found, lets update it with this claim effect
                {[?shop_effect(ID, {created, update_shop(Mod, Shop)}) | Acc], true};
            (?shop_effect(ID, {created, _}), {_, true}) when ID =:= ShopID ->
                % One more shop with same id - error.
                pm_claim_committer:raise_invalid_changeset(?cm_invalid_shop_already_exists(ID), []);
            (E, {Acc, Flag}) ->
                {[E | Acc], Flag}
        end,
        {[], false},
        Squashed
    ),
    case AppliedFlag of
        true ->
            lists:reverse(ReversedEffects);
        false ->
            % Shop creation not found, so this shop created earlier and we shuold just
            % add this claim effect to the end of squashed effects
            lists:reverse([Effect | ReversedEffects])
    end.

-spec apply_effects([effect()], timestamp(), party()) -> party().
apply_effects(Effects, Timestamp, Party) ->
    lists:foldl(
        fun(Effect, AccParty) ->
            apply_claim_effect(Effect, Timestamp, AccParty)
        end,
        Party,
        Effects
    ).

-spec make_modifications_effects(modifications(), timestamp(), revision()) -> effects().
make_modifications_effects(Modifications, Timestamp, Revision) ->
    make_effects(Modifications, Timestamp, Revision, fun make/3).

-spec make_modifications_safe_effects(modifications(), timestamp(), revision()) -> effects().
make_modifications_safe_effects(Modifications, Timestamp, Revision) ->
    make_effects(Modifications, Timestamp, Revision, fun make_safe/3).

make_effects(Modifications, Timestamp, Revision, Fun) ->
    squash_effects(
        lists:filtermap(
            fun
                (?cm_shop_cash_register_modification_unit(_, _)) ->
                    false;
                (Change) ->
                    {true, Fun(Change, Timestamp, Revision)}
            end,
            Modifications
        )
    ).
