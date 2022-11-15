%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.invoke import invoke

from src.better import execute, AccountCallArray, CallDataType
from tests.example.interface import NFT, ExampleContract

@external
func __setup__() {
    %{ context.example_contract = deploy_contract("./tests/example/contract.cairo", []).contract_address %}
    return ();
}

@external
func test_simple_ref{
    syscall_ptr: felt*,
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
}() {
    alloc_locals;
    local example_contract_addr;
    local mint_nft_selector;
    local set_nft_name_selector;
    %{
        from starkware.starknet.compiler.compile import get_selector_from_name

        ids.example_contract_addr = context.example_contract 
        ids.mint_nft_selector = get_selector_from_name("mint_nft")
        ids.set_nft_name_selector = get_selector_from_name("set_nft_name")

        stop_prank_callable = start_prank(123, context.example_contract)
    %}

    let (calldata: felt*) = alloc();
    assert calldata[0] = CallDataType.REF;
    assert calldata[1] = 0;
    assert calldata[2] = CallDataType.VALUE;
    assert calldata[3] = 'aloha';

    let (callarray: AccountCallArray*) = alloc();
    assert callarray[0] = AccountCallArray(example_contract_addr, mint_nft_selector, 0, 0);
    assert callarray[1] = AccountCallArray(example_contract_addr, set_nft_name_selector, 0, 2);

    let (result_len, result: felt*) = execute(2, callarray, 2, calldata);

    assert result_len = 1;
    let minted_nft = result[0];
    let (nft: NFT) = ExampleContract.read_nft(example_contract_addr, minted_nft);

    assert nft.owner = 123;
    assert nft.name = 'aloha';

    return ();
}

@external
func test_ref_to_specific_call{
    syscall_ptr: felt*,
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
}() {
    alloc_locals;
    local example_contract_addr;
    local get_bullshit_selector;
    local mint_nft_selector;
    local set_nft_name_selector;
    %{
        from starkware.starknet.compiler.compile import get_selector_from_name

        ids.example_contract_addr = context.example_contract 
        ids.get_bullshit_selector = get_selector_from_name("get_bullshit")
        ids.mint_nft_selector = get_selector_from_name("mint_nft")
        ids.set_nft_name_selector = get_selector_from_name("set_nft_name")

        stop_prank_callable = start_prank(123, context.example_contract)
    %}

    let (calldata: felt*) = alloc();
    assert calldata[0] = CallDataType.CALL_REF;
    assert calldata[1] = 1;  // we want to get data from second call
    assert calldata[2] = 0;  // at index 0
    assert calldata[3] = CallDataType.VALUE;
    assert calldata[4] = 'aloha';

    let (callarray: AccountCallArray*) = alloc();
    assert callarray[0] = AccountCallArray(example_contract_addr, get_bullshit_selector, 0, 0);
    assert callarray[1] = AccountCallArray(example_contract_addr, mint_nft_selector, 0, 0);
    assert callarray[2] = AccountCallArray(example_contract_addr, set_nft_name_selector, 0, 2);

    let (result_len, result: felt*) = execute(3, callarray, 5, calldata);
    assert result_len = 5;

    let minted_nft = result[result_len - 1];
    let (nft: NFT) = ExampleContract.read_nft(example_contract_addr, minted_nft);

    assert nft.owner = 123;
    assert nft.name = 'aloha';

    return ();
}
