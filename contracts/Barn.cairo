%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.hash import hash2
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import (HashBuiltin, SignatureBuiltin)
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.math import (assert_le, assert_not_zero, unsigned_div_rem, split_felt)
from starkware.cairo.common.math_cmp import is_le_felt

struct SheepWolf:
    member isSheep    : felt  
    member fur        : felt
    member head       : felt
    member ears       : felt
    member eyes       : felt
    member nose       : felt
    member mouth      : felt
    member neck       : felt
    member feet       : felt
    member alphaIndex : felt
end

struct Stake:
    member tokenId   : felt
    member value   : felt
    member owner   : felt
    member traits  : SheepWolf
end

# miliseconds
const day = 86400000 

const MINIMUM_TO_EXIT = day * 2
const MAXIMUM_GLOBAL_WOOL = 2000
const DAILY_WOOL_RATE = 100
const WOOL_CLAIM_TAX_PERCENTAGE = 20

# maps tokenId to stake 
@storage_var
func barn(tokenId : felt) -> (stake : Stake):
end

# maps alpha to all Wolf stakes with that alpha
@storage_var
func pack(alpha : felt, index : felt) -> (stake : Stake):
end

# tracks location of each Wolf in Pack
@storage_var
func packIndices(tokenId : felt) -> (index : felt):
end

# stores number of wolves of each alpha
@storage_var
func packSize(alpha : felt) -> (len : felt):
end

# stores number of wolves of each alpha
@storage_var
func alpha(tokenId : felt) -> (len : felt):
end

# amount of $WOOL due for each alpha point staked
@storage_var
func woolPerAlpha() -> (_woolPerAlpha : felt):
end

# total alpha scores staked
@storage_var
func totalAlphaStaked() -> (_totalAlphaStaked : felt):
end

# any rewards distributed when no wolves are staked
@storage_var
func unaccountedRewards() -> (_unaccountedRewards : felt):
end

# number of Sheep staked in the Barn
@storage_var
func totalSheepStaked() -> (_totalSheepStaked : felt):
end

# amount of $WOOL earned so far
@storage_var
func totalWoolEarned() -> (_totalWoolEarned : felt):
end

# the last time $WOOL was claimed
@storage_var
func lastClaimTimestamp() -> (_lastClaimTimestamp : felt):
end

# stores each user's $WOOL balance
@storage_var
func userBalance(user : felt) -> (_userBalance : felt):
end


#TODO constructor

@view
func get_barn{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(tokenId : felt) -> (res : Stake):
    let (res) = barn.read(tokenId)
    return (res)
end

@view
func get_totalSheepStaked{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (res : felt):
    let (res) = totalSheepStaked.read()
    return (res)
end

@view
func get_totalAlphaStaked{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (res : felt):
    let (res) = totalAlphaStaked.read()
    return (res)
end

@view
func get_pack{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(tokenId : felt) -> (res : Stake):
    let (_alpha) = alpha.read(tokenId)
    let (index) = packIndices.read(tokenId)
    let (res) = pack.read(_alpha, index)
    return (res)
end

@view
func get_totalWoolEarned{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (res : felt):
    let (res) = totalWoolEarned.read()
    return (res)
end

@view
func get_lastClaimTimestamp{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (res : felt):
    let (res) = lastClaimTimestamp.read()
    return (res)
end


#handler?
@external
func register_contract{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}(
    from_address : felt,
    tokenId : felt,
    tokenTraits : SheepWolf,
    user : felt,
    time : felt):

    #check from_addres
    #assert from_address = L1_CONTRACT_ADDRESS

    #check if contract exists already
    let (stake) = barn.read(tokenId=tokenId)
    assert stake.tokenId = 0
    assert stake.value = 0
    assert stake.owner = 0

    #write contract
    if tokenTraits.isSheep == 1:
        barn.write(tokenId, Stake(tokenId=tokenId, value=time, owner=user, traits=tokenTraits))
        let (res) = totalSheepStaked.read()
        totalSheepStaked.write(res + 1)
    else:
        let (wool) = woolPerAlpha.read()
        let (len) = packSize.read(tokenTraits.alphaIndex)
        pack.write(tokenTraits.alphaIndex, len, Stake(tokenId=tokenId, value=wool, owner=user, traits=tokenTraits))
        packIndices.write(tokenId, len)
        packSize.write(tokenTraits.alphaIndex, len + 1)
        
        let (res) = totalAlphaStaked.read()
        totalAlphaStaked.write(res + tokenTraits.alphaIndex)

        alpha.write(tokenId, tokenTraits.alphaIndex)
    end
    
    return ()
end


#handler?
@external
func add_many_sheep_wolves{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}(
    from_address : felt,
    tokenIds_len : felt,
    tokenIds : felt*,
    tokenTraits_len : felt,
    tokenTraits : felt*,
    n : felt,
    user : felt,
    time : felt):

    if n == 0:
        return ()
    end

    #check from_addres
    #assert from_address = L1_CONTRACT_ADDRESS

    register_contract(from_address, tokenIds[0], SheepWolf(tokenTraits[0], tokenTraits[1], tokenTraits[2], tokenTraits[3], tokenTraits[4], tokenTraits[5], tokenTraits[6], tokenTraits[7], tokenTraits[8], tokenTraits[9]), user, time)
    add_many_sheep_wolves(from_address, tokenIds_len, tokenIds + 1, tokenTraits_len, tokenTraits + 10, n - 1, user, time)

    return ()
end


# realize $WOOL earnings for a single Sheep and optionally unstake it
# if not unstaking, pay a 20% tax to the staked Wolves
# if unstaking, there is a 50% chance all $WOOL is stolen
@external
func claim_sheep_from_barn{
    syscall_ptr : felt*,
    ecdsa_ptr : SignatureBuiltin*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}(
    unstake : felt,
    user : felt,
    time : felt,
    stake : Stake,
    owed : felt,
    tax : felt
    ):

    #TODO signature

    #check if sheep in barn
    assert_not_zero(stake.tokenId)
    assert_not_zero(stake.owner)
    assert_not_zero(stake.value)

    # sheep need to be in barn at least 2 days
    # assert_le((time - stake.value - MINIMUM_TO_EXIT) * staked, 0)
    
    payWolfTax(tax)

    if unstake == 1:
        # TODODODO send mesage to L1
        
        # delete sheep from barn
        barn.write(stake.tokenId, Stake(tokenId=0, value=0, owner=0, traits=SheepWolf(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
        let (res) = totalSheepStaked.read()
        totalSheepStaked.write(res - 1)
    else:
        # reset sheep's value to current timestamp
        barn.write(stake.tokenId, Stake(tokenId=stake.tokenId, value=time, owner=stake.owner, traits=stake.traits))
    end

    # add owed amount to user's wallet
    let (_userBalance) = userBalance.read(user)
    userBalance.write(user, _userBalance + owed)

    return ()
end


# realize $WOOL earnings for a single Wolf and optionally unstake it
# Wolves earn $WOOL proportional to their Alpha rank
@external
func claim_wolf_from_pack{
    syscall_ptr : felt*,
    ecdsa_ptr : SignatureBuiltin*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}(
    tokenId : felt,
    unstake : felt,
    user : felt
    ):

    # check if wolf in pack
    let (_alpha) = alpha.read(tokenId)
    let (index) = packIndices.read(tokenId)
    let (stake) = pack.read(_alpha, index)
    assert_not_zero(stake.tokenId)
    assert_not_zero(stake.owner)
    assert stake.owner = user

    # TODO signature

    # Calculate portion of tokens based on Alpha
    let (_woolPerAlpha) = woolPerAlpha.read()
    # add owed amount to user's wallet
    let (_userBalance) = userBalance.read(user)
    userBalance.write(user, _alpha * (_woolPerAlpha - stake.value))

    let (len) = packSize.read(_alpha)
    let (lastStake) = pack.read(_alpha, len)
    if unstake == 1:
        # Remove Alpha from total staked
        let (_totalAlphaStaked) = totalAlphaStaked.read()
        totalAlphaStaked.write(_totalAlphaStaked - _alpha)

        # TODODODO send mesage to L1 - send wolf NFT back to user

        # Shuffle last Wolf to current position
        pack.write(_alpha, index, lastStake)
        pack.write(_alpha, len, Stake(tokenId=0, value=0, owner=0, traits=SheepWolf(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
        packSize.write(_alpha, len - 1)
        packIndices.write(lastStake.tokenId, index)
    else:
        pack.write(_alpha, index, Stake(tokenId=stake.tokenId, value=_woolPerAlpha, owner=stake.owner, traits=stake.traits))
    end

    return ()
end


@external
func claim_many_wolves{
    syscall_ptr : felt*,
    ecdsa_ptr : SignatureBuiltin*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}(
    from_address : felt,
    tokenIds_len : felt,
    tokenIds : felt*,
    unstakes_len : felt,
    unstakes : felt*,
    n : felt,
    user : felt
    ):

    if n == 0:
        return ()
    end

    #check from_addres
    #assert from_address = L1_CONTRACT_ADDRESS

    claim_wolf_from_pack(tokenIds[0], unstakes[0], user)
    claim_many_wolves(from_address, tokenIds_len, tokenIds + 1, unstakes_len, unstakes + 1, n - 1, user)

    return ()
end


# add $WOOL to claimable pot for the Pack
func payWolfTax{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}(
    amount : felt):

    let (_totalAlphaStaked) = totalAlphaStaked.read()
    let (_unaccountedRewards) = unaccountedRewards.read()
    # if there's no staked wolves
    if _totalAlphaStaked == 0:
        # keep track of $WOOL due to wolves
        unaccountedRewards.write(_unaccountedRewards + amount)
    else:
        # makes sure to include any unaccounted $WOOL
        let (_woolPerAlpha) = woolPerAlpha.read()
        let (q, r) = unsigned_div_rem(amount + _unaccountedRewards, _totalAlphaStaked)
        woolPerAlpha.write(_woolPerAlpha + q)
        unaccountedRewards.write(r)
    end

    return ()
end
