%%% Payment tools

-module(pm_payment_tool).

-include_lib("damsel/include/dmsl_domain_thrift.hrl").

%%

-export([create_from_method/1]).
-export([test_condition/3]).

%%

-type t() :: dmsl_domain_thrift:'PaymentTool'().
-type method() :: dmsl_domain_thrift:'PaymentMethodRef'().
-type condition() :: dmsl_domain_thrift:'PaymentToolCondition'().

-import(pm_condition, [some_defined/1, ternary_and/1, ternary_while/1]).

-spec create_from_method(method()) -> t().
%% TODO empty strings - ugly hack for dialyzar
create_from_method(#domain_PaymentMethodRef{
    id =
        {bank_card, #domain_BankCardPaymentMethod{
            payment_system = PaymentSystem,
            is_cvv_empty = IsCVVEmpty,
            payment_token = PaymentToken,
            tokenization_method = TokenizationMethod,
            payment_system_deprecated = PaymentSystemLegacy,
            token_provider_deprecated = TokenProvider
        }}
}) ->
    {bank_card, #domain_BankCard{
        token = <<"">>,
        payment_system = PaymentSystem,
        bin = <<"">>,
        last_digits = <<"">>,
        payment_token = PaymentToken,
        tokenization_method = TokenizationMethod,
        is_cvv_empty = IsCVVEmpty,
        payment_system_deprecated = PaymentSystemLegacy,
        token_provider_deprecated = TokenProvider
    }};
create_from_method(#domain_PaymentMethodRef{id = {payment_terminal, Ref}}) ->
    {payment_terminal, #domain_PaymentTerminal{payment_service = Ref}};
create_from_method(#domain_PaymentMethodRef{id = {digital_wallet, Ref}}) ->
    {digital_wallet, #domain_DigitalWallet{
        payment_service = Ref,
        id = <<"">>
    }};
create_from_method(#domain_PaymentMethodRef{id = {mobile, Ref}}) ->
    {mobile_commerce, #domain_MobileCommerce{
        operator = Ref,
        phone = #domain_MobilePhone{
            cc = <<"">>,
            ctn = <<"">>
        }
    }};
create_from_method(#domain_PaymentMethodRef{id = {crypto_currency, Ref}}) ->
    {crypto_currency, Ref};
create_from_method(#domain_PaymentMethodRef{id = {bank_card_deprecated, PaymentSystem}}) ->
    {bank_card, #domain_BankCard{
        payment_system_deprecated = PaymentSystem,
        token = <<"">>,
        bin = <<"">>,
        last_digits = <<"">>
    }};
create_from_method(#domain_PaymentMethodRef{id = {payment_terminal_deprecated, TerminalType}}) ->
    {payment_terminal, #domain_PaymentTerminal{terminal_type_deprecated = TerminalType}};
create_from_method(#domain_PaymentMethodRef{id = {digital_wallet_deprecated, Provider}}) ->
    {digital_wallet, #domain_DigitalWallet{
        provider_deprecated = Provider,
        id = <<"">>
    }};
create_from_method(#domain_PaymentMethodRef{
    id =
        {tokenized_bank_card_deprecated, #domain_TokenizedBankCard{
            payment_system = PaymentSystem,
            payment_token = PaymentToken,
            tokenization_method = TokenizationMethod,
            payment_system_deprecated = PaymentSystemLegacy,
            token_provider_deprecated = TokenProvider
        }}
}) ->
    {bank_card, #domain_BankCard{
        token = <<"">>,
        payment_system = PaymentSystem,
        bin = <<"">>,
        last_digits = <<"">>,
        payment_token = PaymentToken,
        tokenization_method = TokenizationMethod,
        payment_system_deprecated = PaymentSystemLegacy,
        token_provider_deprecated = TokenProvider
    }};
create_from_method(#domain_PaymentMethodRef{id = {empty_cvv_bank_card_deprecated, PaymentSystem}}) ->
    {bank_card, #domain_BankCard{
        payment_system_deprecated = PaymentSystem,
        token = <<"">>,
        bin = <<"">>,
        last_digits = <<"">>,
        is_cvv_empty = true
    }};
create_from_method(#domain_PaymentMethodRef{id = {crypto_currency_deprecated, CC}}) ->
    {crypto_currency_deprecated, CC};
create_from_method(#domain_PaymentMethodRef{id = {mobile_deprecated, Operator}}) ->
    {mobile_commerce, #domain_MobileCommerce{
        operator_deprecated = Operator,
        phone = #domain_MobilePhone{
            cc = <<"">>,
            ctn = <<"">>
        }
    }}.

%%

-spec test_condition(condition(), t(), pm_domain:revision()) -> boolean() | undefined.
test_condition({bank_card, C}, {bank_card, V = #domain_BankCard{}}, Rev) ->
    test_bank_card_condition(C, V, Rev);
test_condition({payment_terminal, C}, {payment_terminal, V = #domain_PaymentTerminal{}}, Rev) ->
    test_payment_terminal_condition(C, V, Rev);
test_condition({digital_wallet, C}, {digital_wallet, V = #domain_DigitalWallet{}}, Rev) ->
    test_digital_wallet_condition(C, V, Rev);
test_condition({crypto_currency, C}, {crypto_currency, V}, Rev) ->
    test_crypto_currency_condition(C, {ref, V}, Rev);
test_condition({crypto_currency, C}, {crypto_currency_deprecated, V}, Rev) ->
    test_crypto_currency_condition(C, {legacy, V}, Rev);
test_condition({mobile_commerce, C}, {mobile_commerce, V}, Rev) ->
    test_mobile_commerce_condition(C, V, Rev);
test_condition(_PaymentTool, _Condition, _Rev) ->
    false.

test_bank_card_condition(#domain_BankCardCondition{definition = Def}, V, Rev) when Def /= undefined ->
    test_bank_card_condition_def(Def, V, Rev);
test_bank_card_condition(#domain_BankCardCondition{}, _, _Rev) ->
    true.

% legacy
test_bank_card_condition_def(
    {payment_system_is, Ps},
    #domain_BankCard{payment_system_deprecated = Ps, token_provider_deprecated = undefined},
    _Rev
) ->
    true;
test_bank_card_condition_def({payment_system_is, _Ps}, #domain_BankCard{}, _Rev) ->
    false;
test_bank_card_condition_def({payment_system, PaymentSystem}, V, Rev) ->
    test_payment_system_condition(PaymentSystem, V, Rev);
test_bank_card_condition_def({issuer_country_is, IssuerCountry}, V, Rev) ->
    test_issuer_country_condition(IssuerCountry, V, Rev);
test_bank_card_condition_def({issuer_bank_is, BankRef}, V, Rev) ->
    test_issuer_bank_condition(BankRef, V, Rev);
test_bank_card_condition_def({category_is, CategoryRef}, V, Rev) ->
    test_bank_card_category_condition(CategoryRef, V, Rev);
test_bank_card_condition_def(
    {empty_cvv_is, Val},
    #domain_BankCard{is_cvv_empty = Val},
    _Rev
) ->
    true;
%% ?????? ???????????????? ?????????????????????????? ?? ??????????????, ?? ?????????????? ?????? is_cvv_empty
test_bank_card_condition_def(
    {empty_cvv_is, false},
    #domain_BankCard{is_cvv_empty = undefined},
    _Rev
) ->
    true;
test_bank_card_condition_def({empty_cvv_is, _Val}, #domain_BankCard{}, _Rev) ->
    false.

test_payment_system_condition(
    #domain_PaymentSystemCondition{
        payment_system_is = PsIs,
        token_service_is = TpIs,
        payment_system_is_deprecated = PsLegacyIs,
        token_provider_is_deprecated = TpLegacyIs,
        tokenization_method_is = TmIs
    },
    #domain_BankCard{
        payment_system = Ps,
        payment_token = Tp,
        payment_system_deprecated = PsLegacy,
        token_provider_deprecated = TpLegacy,
        tokenization_method = Tm
    },
    _Rev
) ->
    ternary_and([
        some_defined([PsIs, TpIs, PsLegacyIs, TpLegacyIs, TmIs]),
        PsIs == undefined orelse PsIs == Ps,
        TpIs == undefined orelse TpIs == Tp,
        PsLegacyIs == undefined orelse PsLegacyIs == PsLegacy,
        TpLegacyIs == undefined orelse TpLegacyIs == TpLegacy,
        TmIs == undefined orelse ternary_while([Tm, TmIs == Tm])
    ]).

test_issuer_country_condition(Country, #domain_BankCard{issuer_country = TargetCountry}, _Rev) ->
    ternary_while([TargetCountry, Country == TargetCountry]).

test_issuer_bank_condition(BankRef, #domain_BankCard{bank_name = BankName, bin = BIN}, Rev) ->
    #domain_Bank{binbase_id_patterns = Patterns, bins = BINs} = pm_domain:get(Rev, {bank, BankRef}),
    case {Patterns, BankName} of
        {P, B} when is_list(P) and is_binary(B) ->
            test_bank_card_patterns(Patterns, BankName);
        % TODO ??.??. BinBase ???? ???????????????? ???????????? ?????????????? ????????????, ?????? ???? ???????????????????? ???? ???????????????????????? ?? ?????????????????? ???? ??????????.
        %      B ?????????????? ?????????? ???????????????????? ???? ??????????.
        {_, _} ->
            test_bank_card_bins(BIN, BINs)
    end.

test_bank_card_category_condition(CategoryRef, #domain_BankCard{category = Category}, Rev) ->
    #domain_BankCardCategory{
        category_patterns = Patterns
    } = pm_domain:get(Rev, {bank_card_category, CategoryRef}),
    test_bank_card_patterns(Patterns, Category).

test_bank_card_bins(BIN, BINs) ->
    ordsets:is_element(BIN, BINs).

test_bank_card_patterns(Patterns, BankName) ->
    Matches = ordsets:filter(fun(E) -> genlib_wildcard:match(BankName, E) end, Patterns),
    ordsets:size(Matches) > 0.

test_payment_terminal_condition(#domain_PaymentTerminalCondition{definition = Def}, V, Rev) ->
    Def =:= undefined orelse test_payment_terminal_condition_def(Def, V, Rev).

test_payment_terminal_condition_def(
    {payment_service_is, Ps1},
    #domain_PaymentTerminal{payment_service = Ps2},
    _Rev
) ->
    Ps1 =:= Ps2;
test_payment_terminal_condition_def(
    {provider_is_deprecated, V1},
    #domain_PaymentTerminal{terminal_type_deprecated = V2},
    _Rev
) ->
    V1 =:= V2;
test_payment_terminal_condition_def(_Cond, _Data, _Rev) ->
    false.

test_digital_wallet_condition(#domain_DigitalWalletCondition{definition = Def}, V, Rev) ->
    Def =:= undefined orelse test_digital_wallet_condition_def(Def, V, Rev).

test_digital_wallet_condition_def(
    {payment_service_is, Ps1},
    #domain_DigitalWallet{payment_service = Ps2},
    _Rev
) ->
    Ps1 =:= Ps2;
test_digital_wallet_condition_def(
    {provider_is_deprecated, V1},
    #domain_DigitalWallet{provider_deprecated = V2},
    _Rev
) ->
    V1 =:= V2;
test_digital_wallet_condition_def(_Cond, _Data, _Rev) ->
    false.

test_crypto_currency_condition(#domain_CryptoCurrencyCondition{definition = Def}, V, Rev) ->
    Def =:= undefined orelse test_crypto_currency_condition_def(Def, V, Rev).

test_crypto_currency_condition_def({crypto_currency_is, C1}, {ref, C2}, _Rev) ->
    C1 =:= C2;
test_crypto_currency_condition_def({crypto_currency_is_deprecated, C1}, {legacy, C2}, _Rev) ->
    C1 =:= C2;
test_crypto_currency_condition_def(_Cond, _Data, _Rev) ->
    false.

test_mobile_commerce_condition(#domain_MobileCommerceCondition{definition = Def}, V, Rev) ->
    Def =:= undefined orelse test_mobile_commerce_condition_def(Def, V, Rev).

test_mobile_commerce_condition_def(
    {operator_is, C1},
    #domain_MobileCommerce{operator = C2},
    _Rev
) ->
    C1 =:= C2;
test_mobile_commerce_condition_def(
    {operator_is_deprecated, C1},
    #domain_MobileCommerce{operator_deprecated = C2},
    _Rev
) ->
    C1 =:= C2;
test_mobile_commerce_condition_def(_Cond, _Data, _Rev) ->
    false.
