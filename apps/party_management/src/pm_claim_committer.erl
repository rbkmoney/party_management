-module(pm_claim_committer).

-include_lib("damsel/include/dmsl_payment_processing_thrift.hrl").
-include_lib("damsel/include/dmsl_claim_management_thrift.hrl").

-include("claim_management.hrl").
-include("party_events.hrl").

-export([from_claim_mgmt/1]).
-export([assert_cash_register_modifications_applicable/2]).

-type party() :: pm_party:party().
-type changeset() :: dmsl_claim_management_thrift:'ClaimChangeset'().

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
    CashRegisterShopIDs = maps:keys(MappedChanges),
    ShopIDs = get_all_valid_shop_ids(Changeset, Party),
    case sets:is_subset(CashRegisterShopIDs, ShopIDs) of
        true ->
            ok;
        false ->
            ShopID = hd(sets:to_list(sets:subtract(CashRegisterShopIDs, ShopIDs))),
            InvalidChangeset = maps:get(ShopID, MappedChanges),
            throw(#claim_management_InvalidChangeset{
                reason = ?cm_invalid_shop(ShopID, {not_exists, #claim_management_InvalidClaimConcreteReason{}}),
                invalid_changeset = [InvalidChangeset]
            })
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
            (C = #claim_management_ModificationUnit{modification = {party_modification, ?cm_cash_register_modification_unit_modification(ShopID, _)}}, Acc) ->
                Acc#{ShopID => C };
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
