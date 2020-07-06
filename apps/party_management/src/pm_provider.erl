-module(pm_provider).

-include_lib("damsel/include/dmsl_domain_thrift.hrl").

%% API
-export([reduce_p2p_provider/3]).
-export([reduce_withdrawal_provider/3]).
-export([reduce_payment_provider/3]).
-export([reduce_provider_terminal_terms/4]).

-type p2p_provider()            :: dmsl_domain_thrift:'P2PProvider'().
-type withdrawal_provider()     :: dmsl_domain_thrift:'WithdrawalProvider'().
-type provider()                :: dmsl_domain_thrift:'Provider'().
-type terminal()                :: dmsl_domain_thrift:'Terminal'().
-type provision_terms()         :: dmsl_domain_thrift:'ProvisionTermSet'().
-type varset()                  :: pm_selector:varset().
-type domain_revision()         :: pm_domain:revision().

-spec reduce_p2p_provider(p2p_provider(), varset(), domain_revision()) -> p2p_provider().

reduce_p2p_provider(#domain_P2PProvider{p2p_terms = Terms} = Provider, VS, DomainRevision) ->
    Provider#domain_P2PProvider{
        p2p_terms = reduce_p2p_terms(Terms, VS, DomainRevision)
    }.

-spec reduce_withdrawal_provider(withdrawal_provider(), varset(), domain_revision()) -> withdrawal_provider().

reduce_withdrawal_provider(#domain_WithdrawalProvider{withdrawal_terms = Terms} = Provider, VS, DomainRevision) ->
    Provider#domain_WithdrawalProvider{
        withdrawal_terms = reduce_withdrawal_terms(Terms, VS, DomainRevision)
    }.

-spec reduce_payment_provider(provider(), varset(), domain_revision()) -> provider().

reduce_payment_provider(Provider, VS, DomainRevision) ->
    Provider#domain_Provider{
        terminal = pm_selector:reduce(Provider#domain_Provider.terminal, VS, DomainRevision),
        terms = reduce_provision_terms(Provider#domain_Provider.terms, VS, DomainRevision)
    }.

-spec reduce_provider_terminal_terms(provider(), terminal(), varset(), domain_revision()) ->
    provision_terms().

reduce_provider_terminal_terms(Provider, Terminal, VS, DomainRevision) ->
    ProviderTerms = Provider#domain_Provider.terms,
    TerminalTerms = Terminal#domain_Terminal.terms,
    MergedTerms = merge_terms(ProviderTerms, TerminalTerms),
    reduce_provision_terms(MergedTerms, VS, DomainRevision).

reduce_provision_terms(undefined = Terms, _VS, _DomainRevision) ->
    Terms;
reduce_provision_terms(#domain_ProvisionTermSet{} = Terms, VS, DomainRevision) ->
    Terms#domain_ProvisionTermSet{
        payments = reduce_payment_terms(Terms#domain_ProvisionTermSet.payments, VS, DomainRevision),
        recurrent_paytools = reduce_recurrent_paytool_terms(
            Terms#domain_ProvisionTermSet.recurrent_paytools, VS, DomainRevision
        ),
        wallet = reduce_wallet_terms(Terms#domain_ProvisionTermSet.wallet, VS, DomainRevision)
    }.

reduce_wallet_terms(undefined = Terms, _VS, _DomainRevision) ->
    Terms;
reduce_wallet_terms(#domain_WalletProvisionTerms{} = Terms, VS, Rev) ->
    Terms#domain_WalletProvisionTerms{
        withdrawals = reduce_withdrawal_terms(Terms#domain_WalletProvisionTerms.withdrawals, VS, Rev),
        p2p = reduce_p2p_terms(Terms#domain_WalletProvisionTerms.p2p, VS, Rev)
    }.

reduce_p2p_terms(undefined = Terms, _VS, _Rev) ->
    Terms;
reduce_p2p_terms(#domain_P2PProvisionTerms{} = Terms, VS, Rev) ->
    Terms#domain_P2PProvisionTerms{
        currencies = reduce_if_defined(Terms#domain_P2PProvisionTerms.currencies, VS, Rev),
        cash_limit = reduce_if_defined(Terms#domain_P2PProvisionTerms.cash_limit, VS, Rev),
        cash_flow = reduce_if_defined(Terms#domain_P2PProvisionTerms.cash_flow, VS, Rev),
        fees = reduce_if_defined(Terms#domain_P2PProvisionTerms.fees, VS, Rev)
    }.

reduce_withdrawal_terms(undefined = Terms, _VS, _Rev) ->
    Terms;
reduce_withdrawal_terms(#domain_WithdrawalProvisionTerms{} = Terms, VS, Rev) ->
    Terms#domain_WithdrawalProvisionTerms{
        currencies = reduce_if_defined(Terms#domain_WithdrawalProvisionTerms.currencies, VS, Rev),
        payout_methods = reduce_if_defined(Terms#domain_WithdrawalProvisionTerms.payout_methods, VS, Rev),
        cash_limit = reduce_if_defined(Terms#domain_WithdrawalProvisionTerms.cash_limit, VS, Rev),
        cash_flow = reduce_if_defined(Terms#domain_WithdrawalProvisionTerms.cash_flow, VS, Rev)
    }.

reduce_payment_terms(undefined = PaymentTerms, _VS, _DomainRevision) ->
    PaymentTerms;
reduce_payment_terms(PaymentTerms, VS, DomainRevision) ->
    PaymentTerms#domain_PaymentsProvisionTerms{
        currencies = reduce_if_defined(PaymentTerms#domain_PaymentsProvisionTerms.currencies, VS, DomainRevision),
        categories = reduce_if_defined(PaymentTerms#domain_PaymentsProvisionTerms.categories, VS, DomainRevision),
        payment_methods = reduce_if_defined(
            PaymentTerms#domain_PaymentsProvisionTerms.payment_methods, VS, DomainRevision
        ),
        cash_limit = reduce_if_defined(PaymentTerms#domain_PaymentsProvisionTerms.cash_limit, VS, DomainRevision),
        cash_flow = reduce_if_defined(PaymentTerms#domain_PaymentsProvisionTerms.cash_flow, VS, DomainRevision),
        holds = pm_maybe:apply(
            fun(X) -> reduce_payment_hold_terms(X, VS, DomainRevision) end,
            PaymentTerms#domain_PaymentsProvisionTerms.holds
        ),
        refunds = pm_maybe:apply(
            fun(X) -> reduce_payment_refund_terms(X, VS, DomainRevision) end,
            PaymentTerms#domain_PaymentsProvisionTerms.refunds
        ),
        chargebacks = pm_maybe:apply(
            fun(X) -> reduce_payment_chargeback_terms(X, VS, DomainRevision) end,
            PaymentTerms#domain_PaymentsProvisionTerms.chargebacks
        )
    }.

reduce_payment_hold_terms(PaymentHoldTerms, VS, DomainRevision) ->
    PaymentHoldTerms#domain_PaymentHoldsProvisionTerms{
        lifetime = reduce_if_defined(PaymentHoldTerms#domain_PaymentHoldsProvisionTerms.lifetime, VS, DomainRevision),
        partial_captures = pm_maybe:apply(
            fun(X) -> reduce_partial_captures_terms(X, VS, DomainRevision) end,
            #domain_PaymentHoldsProvisionTerms.partial_captures
        )
    }.

reduce_partial_captures_terms(#domain_PartialCaptureProvisionTerms{} = Terms, _VS, _DomainRevision) ->
    Terms.

reduce_payment_refund_terms(PaymentRefundTerms, VS, DomainRevision) ->
    PaymentRefundTerms#domain_PaymentRefundsProvisionTerms{
        cash_flow = reduce_if_defined(
            PaymentRefundTerms#domain_PaymentRefundsProvisionTerms.cash_flow, VS, DomainRevision
        ),
        partial_refunds = pm_maybe:apply(
            fun(X) -> reduce_partial_refunds_terms(X, VS, DomainRevision) end,
            PaymentRefundTerms#domain_PaymentRefundsProvisionTerms.partial_refunds
        )
    }.

reduce_partial_refunds_terms(PartialRefundTerms, VS, DomainRevision) ->
    PartialRefundTerms#domain_PartialRefundsProvisionTerms{
        cash_limit = reduce_if_defined(
            PartialRefundTerms#domain_PartialRefundsProvisionTerms.cash_limit, VS, DomainRevision
        )
    }.

reduce_payment_chargeback_terms(PaymentChargebackTerms, VS, DomainRevision) ->
    PaymentChargebackTerms#domain_PaymentChargebackProvisionTerms{
        cash_flow = reduce_if_defined(
            PaymentChargebackTerms#domain_PaymentChargebackProvisionTerms.cash_flow, VS, DomainRevision
        )
    }.

reduce_recurrent_paytool_terms(RecurrentPaytoolTerms, VS, DomainRevision) ->
    RecurrentPaytoolTerms#domain_RecurrentPaytoolsProvisionTerms{
        cash_value = reduce_if_defined(
            RecurrentPaytoolTerms#domain_RecurrentPaytoolsProvisionTerms.cash_value, VS, DomainRevision
        ),
        categories = reduce_if_defined(
            RecurrentPaytoolTerms#domain_RecurrentPaytoolsProvisionTerms.categories, VS, DomainRevision
        ),
        payment_methods = reduce_if_defined(
            RecurrentPaytoolTerms#domain_RecurrentPaytoolsProvisionTerms.payment_methods, VS, DomainRevision
        )
    }.

merge_terms(
    #domain_ProvisionTermSet{
        payments           = PPayments,
        recurrent_paytools = PRecurrents,
        wallet             = PWallet
    },
    #domain_ProvisionTermSet{
        payments           = TPayments,
        recurrent_paytools = _TRecurrents,  % TODO: Allow to define recurrent terms in terminal
        wallet             = TWallet
    }
) ->
    #domain_ProvisionTermSet{
        payments           = merge_payment_terms(PPayments, TPayments),
        recurrent_paytools = PRecurrents,
        wallet             = merge_wallet_terms(PWallet, TWallet)
    };
merge_terms(ProviderTerms, TerminalTerms) ->
    pm_utils:select_defined(TerminalTerms, ProviderTerms).


merge_payment_terms(
    #domain_PaymentsProvisionTerms{
        currencies      = PCurrencies,
        categories      = PCategories,
        payment_methods = PPaymentMethods,
        cash_limit      = PCashLimit,
        cash_flow       = PCashflow,
        holds           = PHolds,
        refunds         = PRefunds,
        chargebacks     = PChargebacks
    },
    #domain_PaymentsProvisionTerms{
        currencies      = TCurrencies,
        categories      = TCategories,
        payment_methods = TPaymentMethods,
        cash_limit      = TCashLimit,
        cash_flow       = TCashflow,
        holds           = THolds,
        refunds         = TRefunds,
        chargebacks     = TChargebacks
    }
) ->
    #domain_PaymentsProvisionTerms{
        currencies      = pm_utils:select_defined(TCurrencies,     PCurrencies),
        categories      = pm_utils:select_defined(TCategories,     PCategories),
        payment_methods = pm_utils:select_defined(TPaymentMethods, PPaymentMethods),
        cash_limit      = pm_utils:select_defined(TCashLimit,      PCashLimit),
        cash_flow       = pm_utils:select_defined(TCashflow,       PCashflow),
        holds           = pm_utils:select_defined(THolds,          PHolds),
        refunds         = pm_utils:select_defined(TRefunds,        PRefunds),
        chargebacks     = pm_utils:select_defined(TChargebacks,    PChargebacks)
    };
merge_payment_terms(ProviderTerms, TerminalTerms) ->
    pm_utils:select_defined(TerminalTerms, ProviderTerms).

merge_wallet_terms(
    #domain_WalletProvisionTerms{
        turnover_limit = PLimit,
        withdrawals    = PWithdrawal,
        p2p            = PP2P
    },
    #domain_WalletProvisionTerms{
        turnover_limit = TLimit,
        withdrawals    = TWithdrawal,
        p2p            = TP2P
    }
) ->
    #domain_WalletProvisionTerms{
        turnover_limit = pm_utils:select_defined(TLimit, PLimit),
        withdrawals    = merge_withdrawal_terms(PWithdrawal, TWithdrawal),
        p2p            = merge_p2p_terms(PP2P, TP2P)
    };
merge_wallet_terms(ProviderTerms, TerminalTerms) ->
    pm_utils:select_defined(TerminalTerms, ProviderTerms).

merge_withdrawal_terms(
    #domain_WithdrawalProvisionTerms{
        currencies     = PCurrencies,
        payout_methods = PMethods,
        cash_limit     = PLimit,
        cash_flow      = PCashflow
    },
    #domain_WithdrawalProvisionTerms{
        currencies     = TCurrencies,
        payout_methods = TMethods,
        cash_limit     = TLimit,
        cash_flow      = TCashflow
    }
) ->
    #domain_WithdrawalProvisionTerms{
        currencies     = pm_utils:select_defined(TCurrencies, PCurrencies),
        payout_methods = pm_utils:select_defined(TMethods, PMethods),
        cash_limit     = pm_utils:select_defined(TLimit, PLimit),
        cash_flow      = pm_utils:select_defined(TCashflow, PCashflow)
    };
merge_withdrawal_terms(ProviderTerms, TerminalTerms) ->
    pm_utils:select_defined(TerminalTerms, ProviderTerms).

merge_p2p_terms(
    #domain_P2PProvisionTerms{
        currencies     = PCurrencies,
        cash_limit     = PLimit,
        cash_flow      = PCashflow,
        fees           = PFees
    },
    #domain_P2PProvisionTerms{
        currencies     = TCurrencies,
        cash_limit     = TLimit,
        cash_flow      = TCashflow,
        fees           = TFees
    }
) ->
    #domain_P2PProvisionTerms{
        currencies     = pm_utils:select_defined(TCurrencies, PCurrencies),
        cash_limit     = pm_utils:select_defined(TLimit, PLimit),
        cash_flow      = pm_utils:select_defined(TCashflow, PCashflow),
        fees           = pm_utils:select_defined(TFees, PFees)
    };
merge_p2p_terms(ProviderTerms, TerminalTerms) ->
    pm_utils:select_defined(TerminalTerms, ProviderTerms).

reduce_if_defined(Selector, VS, Rev) ->
    pm_maybe:apply(fun(X) -> pm_selector:reduce(X, VS, Rev) end, Selector).