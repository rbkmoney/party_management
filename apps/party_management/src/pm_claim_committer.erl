-module(pm_claim_committer).

-include_lib("damsel/include/dmsl_payment_processing_thrift.hrl").
-include_lib("damsel/include/dmsl_claim_management_thrift.hrl").

-include("claim_management.hrl").
-include("party_events.hrl").

-export([from_claim_mgmt/1]).
-export([assert_cash_register_modifications_applicable/2]).
-export([assert_applicable/4]).
-export([assert_changeset_applicable/4]).
-export([assert_acceptable/4]).

-type party() :: pm_party:party().
-type changeset() :: dmsl_claim_management_thrift:'ClaimChangeset'().
-type claim() :: dmsl_payment_processing_thrift:'Claim'().
-type timestamp() :: pm_datetime:timestamp().
-type revision() :: pm_domain:revision().

-spec from_claim_mgmt(dmsl_claim_management_thrift:'Claim'()) -> dmsl_payment_processing_thrift:'Claim'() | undefined.
from_claim_mgmt(#claim_management_Claim{
    id = ID,
    changeset = Changeset,
    revision = Revision,
    created_at = CreatedAt,
    updated_at = UpdatedAt
}) ->
    case from_cm_changeset(Changeset) of
        [] ->
            undefined;
        Converted ->
            #payproc_Claim{
                id = ID,
                status = ?pending(),
                changeset = Converted,
                revision = Revision,
                created_at = CreatedAt,
                updated_at = UpdatedAt
            }
    end.

-spec assert_cash_register_modifications_applicable(changeset(), party()) -> ok | no_return().
assert_cash_register_modifications_applicable(Changeset, Party) ->
    MappedChanges = get_cash_register_modifications_map(Changeset),
    CashRegisterShopIDs = sets:from_list(maps:keys(MappedChanges)),
    ShopIDs = get_all_valid_shop_ids(Changeset, Party),
    case sets:is_subset(CashRegisterShopIDs, ShopIDs) of
        true ->
            ok;
        false ->
            ShopID = hd(sets:to_list(sets:subtract(CashRegisterShopIDs, ShopIDs))),
            InvalidChangeset = maps:get(ShopID, MappedChanges),
            throw(?cm_invalid_party_changeset(?cm_invalid_shop_not_exists(ShopID), [InvalidChangeset]))
    end.

%%% Internal functions

from_cm_changeset(Changeset) ->
    lists:filtermap(
        fun
            (
                #claim_management_ModificationUnit{
                    modification = {party_modification, PartyMod}
                }
            ) ->
                case PartyMod of
                    ?cm_cash_register_modification_unit_modification(_, _) ->
                        false;
                    PartyMod ->
                        {true, from_cm_party_mod(PartyMod)}
                end;
            (
                #claim_management_ModificationUnit{
                    modification = {claim_modification, _}
                }
            ) ->
                false
        end,
        Changeset
    ).

from_cm_party_mod(?cm_contractor_modification(ContractorID, ContractorModification)) ->
    ?contractor_modification(ContractorID, ContractorModification);
from_cm_party_mod(?cm_contract_modification(ContractID, ContractModification)) ->
    ?contract_modification(
        ContractID,
        from_cm_contract_modification(ContractModification)
    );
from_cm_party_mod(?cm_shop_modification(ShopID, ShopModification)) ->
    ?shop_modification(
        ShopID,
        from_cm_shop_modification(ShopModification)
    ).

from_cm_contract_modification(
    {creation, #claim_management_ContractParams{
        contractor_id = ContractorID,
        template = ContractTemplateRef,
        payment_institution = PaymentInstitutionRef
    }}
) ->
    {creation, #payproc_ContractParams{
        contractor_id = ContractorID,
        template = ContractTemplateRef,
        payment_institution = PaymentInstitutionRef
    }};
from_cm_contract_modification(?cm_contract_termination(Reason)) ->
    ?contract_termination(Reason);
from_cm_contract_modification(?cm_adjustment_creation(ContractAdjustmentID, ContractTemplateRef)) ->
    ?adjustment_creation(
        ContractAdjustmentID,
        #payproc_ContractAdjustmentParams{template = ContractTemplateRef}
    );
from_cm_contract_modification(
    ?cm_payout_tool_creation(PayoutToolID, #claim_management_PayoutToolParams{
        currency = CurrencyRef,
        tool_info = PayoutToolInfo
    })
) ->
    ?payout_tool_creation(PayoutToolID, #payproc_PayoutToolParams{
        currency = CurrencyRef,
        tool_info = PayoutToolInfo
    });
from_cm_contract_modification(
    ?cm_payout_tool_info_modification(PayoutToolID, PayoutToolModification)
) ->
    ?payout_tool_info_modification(PayoutToolID, PayoutToolModification);
from_cm_contract_modification({legal_agreement_binding, _LegalAgreement} = LegalAgreementBinding) ->
    LegalAgreementBinding;
from_cm_contract_modification({report_preferences_modification, _ReportPreferences} = ReportPreferencesModification) ->
    ReportPreferencesModification;
from_cm_contract_modification({contractor_modification, _ContractorID} = ContractorModification) ->
    ContractorModification.

from_cm_shop_modification({creation, ShopParams}) ->
    #claim_management_ShopParams{
        category = CategoryRef,
        location = ShopLocation,
        details = ShopDetails,
        contract_id = ContractID,
        payout_tool_id = PayoutToolID
    } = ShopParams,
    {creation, #payproc_ShopParams{
        category = CategoryRef,
        location = ShopLocation,
        details = ShopDetails,
        contract_id = ContractID,
        payout_tool_id = PayoutToolID
    }};
from_cm_shop_modification({category_modification, _CategoryRef} = CategoryModification) ->
    CategoryModification;
from_cm_shop_modification({details_modification, _ShopDetails} = DetailsModification) ->
    DetailsModification;
from_cm_shop_modification(?cm_shop_contract_modification(ContractID, PayoutToolID)) ->
    ?shop_contract_modification(ContractID, PayoutToolID);
from_cm_shop_modification({payout_tool_modification, _PayoutToolID} = PayoutToolModification) ->
    PayoutToolModification;
from_cm_shop_modification({location_modification, _ShopLocation} = LocationModification) ->
    LocationModification;
from_cm_shop_modification(?cm_shop_account_creation_params(CurrencyRef)) ->
    ?shop_account_creation_params(CurrencyRef);
from_cm_shop_modification(?cm_payout_schedule_modification(BusinessScheduleRef)) ->
    ?payout_schedule_modification(BusinessScheduleRef).

get_all_valid_shop_ids(Changeset, Party) ->
    ShopModificationsShopIDs = get_shop_modifications_shop_ids(Changeset),
    PartyShopIDs = get_party_shop_ids(Party),
    sets:union(ShopModificationsShopIDs, PartyShopIDs).

get_party_shop_ids(Party) ->
    sets:from_list(maps:keys(pm_party:get_shops(Party))).

get_cash_register_modifications_map(Changeset) ->
    lists:foldl(
        fun
            (
                #claim_management_ModificationUnit{
                    modification = C = {party_modification, ?cm_cash_register_modification_unit_modification(ShopID, _)}
                },
                Acc
            ) ->
                Acc#{ShopID => C};
            (_, Acc) ->
                Acc
        end,
        #{},
        Changeset
    ).

get_shop_modifications_shop_ids(Changeset) ->
    sets:from_list(
        lists:filtermap(
            fun
                (
                    #claim_management_ModificationUnit{
                        modification = {party_modification, ?cm_cash_register_modification_unit_modification(_, _)}
                    }
                ) ->
                    false;
                (
                    #claim_management_ModificationUnit{
                        modification = {party_modification, ?cm_shop_modification(ShopID, _)}
                    }
                ) ->
                    {true, ShopID};
                (_) ->
                    false
            end,
            Changeset
        )
    ).

-spec assert_applicable(claim(), timestamp(), revision(), party()) -> ok | no_return().
assert_applicable(Claim, Timestamp, Revision, Party) ->
    assert_changeset_applicable(get_changeset(Claim), Timestamp, Revision, Party).

get_changeset(#payproc_Claim{changeset = Changeset}) ->
    Changeset.

-spec assert_changeset_applicable(changeset(), timestamp(), revision(), party()) -> ok | no_return().
assert_changeset_applicable([Change | Others], Timestamp, Revision, Party) ->
    case Change of
        ?cm_contract_modification(ID, Modification) ->
            Contract = pm_party:get_contract(ID, Party),
            ok = assert_contract_change_applicable(ID, Modification, Contract);
        ?cm_shop_modification(ID, Modification) ->
            Shop = pm_party:get_shop(ID, Party),
            ok = assert_shop_change_applicable(ID, Modification, Shop, Party, Revision);
        ?cm_contractor_modification(ID, Modification) ->
            Contractor = pm_party:get_contractor(ID, Party),
            ok = assert_contractor_change_applicable(ID, Modification, Contractor);
        ?cm_wallet_modification(ID, Modification) ->
            Wallet = pm_party:get_wallet(ID, Party),
            ok = assert_wallet_change_applicable(ID, Modification, Wallet)
    end,
    Effect = pm_claim_effect:make_safe(Change, Timestamp, Revision),
    assert_changeset_applicable(Others, Timestamp, Revision, apply_claim_effect(Effect, Timestamp, Party));
assert_changeset_applicable([], _, _, _) ->
    ok.

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

assert_contract_change_applicable(_, {creation, _}, undefined) ->
    ok;
assert_contract_change_applicable(ID, {creation, _}, #domain_Contract{}) ->
    raise_invalid_changeset(?cm_invalid_contract(ID, {already_exists, ID}));
assert_contract_change_applicable(ID, _AnyModification, undefined) ->
    raise_invalid_changeset(?cm_invalid_contract(ID, {not_exists, ID}));
assert_contract_change_applicable(ID, ?cm_contract_termination(_), Contract) ->
    case pm_contract:is_active(Contract) of
        true ->
            ok;
        false ->
            raise_invalid_changeset(?cm_invalid_contract(ID, {invalid_status, Contract#domain_Contract.status}))
    end;
assert_contract_change_applicable(ID, ?cm_adjustment_creation(AdjustmentID, _), Contract) ->
    case pm_contract:get_adjustment(AdjustmentID, Contract) of
        undefined ->
            ok;
        _ ->
            raise_invalid_changeset(?cm_invalid_contract(ID, {contract_adjustment_already_exists, AdjustmentID}))
    end;
assert_contract_change_applicable(ID, ?cm_payout_tool_creation(PayoutToolID, _), Contract) ->
    case pm_contract:get_payout_tool(PayoutToolID, Contract) of
        undefined ->
            ok;
        _ ->
            raise_invalid_changeset(?cm_invalid_contract(ID, {payout_tool_already_exists, PayoutToolID}))
    end;
assert_contract_change_applicable(ID, ?cm_payout_tool_info_modification(PayoutToolID, _), Contract) ->
    case pm_contract:get_payout_tool(PayoutToolID, Contract) of
        undefined ->
            raise_invalid_changeset(?cm_invalid_contract(ID, {payout_tool_not_exists, PayoutToolID}));
        _ ->
            ok
    end;
assert_contract_change_applicable(_, _, _) ->
    ok.

assert_shop_change_applicable(_, {creation, _}, undefined, _, _) ->
    ok;
assert_shop_change_applicable(ID, _AnyModification, undefined, _, _) ->
    raise_invalid_changeset(?invalid_shop(ID, {not_exists, ID}));
assert_shop_change_applicable(ID, {creation, _}, #domain_Shop{}, _, _) ->
    raise_invalid_changeset(?invalid_shop(ID, {already_exists, ID}));
assert_shop_change_applicable(
    _ID,
    {shop_account_creation, _},
    #domain_Shop{account = Account},
    _Party,
    _Revision
) when Account /= undefined ->
    throw(#'InvalidRequest'{errors = [<<"Can't change shop's account">>]});
assert_shop_change_applicable(
    _ID,
    {contract_modification, #payproc_ShopContractModification{contract_id = NewContractID}},
    #domain_Shop{contract_id = OldContractID},
    Party,
    Revision
) ->
    OldContract = pm_party:get_contract(OldContractID, Party),
    case pm_party:get_contract(NewContractID, Party) of
        #domain_Contract{} = NewContract ->
            assert_payment_institution_realm_equals(OldContract, NewContract, Revision);
        undefined ->
            raise_invalid_changeset(?invalid_contract(NewContractID, {not_exists, NewContractID}))
    end;
assert_shop_change_applicable(_, _, _, _, _) ->
    ok.

assert_contractor_change_applicable(_, {creation, _}, undefined) ->
    ok;
assert_contractor_change_applicable(ID, _AnyModification, undefined) ->
    raise_invalid_changeset(?invalid_contractor(ID, {not_exists, ID}));
assert_contractor_change_applicable(ID, {creation, _}, #domain_PartyContractor{}) ->
    raise_invalid_changeset(?invalid_contractor(ID, {already_exists, ID}));
assert_contractor_change_applicable(_, _, _) ->
    ok.

assert_wallet_change_applicable(_, {creation, _}, undefined) ->
    ok;
assert_wallet_change_applicable(ID, _AnyModification, undefined) ->
    raise_invalid_changeset(?invalid_wallet(ID, {not_exists, ID}));
assert_wallet_change_applicable(ID, {creation, _}, #domain_Wallet{}) ->
    raise_invalid_changeset(?invalid_wallet(ID, {already_exists, ID}));
assert_wallet_change_applicable(
    _ID,
    {account_creation, _},
    #domain_Wallet{account = Account}
) when Account /= undefined ->
    throw(#'InvalidRequest'{errors = [<<"Can't change wallet's account">>]});
assert_wallet_change_applicable(_, _, _) ->
    ok.

assert_payment_institution_realm_equals(
    #domain_Contract{id = OldContractID, payment_institution = OldRef},
    #domain_Contract{id = NewContractID, payment_institution = NewRef},
    Revision
) ->
    OldRealm = get_payment_institution_realm(OldRef, Revision, OldContractID),
    case get_payment_institution_realm(NewRef, Revision, NewContractID) of
        OldRealm ->
            ok;
        _NewRealm ->
            raise_invalid_payment_institution(NewContractID, NewRef)
    end.

get_payment_institution_realm(Ref, Revision, ContractID) ->
    case pm_domain:find(Revision, {payment_institution, Ref}) of
        #domain_PaymentInstitution{} = P ->
            pm_payment_institution:get_realm(P);
        notfound ->
            raise_invalid_payment_institution(ContractID, Ref)
    end.

-spec raise_invalid_payment_institution(
    dmsl_domain_thrift:'ContractID'(),
    dmsl_domain_thrift:'PaymentInstitutionRef'() | undefined
) -> no_return().
raise_invalid_payment_institution(ContractID, Ref) ->
    raise_invalid_changeset(
        ?invalid_contract(
            ContractID,
            {invalid_object_reference, #payproc_InvalidObjectReference{
                ref = make_optional_domain_ref(payment_institution, Ref)
            }}
        )
    ).

-spec raise_invalid_changeset(dmsl_payment_processing_thrift:'InvalidChangesetReason'()) -> no_return().
raise_invalid_changeset(Reason) ->
    throw(#payproc_InvalidChangeset{reason = Reason}).

-spec assert_acceptable(claim(), timestamp(), revision(), party()) -> ok | no_return().
assert_acceptable(Claim, Timestamp, Revision, Party0) ->
    Changeset = get_changeset(Claim),
    Effects = make_changeset_safe_effects(Changeset, Timestamp, Revision),
    Party = apply_effects(Effects, Timestamp, Party0),
    pm_party:assert_party_objects_valid(Timestamp, Revision, Party).

make_changeset_safe_effects(Changeset, Timestamp, Revision) ->
    squash_effects(
        lists:map(
            fun(Change) ->
                pm_claim_effect:make_safe(Change, Timestamp, Revision)
            end,
            Changeset
        )
    ).

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
                raise_invalid_changeset(?invalid_contract(ID, {already_exists, ID}));
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
            % Contract creation not found, so this contract created earlier and we shuold just
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
                raise_invalid_changeset(?invalid_shop(ID, {already_exists, ID}));
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

apply_effects(Effects, Timestamp, Party) ->
    lists:foldl(
        fun(Effect, AccParty) ->
            apply_claim_effect(Effect, Timestamp, AccParty)
        end,
        Party,
        Effects
    ).

make_optional_domain_ref(_, undefined) ->
    undefined;
make_optional_domain_ref(Type, Ref) ->
    {Type, Ref}.
