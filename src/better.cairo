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

struct Type {
    DEFAULT: felt,
    REFERENCE: felt,
}

// if type is default, data is a value,
// otherwise it's an index in output
struct Felt {
    type: felt,
    data: felt,
}

struct BetterCall {
    to: felt,
    selector: felt,
    calldata_len: felt,
    calldata: Felt*,
}

// Tmp struct introduced while we wait for Cairo
// to support passing `[AccountCall]` to __execute__
struct AccountCallArray {
    to: felt,
    selector: felt,
    data_offset: felt,
    data_len: felt,
}

// call_array:
// { contrat, function, offset : 0, taille : 2 }
// { contrat, function, offset : 2, taille : 3 }
// calldata:
// [ a, b, c, d, e]

func better_execute{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
}(call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: Felt*) -> (
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
    let (calls: BetterCall*) = alloc();
    _better_from_call_array_to_call(call_array_len, call_array, calldata, calls);
    let calls_len = call_array_len;

    // execute call
    let (response: felt*) = alloc();
    let (response_len) = _better_execute_list(calls_len, calls, 0, response);

    return (response_len=response_len, response=response);
}

func _better_from_call_array_to_call{syscall_ptr: felt*}(
    call_array_len: felt, call_array: AccountCallArray*, calldata: Felt*, calls: BetterCall*
) {
    // if no more calls
    if (call_array_len == 0) {
        return ();
    }

    // parse the current call
    assert [calls] = BetterCall(
        to=[call_array].to,
        selector=[call_array].selector,
        calldata_len=[call_array].data_len,
        calldata=calldata + [call_array].data_offset
        );

    // parse the remaining calls recursively
    _better_from_call_array_to_call(
        call_array_len - 1, call_array + AccountCallArray.SIZE, calldata, calls + BetterCall.SIZE
    );
    return ();
}

func _better_execute_list{syscall_ptr: felt*}(
    calls_len: felt, calls: BetterCall*, response_len, response: felt*
) -> (response_len: felt) {
    alloc_locals;

    // if no more calls
    if (calls_len == 0) {
        return (response_len=response_len);
    }

    // do the current call
    let this_call: BetterCall = [calls];

    // write calldata
    let (calldata) = alloc();
    write_calldata(calldata, this_call.calldata_len, this_call.calldata, response);

    let res = call_contract(
        contract_address=this_call.to,
        function_selector=this_call.selector,
        calldata_size=this_call.calldata_len,
        calldata=calldata,
    );

    let yolo = res.retdata_size;

    // copy the result in response
    memcpy(response + response_len, res.retdata, res.retdata_size);
    // do the next calls recursively
    return _better_execute_list(
        calls_len - 1, calls + BetterCall.SIZE, response_len + res.retdata_size, response
    );
}

func write_calldata{syscall_ptr: felt*}(
    calldata: felt*, len: felt, dynamic_calldata: Felt*, response: felt*
) {
    if (len == 0) {
        return ();
    }

    tempvar id = len - 1;
    let to_add: Felt = dynamic_calldata[id];

    if (to_add.type == Type.DEFAULT) {
        assert calldata[id] = to_add.data;
        return write_calldata(calldata, id, dynamic_calldata, response);
    } else {
        assert calldata[id] = response[to_add.data];
        return write_calldata(calldata, id, dynamic_calldata, response);
    }
}
