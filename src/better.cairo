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

// From the execute interface
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

    // TMP: Convert `AccountCallArray` to 'Call'.
    let (calls: Call*) = alloc();
    _from_call_array_to_call(call_array_len, call_array, calldata, calls);
    let calls_len = call_array_len;

    let (offsets_len, offsets: felt*, response_len, response: felt*) = rec_execute(
        calls_len, calls
    );
    return (response_len, response);
}

func rec_execute{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
}(calls_len: felt, calls: Call*) -> (
    offsets_len: felt, offsets: felt*, response_len: felt, response: felt*
) {
    alloc_locals;
    if (calls_len == 0) {
        let (response) = alloc();
        let (offsets) = alloc();
        assert offsets[0] = 0;
        return (1, offsets, 0, response);
    }

    // call recursively all previous calls
    let (offsets_len, offsets: felt*, response_len, response: felt*) = rec_execute(
        calls_len - 1, calls
    );

    // handle the last call
    let last_call = calls[calls_len - 1];

    let (inputs: felt*) = alloc();
    compile_call_inputs(
        inputs, last_call.calldata_len, last_call.calldata, offsets, response
    );

    // call the last call
    let res = call_contract(
        contract_address=last_call.to,
        function_selector=last_call.selector,
        calldata_size=last_call.calldata_len,
        calldata=inputs,
    );

    // store response data
    memcpy(response + response_len, res.retdata, res.retdata_size);
    assert offsets[offsets_len] = res.retdata_size + offsets[offsets_len - 1];
    return (offsets_len + 1, offsets, response_len + res.retdata_size, response);
}

// Enumeration of possible CallData prefix
struct CallDataType {
    VALUE: felt,
    REF: felt,
    CALL_REF: felt,
    FUNC: felt,
    FUNC_CALL: felt,
}

func compile_call_inputs{syscall_ptr: felt*}(
    inputs: felt*,
    call_len,
    shifted_calldata: felt*,
    offsets: felt*,
    response: felt*,
) -> () {
    if (call_len == 0) {
        return ();
    }

    tempvar type = [shifted_calldata];
    if (type == CallDataType.VALUE) {
        // 1 -> value
        assert [inputs] = shifted_calldata[1];
        return compile_call_inputs(
            inputs + 1, call_len - 1, shifted_calldata + 2, offsets, response
        );
    }

    if (type == CallDataType.REF) {
        // 1 -> shift
        let shift = shifted_calldata[1];
        assert [inputs] = response[shift];
        return compile_call_inputs(
            inputs + 1, call_len - 1, shifted_calldata + 2, offsets, response
        );
    }

    if (type == CallDataType.CALL_REF) {
        // 1 -> call_id, 2 -> shift
        let call_id = shifted_calldata[1];
        let shift = shifted_calldata[2];
        let call_shift = offsets[call_id];

        let value = response[call_shift + shift];
        assert [inputs] = value;
        return compile_call_inputs(
            inputs + 1, call_len - 1, shifted_calldata + 3, offsets, response
        );
    }

    // should not be called (todo: put the default case)
    assert 1 = 0;
    ret;
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
