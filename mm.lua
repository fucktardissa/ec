script_key="XqUVAxhBRryMRCaREydzjksGtSsUpWkH";
setfpscap(60)  -- number = fps

getgenv().bgsInfConfig = {
    ADD_FRIEND = true,
    AUTO_UPDATE_RESTART = true,
    FOCUS_DICE = true,
    SUPER_TICKET_MINIGAME = "Robot Claw",
    GIVE_BUBBLE_SHRINE = {"Coins", "Tickets", "Mythic", "Speed", "Lucky"},
    MIN_GIVE_BUBBLE_SHRINE = 2000,

    PURCHASE_ALIENSHOP = true,
    PURCHASE_BLACKMARKET = true,
    PURCHASE_DICE_MERCHANT = true,
    PURCHASE_TRAVELING_MERCHANT = true,
    PURCHASE_STARSHOP_SLOT = 14,
    RESTOCK_SHOP = "Festival Shop",

    USE_ROYAL_KEY = false,
    USE_DICE_KEY = false,
    USE_SUPER_KEY = true,  -- Enabled as requested
    USE_GOLDEN_KEY = false,
    USE_MYSTERY_BOX = true,
    IGNORE_MYSTERY_BOX_GEM_CAP = false,

    RARITY_TO_DELETE = {"Common", "Unique", "Rare", "Epic", "Legendary"},
    RARITY_TO_SHINY = {"Common", "Unique", "Rare", "Epic", "Legendary"},
    MAX_LEGENDARY_TIER_TO_DELETE = 2,
    DELETE_LEGENDARY_SHINY = true,
    DELETE_LEGENDARY_MYTHIC = true,

    -- Rift Features (Added from your latest script)
    ENCHANT_TEAMUP = true,
    ENCHANT_TEAMUP_TIER = 3,
    AUTO_BOUNTY_RIFT = true,
    MIN_RIFT_MULTIPLIER = 10,
    RIFT_EGGS = {"Cyber Egg"},
    SUMMON_RIFT_EGG = "Cyber Egg",
    SUMMON_RIFT_LUCK = 25,
    SUMMON_RIFT_TIME = 30,

    HATCH_1X_EGG = {"Candy Egg"},
    ALWAYS_INFINITY_ELIXIR = true,
    ALWAYS_EGG_ELIXIR = true,
    ALWAYS_SECRET_ELIXIR = true,
    INFINITY_EGG_TYPE = "World1",

    -- Additional features from second script
    ENABLE_EXIT = false,
    DO_BUBBLE_GUM = false,
    IGNORE_WORLD_CHEST = false,
    SERVERHOP_EGG = false,
    IGNORE_EQUIP_BEST_PET = true,
    AUTO_BOUNTY_1X = false,
    AUTO_COLLECT_WORLD_REWARDS = false,
    IGNORE_SEASON_CHALLENGES = false,
    AUTO_INDEX = true,

    -- Webhook settings
    WEBHOOK_URL = "",
    DISCORD_ID = "",
    WEBHOOK_NOTE = "",
    WEBHOOK_ODDS = "25m",
    SHOW_PET_WEBHOOK_USERNAME = false,
}

loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/e2d15fd8d5fd053a359cc3e296c68150.lua"))()
