%%%
%%% Copyright 2021 RBKmoney
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%

-module(pm_claim_committer_converter).

-include_lib("damsel/include/dmsl_payment_processing_thrift.hrl").
-include_lib("damsel/include/dmsl_claim_management_thrift.hrl").

-include("claim_management.hrl").
-include("party_events.hrl").

%% API
-export([new_party_claim/5]).

-type payproc_claim() :: dmsl_payment_processing_thrift:'Claim'().
-type timestamp() :: pm_datetime:timestamp().
-type revision() :: pm_domain:revision().
-type claim_id() :: dmsl_claim_management_thrift:'ClaimID'().
-type changes() :: pm_claim_committer:modifications().

-spec new_party_claim(claim_id(), revision(), timestamp(), timestamp(), changes()) -> payproc_claim().
new_party_claim(ID, Revision, CreatedAt, UpdatedAt, Changes) ->
    #payproc_Claim{
        id = ID,
        status = ?pending(),
        changeset = to_party_changeset(Changes),
        revision = Revision,
        created_at = CreatedAt,
        updated_at = UpdatedAt
    }.

to_party_changeset(Changes) ->
    lists:map(
        fun(PartyMod) ->
            to_payproc_party_modification(PartyMod)
        end,
        Changes
    ).

to_payproc_party_modification(?cm_contractor_modification(ContractorID, ContractorModification)) ->
    ?contractor_modification(ContractorID, ContractorModification);
to_payproc_party_modification(?cm_contract_modification(ContractID, ContractModification)) ->
    ?contract_modification(
        ContractID,
        to_payproc_contract_modification(ContractModification)
    );
to_payproc_party_modification(?cm_shop_modification(ShopID, ShopModification)) ->
    ?shop_modification(
        ShopID,
        to_payproc_shop_modification(ShopModification)
    ).

to_payproc_contract_modification(
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
to_payproc_contract_modification(?cm_contract_termination(Reason)) ->
    ?contract_termination(Reason);
to_payproc_contract_modification(?cm_adjustment_creation(ContractAdjustmentID, Params)) ->
    ContractTemplateRef = Params#claim_management_ContractAdjustmentParams.template,
    ?adjustment_creation(
        ContractAdjustmentID,
        #payproc_ContractAdjustmentParams{template = ContractTemplateRef}
    );
to_payproc_contract_modification(
    ?cm_payout_tool_creation(PayoutToolID, #claim_management_PayoutToolParams{
        currency = CurrencyRef,
        tool_info = PayoutToolInfo
    })
) ->
    ?payout_tool_creation(PayoutToolID, #payproc_PayoutToolParams{
        currency = CurrencyRef,
        tool_info = PayoutToolInfo
    });
to_payproc_contract_modification(
    ?cm_payout_tool_info_modification(PayoutToolID, PayoutToolModification)
) ->
    ?payout_tool_info_modification(PayoutToolID, PayoutToolModification);
to_payproc_contract_modification(
    {legal_agreement_binding, _LegalAgreement} = LegalAgreementBinding
) ->
    LegalAgreementBinding;
to_payproc_contract_modification(
    {report_preferences_modification, _ReportPreferences} = ReportPreferencesModification
) ->
    ReportPreferencesModification;
to_payproc_contract_modification({contractor_modification, _ContractorID} = ContractorModification) ->
    ContractorModification.

to_payproc_shop_modification({creation, ShopParams}) ->
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
to_payproc_shop_modification({category_modification, _CategoryRef} = CategoryModification) ->
    CategoryModification;
to_payproc_shop_modification({details_modification, _ShopDetails} = DetailsModification) ->
    DetailsModification;
to_payproc_shop_modification(?cm_shop_contract_modification(ContractID, PayoutToolID)) ->
    ?shop_contract_modification(ContractID, PayoutToolID);
to_payproc_shop_modification({payout_tool_modification, _PayoutToolID} = PayoutToolModification) ->
    PayoutToolModification;
to_payproc_shop_modification({location_modification, _ShopLocation} = LocationModification) ->
    LocationModification;
to_payproc_shop_modification(?cm_shop_account_creation_params(CurrencyRef)) ->
    ?shop_account_creation_params(CurrencyRef);
to_payproc_shop_modification(?cm_payout_schedule_modification(BusinessScheduleRef)) ->
    ?payout_schedule_modification(BusinessScheduleRef).
