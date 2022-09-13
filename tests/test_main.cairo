%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin

from src.main import execute
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
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    return ();
}

@external
func test_through_account_multicall{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    return ();
}
