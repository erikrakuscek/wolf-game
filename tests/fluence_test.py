import os
import pytest
import time
import random

from starkware.starknet.testing.starknet import Starknet

def current_milli_time():
    return round(time.time() * 1000)

MAXIMUM_GLOBAL_WOOL = 2000
DAILY_WOOL_RATE = 100
DAY = 86400000 
WOOL_CLAIM_TAX_PERCENTAGE = 20

# The path to the contract source code.
CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/Barn.cairo")

# The testing library uses python's asyncio. So the following
# decorator and the ``async`` keyword are needed.
@pytest.mark.asyncio
async def test_register_contract():
    # Create a new Starknet class that simulates the StarkNet
    # system.
    global starknet
    starknet = await Starknet.empty()

    # Deploy the contract.
    global contract
    contract = await starknet.deploy(
        source=CONTRACT_FILE,
    )
    print("------TESTING register_contract--------")
    # Register new contract
    sw = (1, 200, 100, 150, 166, 15, 10, 8, 10, 5)
    await contract.register_contract(from_address=10101, tokenId=1, tokenTraits=sw, owner=4343, time=current_milli_time()).invoke()
    # Check results.
    execution_info = await contract.get_barn(tokenId=1).call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)
    
    
    # Register new contract.
    await contract.register_contract(from_address=122221, tokenId=2, tokenTraits=sw, owner=23232, time=current_milli_time()).invoke()
    # Check results.
    execution_info = await contract.get_barn(tokenId=2).call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)

    # Register new contract.
    sw = (0, 200, 100, 150, 166, 15, 10, 8, 10, 5)
    await contract.register_contract(from_address=45454, tokenId=3, tokenTraits=sw, owner=23232, time=current_milli_time()).invoke()
    # Check results.
    execution_info = await contract.get_pack(tokenId=3).call()
    print(execution_info.result)
    execution_info = await contract.get_totalAlphaStaked().call()
    print(execution_info.result)

    # Register new contract.
    await contract.register_contract(from_address=1112222, tokenId=4, tokenTraits=sw, owner=1212, time=current_milli_time()).invoke()
    # Check results.
    execution_info = await contract.get_pack(tokenId=4).call()
    print(execution_info.result)
    execution_info = await contract.get_totalAlphaStaked().call()
    print(execution_info.result)


@pytest.mark.asyncio
async def test_claim_sheep_from_barn():
    print("------TESTING claim_sheep_from_barn--------")

    time = current_milli_time()
    totalWoolEarned = (await contract.get_totalWoolEarned().call()).result.res
    stake = (await contract.get_barn(tokenId=1).call()).result.res
    lastClaimTimestamp = (await contract.get_lastClaimTimestamp().call()).result.res
    owed = 0
    tax = 0
    random.seed(time+totalWoolEarned+lastClaimTimestamp)
    rnd = random.randint(0,9)

    if totalWoolEarned < MAXIMUM_GLOBAL_WOOL:
        # calculates how much $WOOL user is owed
        owed,_ = divmod((time - stake.value) * DAILY_WOOL_RATE, DAY)
    elif lastClaimTimestamp < stake.value:
        # $WOOL production stopped already
        owed = 0
    else:
        # stop earning additional $WOOL if it's all been earned
        owed,_ = divmod((lastClaimTimestamp - stake.value) * DAILY_WOOL_RATE, DAY)

    # 50% chance that wolf gets all $WOOL
    if rnd % 2 == 0:
        tax += owed
        owed = 0
    else:
        tax,_ = divmod(owed * WOOL_CLAIM_TAX_PERCENTAGE, 100)
        owed -= tax 
            

    await contract.claim_sheep_from_barn(unstake=0, user=123, 
                time=time, stake=stake, owed=owed, tax=tax).invoke()

    execution_info = await contract.get_barn(tokenId=1).call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)
    
    await contract.claim_sheep_from_barn(unstake=1, user=123, 
                time=time, stake=stake, owed=owed, tax=tax).invoke()

    execution_info = await contract.get_barn(tokenId=2).call()
    print(execution_info.result)
    execution_info = await contract.get_totalSheepStaked().call()
    print(execution_info.result)


@pytest.mark.asyncio
async def test_claim_wolf_from_pack():
    print("------TESTING claim_wolf_from_pack--------")

    await contract.claim_wolf_from_pack(tokenId=3, unstake=0, user=23232).invoke()

    execution_info = await contract.get_pack(tokenId=3).call()
    print(execution_info.result)
    execution_info = await contract.get_totalAlphaStaked().call()
    print(execution_info.result)
    
    await contract.claim_wolf_from_pack(tokenId=4, unstake=1, user=1212).invoke()

    execution_info = await contract.get_pack(tokenId=4).call()
    print(execution_info.result)
    execution_info = await contract.get_totalAlphaStaked().call()
    print(execution_info.result)

    try:
        await contract.claim_wolf_from_pack(tokenId=3, unstake=0, user=1).invoke()
    except:
        print('OK')

