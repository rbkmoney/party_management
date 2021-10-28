-module(pm_claim_committer).

-include_lib("damsel/include/dmsl_payment_processing_thrift.hrl").
-include_lib("damsel/include/dmsl_claim_management_thrift.hrl").

-include("claim_management.hrl").
-include("party_events.hrl").

-export([filter_party_modifications/1]).
-export([assert_cash_register_modifications_applicable/2]).
-export([assert_modifications_applicable/4]).
-export([assert_modifications_acceptable/4]).
-export([raise_invalid_changeset/2]).

-type party() :: pm_party:party().
-type changeset() :: dmsl_claim_management_thrift:'ClaimChangeset'().
-type timestamp() :: pm_datetime:timestamp().
-type revision() :: pm_domain:revision().
-type modification() :: dmsl_claim_management_thrift:'PartyModification'().
-type modifications() :: [modification()].
-type shop_id() :: dmsl_domain_thrift:'ShopID'().
-type wallet_id() :: dmsl_domain_thrift:'WalletID'().
-type contract_id() :: dmsl_domain_thrift:'ContractID'().

-export_type([modification/0]).
-export_type([modifications/0]).

-spec filter_party_modifications(changeset()) -> modifications().
filter_party_modifications(Changeset) ->
    lists:filtermap(
        fun
            (?cm_party_modification(_, _, Change, _)) ->
                {true, Change};
            (?cm_modification_unit(_, _, _, _)) ->
                false
        end,
        Changeset
    ).

-spec assert_cash_register_modifications_applicable(modifications(), party()) -> ok | no_return().
assert_cash_register_modifications_applicable(Modifications, Party) ->
    MappedChanges = get_cash_register_modifications_map(Modifications),
    CashRegisterShopIDs = sets:from_list(maps:keys(MappedChanges)),
    ShopIDs = get_all_valid_shop_ids(Modifications, Party),
    case sets:is_subset(CashRegisterShopIDs, ShopIDs) of
        true ->
            ok;
        false ->
            ShopID = hd(sets:to_list(sets:subtract(CashRegisterShopIDs, ShopIDs))),
            InvalidChangeset = maps:get(ShopID, MappedChanges),
            raise_invalid_changeset(?cm_invalid_shop_not_exists(ShopID), [InvalidChangeset])
    end.

%%% Internal functions

get_all_valid_shop_ids(Changeset, Party) ->
    ShopModificationsShopIDs = get_shop_modifications_shop_ids(Changeset),
    PartyShopIDs = get_party_shop_ids(Party),
    sets:union(ShopModificationsShopIDs, PartyShopIDs).

get_party_shop_ids(Party) ->
    sets:from_list(maps:keys(pm_party:get_shops(Party))).

get_cash_register_modifications_map(Modifications) ->
    lists:foldl(
        fun
            (C = ?cm_shop_cash_register_modification_unit(ShopID, _), Acc) ->
                Acc#{ShopID => C};
            (_, Acc) ->
                Acc
        end,
        #{},
        Modifications
    ).

get_shop_modifications_shop_ids(Changeset) ->
    sets:from_list(
        lists:filtermap(
            fun
                (?cm_party_modification(_, _, ?cm_shop_cash_register_modification_unit(_, _), _)) ->
                    false;
                (?cm_party_modification(_, _, ?cm_shop_modification(ShopID, _), _)) ->
                    {true, ShopID};
                (_) ->
                    false
            end,
            Changeset
        )
    ).

-spec assert_modifications_applicable(modifications(), timestamp(), revision(), party()) -> ok | no_return().
assert_modifications_applicable([?cm_shop_cash_register_modification_unit(_, _) | Others], Timestamp, Revision, Party) ->
    assert_modifications_applicable(Others, Timestamp, Revision, Party);
assert_modifications_applicable([PartyChange | Others], Timestamp, Revision, Party) ->
    case PartyChange of
        ?cm_contract_modification(ID, Modification) ->
            Contract = pm_party:get_contract(ID, Party),
            ok = assert_contract_modification_applicable(ID, Modification, Contract, PartyChange);
        ?cm_shop_modification(ID, Modification) ->
            Shop = pm_party:get_shop(ID, Party),
            ok = assert_shop_modification_applicable(ID, Modification, Shop, Party, Revision, PartyChange);
        ?cm_contractor_modification(ID, Modification) ->
            Contractor = pm_party:get_contractor(ID, Party),
            ok = assert_contractor_modification_applicable(ID, Modification, Contractor, PartyChange);
        ?cm_wallet_modification(ID, Modification) ->
            Wallet = pm_party:get_wallet(ID, Party),
            ok = assert_wallet_modification_applicable(ID, Modification, Wallet, PartyChange)
    end,
    Effect = pm_claim_committer_effect:make_safe(PartyChange, Timestamp, Revision),
    assert_modifications_applicable(
        Others, Timestamp, Revision, pm_claim_committer_effect:apply_claim_effect(Effect, Timestamp, Party)
    );
assert_modifications_applicable([], _, _, _) ->
    ok.

assert_contract_modification_applicable(_, {creation, _}, undefined, _) ->
    ok;
assert_contract_modification_applicable(ID, {creation, _}, #domain_Contract{}, PartyChange) ->
    raise_invalid_changeset(?cm_invalid_contract_already_exists(ID), [PartyChange]);
assert_contract_modification_applicable(ID, _AnyModification, undefined, PartyChange) ->
    raise_invalid_changeset(?cm_invalid_contract_not_exists(ID), [PartyChange]);
assert_contract_modification_applicable(ID, ?cm_contract_termination(_), Contract, PartyChange) ->
    case pm_contract:is_active(Contract) of
        true ->
            ok;
        false ->
            raise_invalid_changeset(?cm_invalid_contract(ID, {invalid_status, Contract#domain_Contract.status}), [
                PartyChange
            ])
    end;
assert_contract_modification_applicable(ID, ?cm_adjustment_creation(AdjustmentID, _), Contract, PartyChange) ->
    case pm_contract:get_adjustment(AdjustmentID, Contract) of
        undefined ->
            ok;
        _ ->
            raise_invalid_changeset(?cm_invalid_contract(ID, {contract_adjustment_already_exists, AdjustmentID}), [
                PartyChange
            ])
    end;
assert_contract_modification_applicable(ID, ?cm_payout_tool_creation(PayoutToolID, _), Contract, PartyChange) ->
    case pm_contract:get_payout_tool(PayoutToolID, Contract) of
        undefined ->
            ok;
        _ ->
            raise_invalid_changeset(?cm_invalid_contract(ID, {payout_tool_already_exists, PayoutToolID}), [PartyChange])
    end;
assert_contract_modification_applicable(ID, ?cm_payout_tool_info_modification(PayoutToolID, _), Contract, PartyChange) ->
    case pm_contract:get_payout_tool(PayoutToolID, Contract) of
        undefined ->
            raise_invalid_changeset(?cm_invalid_contract(ID, {payout_tool_not_exists, PayoutToolID}), [PartyChange]);
        _ ->
            ok
    end;
assert_contract_modification_applicable(_, _, _, _) ->
    ok.

assert_shop_modification_applicable(_, {creation, _}, undefined, _, _, _) ->
    ok;
assert_shop_modification_applicable(ID, _AnyModification, undefined, _, _, PartyChange) ->
    raise_invalid_changeset(?cm_invalid_shop_not_exists(ID), [PartyChange]);
assert_shop_modification_applicable(ID, {creation, _}, #domain_Shop{}, _, _, PartyChange) ->
    raise_invalid_changeset(?cm_invalid_shop_already_exists(ID), [PartyChange]);
assert_shop_modification_applicable(
    _ID,
    {shop_account_creation, _},
    #domain_Shop{account = Account},
    _Party,
    _Revision,
    _PartyChange
) when Account /= undefined ->
    throw(#'InvalidRequest'{errors = [<<"Can't change shop's account">>]});
assert_shop_modification_applicable(
    _ID,
    {contract_modification, #claim_management_ShopContractModification{contract_id = NewContractID}},
    #domain_Shop{contract_id = OldContractID},
    Party,
    Revision,
    PartyChange
) ->
    OldContract = pm_party:get_contract(OldContractID, Party),
    case pm_party:get_contract(NewContractID, Party) of
        #domain_Contract{} = NewContract ->
            assert_payment_institution_realm_equals(OldContract, NewContract, Revision, PartyChange);
        undefined ->
            raise_invalid_changeset(?cm_invalid_contract_not_exists(NewContractID), [PartyChange])
    end;
assert_shop_modification_applicable(_, _, _, _, _, _) ->
    ok.

assert_contractor_modification_applicable(_, {creation, _}, undefined, _) ->
    ok;
assert_contractor_modification_applicable(ID, _AnyModification, undefined, PartyChange) ->
    raise_invalid_changeset(?cm_invalid_contractor_not_exists(ID), [PartyChange]);
assert_contractor_modification_applicable(ID, {creation, _}, #domain_PartyContractor{}, PartyChange) ->
    raise_invalid_changeset(?cm_invalid_contractor_already_exists(ID), [PartyChange]);
assert_contractor_modification_applicable(_, _, _, _) ->
    ok.

assert_wallet_modification_applicable(_, {creation, _}, undefined, _) ->
    ok;
assert_wallet_modification_applicable(ID, _AnyModification, undefined, PartyChange) ->
    raise_invalid_changeset(?cm_invalid_wallet_not_exists(ID), [PartyChange]);
assert_wallet_modification_applicable(ID, {creation, _}, #domain_Wallet{}, PartyChange) ->
    raise_invalid_changeset(?cm_invalid_wallet_already_exists(ID), [PartyChange]);
assert_wallet_modification_applicable(
    _ID,
    {account_creation, _},
    #domain_Wallet{account = Account},
    _PartyChange
) when Account /= undefined ->
    throw(#'InvalidRequest'{errors = [<<"Can't change wallet's account">>]});
assert_wallet_modification_applicable(_, _, _, _) ->
    ok.

assert_payment_institution_realm_equals(
    #domain_Contract{id = OldContractID, payment_institution = OldRef},
    #domain_Contract{id = NewContractID, payment_institution = NewRef},
    Revision,
    PartyChange
) ->
    OldRealm = get_payment_institution_realm(OldRef, Revision, OldContractID, PartyChange),
    case get_payment_institution_realm(NewRef, Revision, NewContractID, PartyChange) of
        OldRealm ->
            ok;
        _NewRealm ->
            raise_invalid_payment_institution(NewContractID, NewRef, PartyChange)
    end.

get_payment_institution_realm(Ref, Revision, ContractID, PartyChange) ->
    case pm_domain:find(Revision, {payment_institution, Ref}) of
        #domain_PaymentInstitution{} = P ->
            pm_payment_institution:get_realm(P);
        notfound ->
            raise_invalid_payment_institution(ContractID, Ref, PartyChange)
    end.

-spec raise_invalid_payment_institution(
    dmsl_domain_thrift:'ContractID'(),
    dmsl_domain_thrift:'PaymentInstitutionRef'() | undefined,
    modification()
) -> no_return().
raise_invalid_payment_institution(ContractID, Ref, PartyChange) ->
    raise_invalid_changeset(
        ?cm_invalid_contract(
            ContractID,
            {invalid_object_reference, #claim_management_InvalidObjectReference{
                ref = make_optional_domain_ref(payment_institution, Ref)
            }}
        ),
        [PartyChange]
    ).

-spec assert_modifications_acceptable(modifications(), timestamp(), revision(), party()) -> ok | no_return().
assert_modifications_acceptable(Modifications, Timestamp, Revision, Party0) ->
    Effects = pm_claim_committer_effect:make_modifications_safe_effects(Modifications, Timestamp, Revision),
    Party = pm_claim_committer_effect:apply_effects(Effects, Timestamp, Party0),
    _ = assert_contracts_valid(Timestamp, Revision, Party, Modifications),
    _ = assert_shops_valid(Timestamp, Revision, Party, Modifications),
    _ = assert_wallets_valid(Timestamp, Revision, Party, Modifications),
    ok.

assert_contracts_valid(_Timestamp, _Revision, Party, Changeset) ->
    genlib_map:foreach(
        fun(_ID, Contract) ->
            assert_contract_valid(Contract, Party, Changeset)
        end,
        Party#domain_Party.contracts
    ).

assert_shops_valid(Timestamp, Revision, Party, Changeset) ->
    genlib_map:foreach(
        fun(_ID, Shop) ->
            assert_shop_valid(Shop, Timestamp, Revision, Party, Changeset)
        end,
        Party#domain_Party.shops
    ).

assert_wallets_valid(Timestamp, Revision, Party, Changeset) ->
    genlib_map:foreach(
        fun(_ID, Wallet) ->
            assert_wallet_valid(Wallet, Timestamp, Revision, Party, Changeset)
        end,
        Party#domain_Party.wallets
    ).

assert_contract_valid(
    #domain_Contract{id = ID, contractor_id = ContractorID},
    Party,
    Changeset
) when ContractorID /= undefined ->
    case pm_party:get_contractor(ContractorID, Party) of
        #domain_PartyContractor{} ->
            ok;
        undefined ->
            raise_invalid_changeset(
                ?cm_invalid_contract_contractor_not_exists(ID, ContractorID),
                Changeset
            )
    end;
assert_contract_valid(
    #domain_Contract{id = ID, contractor_id = undefined, contractor = undefined},
    _Party,
    Changeset
) ->
    raise_invalid_changeset(
        ?cm_invalid_contract_contractor_not_exists(ID, undefined),
        Changeset
    );
assert_contract_valid(_, _, _) ->
    ok.

assert_shop_valid(#domain_Shop{contract_id = ContractID} = Shop, Timestamp, Revision, Party, Changeset) ->
    case pm_party:get_contract(ContractID, Party) of
        #domain_Contract{} = Contract ->
            _ = assert_shop_contract_valid(Shop, Contract, Timestamp, Revision, Changeset),
            _ = assert_shop_payout_tool_valid(Shop, Contract, Changeset),
            ok;
        undefined ->
            raise_invalid_changeset(?cm_invalid_contract_not_exists(ContractID), Changeset)
    end.

assert_shop_contract_valid(
    #domain_Shop{id = ID, category = CategoryRef, account = ShopAccount},
    Contract,
    Timestamp,
    Revision,
    Changeset
) ->
    Terms = pm_party:get_terms(Contract, Timestamp, Revision),
    case ShopAccount of
        #domain_ShopAccount{currency = CurrencyRef} ->
            _ = assert_currency_valid(
                {shop, ID}, pm_contract:get_id(Contract), CurrencyRef, Terms, Revision, Changeset
            );
        undefined ->
            raise_invalid_changeset(?cm_invalid_shop_account_not_exists(ID), Changeset)
    end,
    #domain_TermSet{
        payments = #domain_PaymentsServiceTerms{categories = CategorySelector}
    } = Terms,
    Categories = pm_selector:reduce_to_value(CategorySelector, #{}, Revision),
    _ =
        ordsets:is_element(CategoryRef, Categories) orelse
            raise_invalid_changeset(
                ?cm_invalid_shop_contract_terms_violated(
                    ID,
                    pm_contract:get_id(Contract),
                    #domain_TermSet{payments = #domain_PaymentsServiceTerms{categories = CategorySelector}}
                ),
                Changeset
            ),
    ok.

assert_shop_payout_tool_valid(#domain_Shop{payout_tool_id = undefined, payout_schedule = undefined}, _, _) ->
    % automatic payouts disabled for this shop and it's ok
    ok;
assert_shop_payout_tool_valid(
    #domain_Shop{id = ID, payout_tool_id = undefined, payout_schedule = Schedule}, _, Changeset
) ->
    % automatic payouts enabled for this shop but no payout tool specified
    raise_invalid_changeset(?cm_invalid_shop_payout_tool_not_set_for_payouts(ID, Schedule), Changeset);
assert_shop_payout_tool_valid(#domain_Shop{id = ID, payout_tool_id = PayoutToolID} = Shop, Contract, Changeset) ->
    ShopAccountCurrency = (Shop#domain_Shop.account)#domain_ShopAccount.currency,
    ContractID = Contract#domain_Contract.id,
    case pm_contract:get_payout_tool(PayoutToolID, Contract) of
        #domain_PayoutTool{currency = ShopAccountCurrency} ->
            ok;
        #domain_PayoutTool{currency = PayoutToolCurrency} ->
            raise_invalid_changeset(
                ?cm_invalid_shop_payout_tool_currency_mismatch(
                    ID,
                    PayoutToolID,
                    ShopAccountCurrency,
                    PayoutToolCurrency
                ),
                Changeset
            );
        undefined ->
            raise_invalid_changeset(
                ?cm_invalid_shop_payout_tool_not_in_contract(ID, ContractID, PayoutToolID),
                Changeset
            )
    end.

assert_wallet_valid(#domain_Wallet{contract = ContractID} = Wallet, Timestamp, Revision, Party, Changeset) ->
    case pm_party:get_contract(ContractID, Party) of
        #domain_Contract{} = Contract ->
            _ = assert_wallet_contract_valid(Wallet, Contract, Timestamp, Revision, Changeset),
            ok;
        undefined ->
            raise_invalid_changeset(?cm_invalid_contract_not_exists(ContractID), Changeset)
    end.

assert_wallet_contract_valid(#domain_Wallet{id = ID, account = Account}, Contract, Timestamp, Revision, Changeset) ->
    case Account of
        #domain_WalletAccount{currency = CurrencyRef} ->
            Terms = pm_party:get_terms(Contract, Timestamp, Revision),
            _ = assert_currency_valid(
                {wallet, ID}, pm_contract:get_id(Contract), CurrencyRef, Terms, Revision, Changeset
            ),
            ok;
        undefined ->
            raise_invalid_changeset(?cm_invalid_wallet_account_not_exists(ID), Changeset)
    end,
    ok.

assert_currency_valid(
    {shop, _} = Prefix,
    ContractID,
    CurrencyRef,
    #domain_TermSet{payments = #domain_PaymentsServiceTerms{currencies = Selector}},
    Revision,
    Changeset
) ->
    Terms = #domain_TermSet{payments = #domain_PaymentsServiceTerms{currencies = Selector}},
    assert_currency_valid(Prefix, ContractID, CurrencyRef, Selector, Terms, Revision, Changeset);
assert_currency_valid(
    {shop, _} = Prefix,
    ContractID,
    _,
    #domain_TermSet{payments = undefined},
    _,
    Changeset
) ->
    raise_contract_terms_violated(Prefix, ContractID, #domain_TermSet{}, Changeset);
assert_currency_valid(
    {wallet, _} = Prefix,
    ContractID,
    CurrencyRef,
    #domain_TermSet{wallets = #domain_WalletServiceTerms{currencies = Selector}},
    Revision,
    Changeset
) ->
    Terms = #domain_TermSet{wallets = #domain_WalletServiceTerms{currencies = Selector}},
    assert_currency_valid(Prefix, ContractID, CurrencyRef, Selector, Terms, Revision, Changeset);
assert_currency_valid(
    {wallet, _} = Prefix,
    ContractID,
    _,
    #domain_TermSet{wallets = undefined},
    _,
    Changeset
) ->
    raise_contract_terms_violated(Prefix, ContractID, #domain_TermSet{}, Changeset).

assert_currency_valid(Prefix, ContractID, CurrencyRef, Selector, Terms, Revision, Changeset) ->
    Currencies = pm_selector:reduce_to_value(Selector, #{}, Revision),
    _ =
        ordsets:is_element(CurrencyRef, Currencies) orelse
            raise_contract_terms_violated(Prefix, ContractID, Terms, Changeset).

-spec raise_contract_terms_violated(
    {shop, shop_id()} | {wallet, wallet_id()},
    contract_id(),
    dmsl_domain_thrift:'TermSet'(),
    changeset()
) -> no_return().
raise_contract_terms_violated({shop, ID}, ContractID, Terms, Changeset) ->
    raise_invalid_changeset(?cm_invalid_shop_contract_terms_violated(ID, ContractID, Terms), Changeset);
raise_contract_terms_violated({wallet, ID}, ContractID, Terms, Changeset) ->
    raise_invalid_changeset(?cm_invalid_wallet_contract_terms_violated(ID, ContractID, Terms), Changeset).

-spec raise_invalid_changeset(dmsl_claim_management_thrift:'InvalidChangesetReason'(), changeset()) -> no_return().
raise_invalid_changeset(Reason, InvalidChangeset) ->
    throw(?cm_invalid_party_changeset(Reason, [{party_modification, C} || C <- InvalidChangeset])).

make_optional_domain_ref(_, undefined) ->
    undefined;
make_optional_domain_ref(Type, Ref) ->
    {Type, Ref}.
