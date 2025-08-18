local AssetUtil = require("utils/assetutil")
local TheNet = GLOBAL.TheNet

--注册预制体
PrefabFiles = {
    "dreadsword",
    "dread_pickaxe",
    "dreadsword_wave",
    "dread_lantern",
    "lunar_spark_blade",
    "dread_cloak",
    "dread_axe",
    "aoc_skins",
    "nightmare_hat",
    "dread_spear",
    "woods_shadeling",
    "knightmare",
    "shroudlog",
    "knightmare_gears",

    "knightmare_clue_map",
    "knightmare_clue_ground_fx",

    "boat_aoc",
}

Assets = {
    -- inventoryimages
    Asset("IMAGE", "images/apocalypse-of-the-constant.tex"),
    Asset("ATLAS", "images/apocalypse-of-the-constant.xml"),
    Asset("ATLAS_BUILD", "images/apocalypse-of-the-constant.xml", 256), -- for minisign
    Asset("ANIM", "anim/lunar_spark_meter.zip"),
}

AssetUtil.RegisterImageAtlas("images/apocalypse-of-the-constant.xml")

local sounds = {
    Asset("SOUND", "sound/Aoc.fsb"),
    Asset("SOUNDPACKAGE", "sound/Aoc.fev")
}

if not TheNet:IsDedicated() then
    for _, asset in ipairs(sounds) do
        table.insert(Assets, asset)
    end
end
