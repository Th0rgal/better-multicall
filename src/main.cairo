%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    call_contract,
    get_caller_address,
    get_contract_address,
    get_tx_info,
)

struct Call {
    to: felt,
    selector: felt,
    calldata_len: felt,
    calldata: felt*,
}

// Tmp struct introduced while we wait for Cairo
// to support passing `[AccountCall]` to __execute__
struct AccountCallArray {
    to: felt,
    selector: felt,
    data_offset: felt,
    data_len: felt,
}

func execute{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
}(call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*) -> (
    response_len: felt, response: felt*
) {
    alloc_locals;

    let (tx_info) = get_tx_info();
    with_attr error_message("Account: invalid tx version") {
        assert tx_info.version = 1;
    }

    // assert not a reentrant call
    let (caller) = get_caller_address();
    with_attr error_message("Account: no reentrant call") {
        assert caller = 0;
    }

    // TMP: Convert `AccountCallArray` to 'Call'.
    let (calls: Call*) = alloc();
    _from_call_array_to_call(call_array_len, call_array, calldata, calls);
    let calls_len = call_array_len;

    // execute call
    let (response: felt*) = alloc();
    let (response_len) = _execute_list(calls_len, calls, response);

    return (response_len=response_len, response=response);
}

func _from_call_array_to_call{syscall_ptr: felt*}(
    call_array_len: felt, call_array: AccountCallArray*, calldata: felt*, calls: Call*
) {
    // if no more calls
    if (call_array_len == 0) {
        return ();
    }

    // parse the current call
    assert [calls] = Call(
        to=[call_array].to,
        selector=[call_array].selector,
        calldata_len=[call_array].data_len,
        calldata=calldata + [call_array].data_offset
        );
    // parse the remaining calls recursively
    _from_call_array_to_call(
        call_array_len - 1, call_array + AccountCallArray.SIZE, calldata, calls + Call.SIZE
    );
    return ();
}

func _execute_list{syscall_ptr: felt*}(calls_len: felt, calls: Call*, response: felt*) -> (
    response_len: felt
) {
    alloc_locals;

    // if no more calls
    if (calls_len == 0) {
        return (response_len=0);
    }

    // do the current call
    let this_call: Call = [calls];
    let res = call_contract(
        contract_address=this_call.to,
        function_selector=this_call.selector,
        calldata_size=this_call.calldata_len,
        calldata=this_call.calldata,
    );
    // copy the result in response
    memcpy(response, res.retdata, res.retdata_size);
    // do the next calls recursively
    let (response_len) = _execute_list(
        calls_len - 1, calls + Call.SIZE, response + res.retdata_size
    );
    return (response_len=response_len + res.retdata_size);
}
