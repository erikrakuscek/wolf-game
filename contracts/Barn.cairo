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


const time1 = 1
const time2 = 100
const day = 24
const lastClaimTimestamp = 20
const MINIMUM_TO_EXIT = 50
const MAXIMUM_GLOBAL_WOOL = 2000
const DAILY_WOOL_RATE = 10000
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


@external
func register_contract{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}(
    from_address : felt,
    tokenId : felt,
    tokenTraits : SheepWolf,
    owner : felt):

    #check from_addres
    #assert from_address = L1_CONTRACT_ADDRESS

    #check if contract exists already
    let (stake) = barn.read(tokenId=tokenId)
    assert stake.value = 0
    assert stake.owner = 0


    #write contract
    if tokenTraits.isSheep == 1:
        #TODO fix value to block timestamp
        barn.write(tokenId, Stake(value=time1, owner=owner, traits=tokenTraits))
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

@external
func claim_sheep_from_barn{
    syscall_ptr : felt*,
    ecdsa_ptr : SignatureBuiltin*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}(
    tokenId : felt,
    staked : felt,
    user : felt):

    alloc_locals 
    local owed

    #TODO signature

    #check if sheep in barn
    let (stake) = barn.read(tokenId=tokenId)
    assert_not_zero(stake.owner)
    assert_not_zero(stake.value)

    #sheep need to be in barn at least 2 days
    if staked == 1:
        assert_le(1, time2 - stake.value - MINIMUM_TO_EXIT)
        tempvar range_check_ptr = range_check_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        tempvar range_check_ptr = range_check_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end

    let (_totalWoolEarned) = totalWoolEarned.read()
    let (check_lt) = is_le_felt(_totalWoolEarned, MAXIMUM_GLOBAL_WOOL)
    if check_lt == 1:
        let(q,r) = unsigned_div_rem((time2 - stake.value) * DAILY_WOOL_RATE, day)
        owed = q
        tempvar range_check_ptr = range_check_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        let (check_lt) = is_le_felt(lastClaimTimestamp, stake.value)
        if check_lt == 1:
            owed = 0
            tempvar range_check_ptr = range_check_ptr
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
        else:
            let(q,r) = unsigned_div_rem((lastClaimTimestamp - stake.value) * DAILY_WOOL_RATE, day)
            owed = q
            tempvar range_check_ptr = range_check_ptr
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
        end
        tempvar range_check_ptr = range_check_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end
    tempvar range_check_ptr = range_check_ptr
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr

    if staked == 0:
        let (inputs : felt*) = alloc()
        assert inputs[0] = tokenId
        assert inputs[1] = time2
        assert inputs[2] = user
        assert inputs[3] = stake.value
        assert inputs[4] = stake.owner
        let (random) = random_number(5, inputs)
        let (q, r) = unsigned_div_rem(random, 2)
        if r == 0:
            payWolfTax(owed * 100)

            # TODO: set owed amount for user (write storage variable) = 0

            tempvar range_check_ptr = range_check_ptr
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
        else:
            tempvar range_check_ptr = range_check_ptr
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
        end
        # TODODODO
        # let (payload : felt*) = alloc()
        # assert payload[0] = WITHDRAW
        # assert payload[1] = address
        # assert payload[2] = amountOrId
        # assert payload[3] = contract
        # send_message_to_l1(
        #     to_address=L1_CONTRACT_ADDRESS,
        #     payload_size=4,
        #     payload=payload)
        
        # delete sheep from barn
        barn.write(tokenId, Stake(value=0, owner=0, traits=SheepWolf(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
        let (res) = totalSheepStaked.read()
        totalSheepStaked.write(res - 1)
        tempvar range_check_ptr = range_check_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        let (q, r) = unsigned_div_rem(owed * WOOL_CLAIM_TAX_PERCENTAGE, 100)
        payWolfTax(q)

        # TODO: set owed amount for user (write storage variable) = owed - q

        barn.write(tokenId, Stake(value=time2, owner=stake.owner, traits=stake.traits))
        tempvar range_check_ptr = range_check_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end

    return ()
end

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
        tempvar range_check_ptr = range_check_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        # makes sure to include any unaccounted $WOOL
        let (_woolPerAlpha) = woolPerAlpha.read()
        let (q, r) = unsigned_div_rem(amount + _unaccountedRewards, _totalAlphaStaked)
        woolPerAlpha.write(_woolPerAlpha + q)
        unaccountedRewards.write(r)
        tempvar range_check_ptr = range_check_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end

    return ()
end

func random_number{
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}(
    n : felt, inputs : felt*) -> (
    result : felt):

    if n == 1:
        let (res) = hash2{hash_ptr=pedersen_ptr}(inputs[0], 0)
        return (result=res)
    end

    let (res) = random_number(n - 1, inputs + 1)
    let (res) = hash2{hash_ptr=pedersen_ptr}(inputs[0], res)

    # Avoid too large random number for division
    let (left, right) = split_felt(res)
    return (result=right)
end