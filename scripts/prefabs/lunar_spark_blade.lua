 local assets = {
    Asset("ANIM", "anim/lunar_spark_blade.zip"),
}

local prefabs =
{
    "hitsparks_fx",
}

------------------------------------------------------------------------------------------------------------------------

local function ReticuleTargetFn()
    --Cast range is 8, leave room for error (6.5 lunge)
    return Vector3(ThePlayer.entity:LocalToWorldSpace(6.5, 0, 0))
end

local function ReticuleMouseTargetFn(inst, mousepos)
    if mousepos ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        local dx = mousepos.x - x
        local dz = mousepos.z - z
        local l = dx * dx + dz * dz
        if l <= 0 then
            return inst.components.reticule.targetpos
        end
        l = 6.5 / math.sqrt(l)
        return Vector3(x + dx * l, 0, z + dz * l)
    end
end

local function ReticuleUpdatePositionFn(inst, pos, reticule, ease, smoothing, dt)
    local x, y, z = inst.Transform:GetWorldPosition()
    reticule.Transform:SetPosition(x, 0, z)
    local rot = -math.atan2(pos.z - z, pos.x - x) / DEGREES
    if ease and dt ~= nil then
        local rot0 = reticule.Transform:GetRotation()
        local drot = rot - rot0
        rot = Lerp((drot > 180 and rot0 + 360) or (drot < -180 and rot0 - 360) or rot0, rot, dt * smoothing)
    end
    reticule.Transform:SetRotation(rot)
end

------------------------------------------------------------------------------------------------------------------------


local function CheckSwapAnims(inst, owneroverride)
    local owner = owneroverride or inst.components.inventoryitem.owner
    if owner and inst.components.equippable:IsEquipped() then
        for _, v in pairs(inst.anim_fxs) do
            v:Show()
            v.entity:SetParent(owner.entity)
            v.components.highlightchild:SetOwner(owner)
            if owner.components.colouradder ~= nil then
                owner.components.colouradder:AttachChild(v)
            end
        end

        inst.anim_fxs[1].Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, 0, 3)
        inst.anim_fxs[2].Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, 5, 8)
    else
        for _, v in pairs(inst.anim_fxs) do
            v:Hide()
            v.entity:SetParent(inst.entity)
            v.Follower:FollowSymbol(inst.GUID, "lunar_spark_blade", nil, nil, nil, true)
            v.components.highlightchild:SetOwner(inst)
            if owner then
                if owner.components.colouradder ~= nil then
                    owner.components.colouradder:DetachChild(v)
                end
            end
        end
    end
end

local function onequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_object")
    CheckSwapAnims(inst)

    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    inst._owner:set(owner)

    if inst.increase_charge_task then
        inst.increase_charge_task:Cancel()
    end
    inst.increase_charge_task = inst:DoPeriodicTask(0, function()
        inst.components.dc_chargeable_item:DoDelta(FRAMES * 0.2)
    end)
end

local function onunequip(inst, owner)
    CheckSwapAnims(inst)

    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    inst._owner:set(nil)
    if inst.increase_charge_task then
        inst.increase_charge_task:Cancel()
        inst.increase_charge_task = nil
    end
end

local function OnChargeValChange(inst, old, new)
    if inst.components.dc_chargeable_item:GetPercent() >= 0.6 then
        inst._leap_range:set(1.9)
        inst.components.weapon:SetRange(10, 0)
    else
        inst._leap_range:set(-1)
        inst.components.weapon:SetRange(0)
    end
end

local function OnFinished(inst)
        local min_speed = 0
        local max_speed = 2
        local y_speed = 8
        local y_speed_variance = 4
        local pt = inst:GetPosition()  -- 获取生物的位置作为掉落位置
    local extra_items = {"security_pulse_cage"} -- 额外的物品列表
    for _, prefab in ipairs(extra_items) do
        local loot = SpawnPrefab(prefab)
        if loot then
            -- 设置投掷目标点和方差
            local fling_target_pt = pt + Vector3(math.random(-1, 1), 0, math.random(-1, 1))  -- 设置一个随机的目标点
            loot.Transform:SetPosition(pt:Get())
            -- 投掷额外的物品
            local fling_speed = 5  -- 设置投掷速度
            local fling_y_speed = 8  -- 设置投掷高度
        if loot.Physics ~= nil then
            local angle = 10
            local speed = 2
                local sinangle = math.sin(angle)
                local cosangle = math.cos(angle)
                loot.Physics:SetVel(speed * cosangle, GetRandomWithVariance(y_speed, y_speed_variance), speed * -sinangle)
            end
        end
    end
    inst:Remove()
end

local function GetDamage(inst, attacker, target)
    local base_dmg = 68
    local leap_dmg = base_dmg * 2
    return (attacker.sg and attacker.sg.currentstate.name == "lunar_spark_blade_leap") and leap_dmg or base_dmg
end

local function OnAttack(inst, attacker, target)
    if attacker.sg and attacker.sg.currentstate.name == "lunar_spark_blade_leap" then
        inst.components.dc_chargeable_item:DoDelta(-8)
    else
        inst.components.dc_chargeable_item:DoDelta(1)
    end

    if target ~= nil and target:IsValid() then
        SpawnPrefab("hitsparks_fx"):Setup(attacker, target)
    end
end

local function SpellFn(inst, caster, pos)
    caster:PushEvent("combat_lunge", { targetpos = pos, weapon = inst })
end

local function OnLunged(inst, doer, startingpos, targetpos)
    -- Lightning fx towards targetpos
    local fx = SpawnPrefab("spear_wathgrithr_lightning_lunge_fx")
    fx.Transform:SetPosition(targetpos:Get())
    fx.Transform:SetRotation(doer:GetRotation())

    -- Change weapon skill cd at here
    inst.components.rechargeable:Discharge(3)
end

local function OnLungedHit(inst, doer, target)

end

-------------------------------------------------------------
local function OnHit(self, doer, target)
    if self.onprehitfn ~= nil then
        self.onprehitfn(self.inst, doer, target)
    end

    local targetisworkable = false
    if target.components.workable then
        local work_action = target.components.workable:GetWorkAction()

        --V2C: nil action for NPC_workable (e.g. campfires)
        targetisworkable =
            (   not work_action and target:HasTag("NPC_workable")    ) or
            (   target.components.workable:CanBeWorked() and
                self.workactions[work_action] and
                (   work_action ~= ACTIONS.DIG or
                    (   target.components.spawner == nil and target.components.childspawner == nil  )
                )
            )
    end

    local did_hit = false
    if targetisworkable then
        target.components.workable:Destroy(doer)
        if target:IsValid() and target:HasTag("stump") then
            target:Remove()
        end

        did_hit = true
    elseif self.canpick and target.components.pickable and target.components.pickable:CanBePicked()
            and not target:HasTag("intense") then
		target.components.pickable:Pick(self.inst) --don't pass doer or they'll pocket the loot

        did_hit = true
    elseif doer.components.combat:CanTarget(target) and not doer.components.combat:IsAlly(target) and target.components.combat ~= nil then
        --doer.components.combat:DoAttack(target, nil, nil, self.stimuli)
        target.components.combat:GetAttacked(doer, 999, self.inst, self.stimuli, { planar = 999 })

        did_hit = true
    end

    if did_hit then
        if self.onhitfn then
            self.onhitfn(self.inst, doer, target)
        end
    else
        if self.onmissfn then
            self.onmissfn(self.inst, doer, target)
        end
    end
end

local function OnDischarged(inst)
    inst.components.aoetargeting:SetEnabled(false)
end

local function OnCharged(inst)
    inst.components.aoetargeting:SetEnabled(true)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("lunar_spark_blade")
    inst.AnimState:SetBuild("lunar_spark_blade")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetSymbolBloom("glow")
    inst.AnimState:SetSymbolLightOverride("glow", 0.5)


    MakeInventoryFloatable(inst, "med", 0.05, { 1.1, 0.5, 1.1 }, true, -9)

    inst:AddComponent("aoetargeting")
    inst.components.aoetargeting:SetAllowRiding(false)
    inst.components.aoetargeting.reticule.reticuleprefab = "reticuleline"
    inst.components.aoetargeting.reticule.pingprefab = "reticulelineping"
    inst.components.aoetargeting.reticule.targetfn = ReticuleTargetFn
    inst.components.aoetargeting.reticule.mousetargetfn = ReticuleMouseTargetFn
    inst.components.aoetargeting.reticule.updatepositionfn = ReticuleUpdatePositionFn
    inst.components.aoetargeting.reticule.validcolour = { 1, .75, 0, 1 }
    inst.components.aoetargeting.reticule.invalidcolour = { .5, 0, 0, 1 }
    inst.components.aoetargeting.reticule.ease = true
    inst.components.aoetargeting.reticule.mouseenabled = true

    -- if _leap_range > 0 and larger than leap_range should leap
    inst._leap_range = net_float(inst.GUID, "inst._leap_range")
    inst._leap_range:set(-1)

    inst._leap_fx_pos_x = net_float(inst.GUID, "inst._leap_fx_pos_x")
    inst._leap_fx_pos_z = net_float(inst.GUID, "inst._leap_fx_pos_z")
    inst._owner = net_entity(inst.GUID, "inst._owner")
    inst._leap_fx_spawn_event = net_event(inst.GUID, "inst._leap_fx_spawn_event")

    if not TheNet:IsDedicated() then
        inst:ListenForEvent("inst._leap_fx_spawn_event", function()
            local attacker = inst._owner:value()
            if attacker ~= nil and attacker:IsValid() then
                local fx = SpawnAt("moonstorm_ground_lightning_fx",
                    Vector3(inst._leap_fx_pos_x:value(), 0, inst._leap_fx_pos_z:value()))
                fx.Transform:SetRotation(attacker.Transform:GetRotation() - 90)
            end
        end)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.anim_fxs = {
        inst:SpawnChild("lunar_spark_blade_swapanim"),
        inst:SpawnChild("lunar_spark_blade_swapanim")
    }
    inst.anim_fxs[1].AnimState:PlayAnimation("swap_loop1", true)
    inst.anim_fxs[2].AnimState:PlayAnimation("swap_loop2", true)
    for _, v in pairs(inst.anim_fxs) do
        v.entity:AddFollower()
    end

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(51)

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(GetDamage)
    -- inst.components.weapon:SetRange(10, 0)
    inst.components.weapon:SetRange(0)
    inst.components.weapon:SetOnAttack(OnAttack)

    inst:AddComponent("aoeweapon_lunge")
    inst.components.aoeweapon_lunge:SetDamage(34) -- lunge weapon skill damage
    inst.components.aoeweapon_lunge:SetSound("moonstorm/characters/wagstaff/goggles/shoot")
    inst.components.aoeweapon_lunge:SetSideRange(1)
    inst.components.aoeweapon_lunge:SetOnLungedFn(OnLunged)
    inst.components.aoeweapon_lunge:SetOnHitFn(OnLungedHit)
    -- inst.components.aoeweapon_lunge:SetStimuli("electric")
    inst.components.aoeweapon_lunge:SetWorkActions()
    inst.components.aoeweapon_lunge:SetTags("_combat")
    inst.components.aoeweapon_lunge.OnHit = OnHit

    inst:AddComponent("aoespell")
    inst.components.aoespell:SetSpellFn(SpellFn)

    inst:AddComponent("rechargeable")
    inst.components.rechargeable:SetOnDischargedFn(OnDischarged)
    inst.components.rechargeable:SetOnChargedFn(OnCharged)

    inst:AddComponent("dc_chargeable_item")
    inst.components.dc_chargeable_item:SetMax(20)
    -- inst.components.dc_chargeable_item:SetDrainPerSecond(1)
    -- inst.components.dc_chargeable_item:SetResumeDrainCD(2)
    inst.components.dc_chargeable_item:SetOnValChangeFn(OnChargeValChange)
    inst.components.dc_chargeable_item:SetVal(0)

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(350)
    inst.components.finiteuses:SetUses(350)
    inst.components.finiteuses:SetOnFinished(OnFinished)

    local damagetypebonus = inst:AddComponent("damagetypebonus")
    damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.WEAPONS_LUNARPLANT_VS_SHADOW_BONUS)


    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    MakeHauntableLaunch(inst)
    CheckSwapAnims(inst)

    return inst
end

local function animfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("lunar_spark_blade")
    inst.AnimState:SetBuild("lunar_spark_blade")

    inst.AnimState:SetSymbolBloom("glow")
    inst.AnimState:SetSymbolLightOverride("glow", 0.5)


    inst:AddComponent("highlightchild")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

-------------------------------------------------------------------------------------------
-- Unused broken blade code
local function broken_ShouldAcceptItem(inst, item)
    return item.prefab == "security_pulse_cage_full"
end

local function broken_OnGetItemFromPlayer(inst, giver, item)
    local new_blade = SpawnAt("lunar_spark_blade", inst)

    if giver == inst.components.inventoryitem:GetGrandOwner() then
        if giver.components.inventory then
            giver.components.inventory:GiveItem(new_blade)
        end
    end


    inst:Remove()
end

local function brokenfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("lunar_spark_blade")
    inst.AnimState:SetBuild("lunar_spark_blade")
    inst.AnimState:PlayAnimation("broken")

    MakeInventoryFloatable(inst, "med", 0.05, { 1.1, 0.5, 1.1 }, true, -9)


    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    inst:AddComponent("trader")
    inst.components.trader:SetAcceptTest(broken_ShouldAcceptItem)
    inst.components.trader.onaccept = broken_OnGetItemFromPlayer
    inst.components.trader.onrefuse = broken_OnRefuseItem

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("lunar_spark_blade", fn, assets, prefabs),
    Prefab("lunar_spark_blade_swapanim", animfn, assets)
-- Prefab("lunar_spark_blade_broken", brokenfn, assets)
