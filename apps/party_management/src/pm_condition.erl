-module(pm_condition).

-include_lib("damsel/include/dmsl_domain_thrift.hrl").

%%

-export([test/3]).
-export([some_defined/1]).
-export([ternary_and/1]).
-export([ternary_or/1]).
-export([ternary_with_defined/1]).

%%
-export_type([ternary_term/0]).
-export_type([ternary_value/0]).

-type condition() :: dmsl_domain_thrift:'Condition'().
-type varset() :: pm_selector:varset().
-type ternary_term() :: ternary_lazy_term() | ternary_simple_term().
-type ternary_lazy_term() :: fun(() -> ternary_simple_term()).
%% Any (any()) other value is evaluated as true
-type ternary_simple_term() :: ternary_value() | any().
-type ternary_value() :: true | undefined | false.

-spec test(condition(), varset(), pm_domain:revision()) -> true | false | undefined.
test({category_is, V1}, #{category := V2}, _) ->
    V1 =:= V2;
test({currency_is, V1}, #{currency := V2}, _) ->
    V1 =:= V2;
test({cost_in, V}, #{cost := C}, _) ->
    pm_cash_range:is_inside(C, V) =:= within;
test({payment_tool, C}, #{payment_tool := V}, Rev) ->
    pm_payment_tool:test_condition(C, V, Rev);
test({shop_location_is, V}, #{shop := S}, _) ->
    V =:= S#domain_Shop.location;
test({party, V}, #{party_id := PartyID} = VS, _) ->
    test_party(V, PartyID, VS);
test({payout_method_is, V1}, #{payout_method := V2}, _) ->
    V1 =:= V2;
test({identification_level_is, V1}, #{identification_level := V2}, _) ->
    V1 =:= V2;
test({p2p_tool, #domain_P2PToolCondition{} = C}, #{p2p_tool := #domain_P2PTool{} = V}, Rev) ->
    test_p2p_tool(C, V, Rev);
test({bin_data, #domain_BinDataCondition{} = C}, #{bin_data := #domain_BinData{} = V}, Rev) ->
    test_bindata_tool(C, V, Rev);
test(_, #{}, _) ->
    undefined.

test_party(#domain_PartyCondition{id = PartyID, definition = Def}, PartyID, VS) ->
    test_party_definition(Def, VS);
test_party(_, _, _) ->
    false.

test_party_definition(undefined, _) ->
    true;
test_party_definition({shop_is, ID1}, #{shop_id := ID2}) ->
    ID1 =:= ID2;
test_party_definition({wallet_is, ID1}, #{wallet_id := ID2}) ->
    ID1 =:= ID2;
test_party_definition({contract_is, ID1}, #{contract_id := ID2}) ->
    ID1 =:= ID2;
test_party_definition(_, _) ->
    undefined.

test_p2p_tool(P2PCondition, P2PTool, Rev) ->
    #domain_P2PToolCondition{
        sender_is = SenderIs,
        receiver_is = ReceiverIs
    } = P2PCondition,
    #domain_P2PTool{
        sender = Sender,
        receiver = Receiver
    } = P2PTool,
    ternary_and([
        ternary_or([
            SenderIs == undefined,
            fun() -> test({payment_tool, SenderIs}, #{payment_tool => Sender}, Rev) end
        ]),
        ternary_or([
            ReceiverIs == undefined,
            fun() -> test({payment_tool, ReceiverIs}, #{payment_tool => Receiver}, Rev) end
        ])
    ]).

test_bindata_tool(
    #domain_BinDataCondition{
        payment_system = PaymentSystemCondition,
        bank_name = BankNameCondition
    },
    #domain_BinData{
        payment_system = PaymentSystem,
        bank_name = BankName
    },
    _Rev
) ->
    ternary_and([
        ternary_or([
            PaymentSystemCondition == undefined,
            fun() -> test_string_condition(PaymentSystemCondition, PaymentSystem) end
        ]),
        ternary_or([
            BankNameCondition == undefined,
            fun() -> test_string_condition(BankNameCondition, BankName) end
        ])
    ]).

test_string_condition({matches, Substring}, String) ->
    string:find(String, Substring) /= nomatch;
test_string_condition({equals, String1}, String2) ->
    String1 =:= String2.

-spec some_defined(list()) -> boolean().
some_defined(List) ->
    genlib_list:compact(List) /= [].

-spec ternary_and([ternary_term()]) -> ternary_value().
ternary_and([]) ->
    undefined;
ternary_and(List) ->
    genlib_list:foldl_while(
        fun(Elem, Acc) ->
            case ternary_and(compute_term(Elem), Acc) of
                false -> {halt, false};
                Result -> {cont, Result}
            end
        end,
        true,
        List
    ).

-spec ternary_or([ternary_term()]) -> ternary_value().
ternary_or([]) ->
    undefined;
ternary_or(List) ->
    genlib_list:foldl_while(
        fun(Elem, Acc) ->
            case ternary_or(compute_term(Elem), Acc) of
                true -> {halt, true};
                Result -> {cont, Result}
            end
        end,
        false,
        List
    ).

ternary_and(true, true) ->
    true;
ternary_and(MaybeLeftFalse, MaybeRightFalse) when MaybeLeftFalse == false; MaybeRightFalse == false ->
    false;
ternary_and(MaybeLeftUndef, MaybeRightUndef) when MaybeLeftUndef == undefined; MaybeRightUndef == undefined ->
    undefined.

ternary_or(false, false) ->
    false;
ternary_or(MaybeLeftTrue, MaybeRightTrue) when MaybeLeftTrue == true; MaybeRightTrue == true ->
    true;
ternary_or(MaybeLeftUndef, MaybeRightUndef) when MaybeLeftUndef == undefined; MaybeRightUndef == undefined ->
    undefined.

-spec ternary_with_defined([ternary_term()]) -> ternary_value().
ternary_with_defined(Terms) ->
    genlib_list:foldl_while(
        fun(Term, _) ->
            case compute_term(Term) of
                true -> {cont, true};
                Result -> {halt, Result}
            end
        end,
        undefined,
        Terms
    ).

compute_term(Fun) when is_function(Fun, 0) -> to_ternary_bool(Fun());
compute_term(Term) -> to_ternary_bool(Term).

to_ternary_bool(Bool) when is_boolean(Bool) -> Bool;
to_ternary_bool(undefined) -> undefined;
to_ternary_bool(_) -> true.
