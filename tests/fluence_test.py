import os
import pytest

from starkware.starknet.testing.starknet import Starknet

# The path to the contract source code.
CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/Barn.cairo")

# The testing library uses python's asyncio. So the following
# decorator and the ``async`` keyword are needed.
@pytest.mark.asyncio
async def test_register_contract():
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(
        source=CONTRACT_FILE,
    )
    print("------TESTING register_contract--------")
    # Register new contract
    sw = (1, 200, 100, 150, 166, 15, 10, 8, 10, 5)
    await contract.register_contract(from_address=10101, tokenId=1, tokenTraits=sw, owner=4343).invoke()
    # Check results.
    execution_info = await contract.get_stake(tokenId=1).call()
    print(execution_info.result)
    execution_info = await contract.get_totalAlphaStaked().call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)
    
    
    # Register new contract.
    await contract.register_contract(from_address=122221, tokenId=2, tokenTraits=sw, owner=23232).invoke()
    # Check results.
    execution_info = await contract.get_stake(tokenId=2).call()
    print(execution_info.result)
    execution_info = await contract.get_totalAlphaStaked().call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)

    # Register new contract.
    sw = (0, 200, 100, 150, 166, 15, 10, 8, 10, 5)
    await contract.register_contract(from_address=45454, tokenId=3, tokenTraits=sw, owner=23232).invoke()
    # Check results.
    execution_info = await contract.get_pack(alpha=5, index=0).call()
    print(execution_info.result)
    execution_info = await contract.get_totalAlphaStaked().call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)

    # Register new contract.
    await contract.register_contract(from_address=1112222, tokenId=4, tokenTraits=sw, owner=1212).invoke()
    # Check results.
    execution_info = await contract.get_pack(alpha=5, index=1).call()
    print(execution_info.result)
    execution_info = await contract.get_totalAlphaStaked().call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)


@pytest.mark.asyncio
async def test_claim_sheep_from_barn():
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(
        source=CONTRACT_FILE,
    )
    print("------TESTING claim_sheep_from_barn--------")

    sw = (1, 200, 100, 150, 166, 15, 10, 8, 10, 5)
    await contract.register_contract(from_address=10101, tokenId=1, tokenTraits=sw, owner=4343).invoke()
    # Check results.
    execution_info = await contract.get_stake(tokenId=1).call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)

    # Register new contract.
    await contract.register_contract(from_address=122221, tokenId=2, tokenTraits=sw, owner=23232).invoke()
    # Check results.
    execution_info = await contract.get_stake(tokenId=2).call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)

    await contract.claim_sheep_from_barn(tokenId=1, staked=1, user=123).invoke()

    execution_info = await contract.get_stake(tokenId=1).call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)

    await contract.claim_sheep_from_barn(tokenId=2, staked=0, user=123).invoke()

    execution_info = await contract.get_stake(tokenId=2).call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)

