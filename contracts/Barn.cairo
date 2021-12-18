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
func get_stake{
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
        range_check_ptr}(alpha : felt, index : felt) -> (res : Stake):
    let (res) = pack.read(alpha, index)
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
    owner : felt,
    time : felt):

    #check from_addres
    #assert from_address = L1_CONTRACT_ADDRESS

    #check if contract exists already
    let (stake) = barn.read(tokenId=tokenId)
    assert stake.value = 0
    assert stake.owner = 0


    #write contract
    if tokenTraits.isSheep == 1:
        barn.write(tokenId, Stake(value=time, owner=owner, traits=tokenTraits))
        let (res) = totalSheepStaked.read()
        totalSheepStaked.write(res + 1)
    else:
        let (wool) = woolPerAlpha.read()
        let (len) = packSize.read(tokenTraits.alphaIndex)
        pack.write(tokenTraits.alphaIndex, len, Stake(value=wool, owner=owner, traits=tokenTraits))
        packIndices.write(tokenId, len)
        packSize.write(tokenTraits.alphaIndex, len + 1)
        
        let (res) = totalAlphaStaked.read()
        totalAlphaStaked.write(res + tokenTraits.alphaIndex)
    end                 
    
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
    tokenId : felt,
    staked : felt,
    user : felt,
    time : felt,
    stake : Stake,
    owed : felt,
    tax : felt
    ):

    #TODO signature

    #check if sheep in barn
    assert_not_zero(stake.owner)
    assert_not_zero(stake.value)

    #sheep need to be in barn at least 2 days
    # assert_le((time - stake.value - MINIMUM_TO_EXIT) * staked, 0)

    # add owed amount to user's wallet
    let (_userBalance) = userBalance.read(user)
    userBalance.write(user, owed)
    
    payWolfTax(tax)

    if staked == 0:
        # TODODODO send mesage to L1
        
        # delete sheep from barn
        barn.write(tokenId, Stake(value=0, owner=0, traits=SheepWolf(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
        let (res) = totalSheepStaked.read()
        totalSheepStaked.write(res - 1)

    else:
        # reset sheep's value to current timestamp
        barn.write(tokenId, Stake(value=time, owner=stake.owner, traits=stake.traits))
    end

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
