%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.invoke import invoke

from src.main import execute, AccountCallArray
from tests.example.interface import NFT, ExampleContract

@external
func __setup__() {
    %{ context.example_contract = deploy_contract("./tests/example/contract.cairo", []).contract_address %}
    return ();
}

@external
func test_example_contract{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    tempvar example_contract_addr;
    %{
        ids.example_contract_addr = context.example_contract 
        stop_prank_callable = start_prank(123, context.example_contract)
    %}

    let (minted_nft_id) = ExampleContract.mint_nft(example_contract_addr);
    ExampleContract.set_nft_name(example_contract_addr, minted_nft_id, 'aloha');
    let (nft: NFT) = ExampleContract.read_nft(example_contract_addr, minted_nft_id);

    assert nft.owner = 123;
    assert nft.name = 'aloha';

    %{ stop_prank_callable() %}

    return ();
}

@external
func test_through_account_singlecall{
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

    // 1st tx: minting the nft
    let (result_len, result: felt*) = execute(
        1, new (AccountCallArray(example_contract_addr, mint_nft_selector, 0, 0)), 0, new ()
    );
    assert result_len = 1;
    local minted_nft = result[0];

    // 2nd tx: changing nft name
    let (result_len, result: felt*) = execute(
        1,
        new (AccountCallArray(example_contract_addr, set_nft_name_selector, 0, 2)),
        2,
        new (minted_nft, 'aloha'),
    );
    assert result_len = 0;

    let (nft: NFT) = ExampleContract.read_nft(example_contract_addr, minted_nft);

    assert nft.owner = 123;
    assert nft.name = 'aloha';

    return ();
}

@external
func test_through_account_multicall{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    return ();
}
