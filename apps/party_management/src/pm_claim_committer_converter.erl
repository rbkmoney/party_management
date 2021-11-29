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

-include("party_events.hrl").

%% API
-export([new_party_claim/4]).

-type payproc_claim() :: dmsl_payment_processing_thrift:'Claim'().
-type timestamp() :: pm_datetime:timestamp().
-type revision() :: pm_domain:revision().
-type claim_id() :: dmsl_claim_management_thrift:'ClaimID'().

-spec new_party_claim(claim_id(), revision(), timestamp(), timestamp()) -> payproc_claim().
new_party_claim(ID, Revision, CreatedAt, UpdatedAt) ->
    #payproc_Claim{
        id = ID,
        status = ?pending(),
        revision = Revision,
        created_at = CreatedAt,
        updated_at = UpdatedAt,
        caused_by = build_claim_ref(ID, Revision)
    }.

build_claim_ref(ID, Revision) ->
    #payproc_ClaimManagementClaimRef{id = ID, revision = Revision}.
