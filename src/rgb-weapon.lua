local imgui    = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8  = encoding.UTF8
local new = imgui.new

local ffi  = require('ffi')
local hook = require('monethook')
local mem  = require('SAMemory')

mem.require('CPed')

local cast = ffi.cast
local gta  = ffi.load('GTASA')

ffi.cdef[[
    void _Z20RpClumpForAllAtomicsP7RpClumpPFP8RpAtomicS2_PvES3_(RpClump* clump, void*(*cb)(void*, void*), void* data);
    void _Z25RpGeometryForAllMaterialsP10RpGeometryPFP10RpMaterialS2_PvES3_(RpGeometry* geo, void*(*cb)(void*, void*), void* data);
    void* _Z13FindPlayerPedi(int index);
    void  _ZN4CPed6RenderEv(CPed* ped);
]]

local rpGEOMETRY_MODULATE = 0x40

local SW, SH   = getScreenResolution()
local WinState = new.bool(false)
local col      = new.float[4](1.0, 1.0, 1.0, 1.0)
local enabled  = new.bool(true)
local rgbMode  = new.bool(false)
local rgbSpeed = new.float(2.0)

local colorBuf        = ffi.new('RwColor')
local lastWeaponClump = nil

local cbApplyMat = ffi.cast('void*(*)(void*, void*)', function(mat_ptr, data_ptr)
    local mat = cast('RpMaterial*', mat_ptr)
    local c   = cast('RwColor*', data_ptr)
    mat.color.r = c.r; mat.color.g = c.g
    mat.color.b = c.b; mat.color.a = c.a
    return mat_ptr
end)

local cbApplyAtomic = ffi.cast('void*(*)(void*, void*)', function(atomic_ptr, data_ptr)
    local atomic = cast('RpAtomic*', atomic_ptr)
    if atomic.geometry ~= nil then
        atomic.geometry.flags = bit.bor(atomic.geometry.flags, rpGEOMETRY_MODULATE)
        gta._Z25RpGeometryForAllMaterialsP10RpGeometryPFP10RpMaterialS2_PvES3_(atomic.geometry, cbApplyMat, data_ptr)
    end
    return atomic_ptr
end)

local function applyColor(clump, r, g, b, a)
    colorBuf.r = r; colorBuf.g = g; colorBuf.b = b; colorBuf.a = a
    gta._Z20RpClumpForAllAtomicsP7RpClumpPFP8RpAtomicS2_PvES3_(clump, cbApplyAtomic, colorBuf)
end

local pedRenderHook
pedRenderHook = hook.new(
    'void(*)(CPed*)',
    function(ped)
        local playerPed = gta._Z13FindPlayerPedi(0)
        local isPlayer  = playerPed ~= nil and
                          cast('uintptr_t', ped) == cast('uintptr_t', playerPed)

        if isPlayer then
            local weapClump  = ped.pWeaponObject
            local activeSlot = ped.nActiveWeaponSlot

            if weapClump ~= nil and activeSlot > 0 then
                local clumpAddr = tonumber(cast('uintptr_t', weapClump))

                -- weapon change reset old clump ke white
                if lastWeaponClump ~= clumpAddr then
                    if lastWeaponClump ~= nil then
                        applyColor(weapClump, 255, 255, 255, 255)
                    end
                    lastWeaponClump = clumpAddr
                end
                -- attached obj ga works ngentot, gua masih fix

                if enabled[0] then
                    local r, g, b
                    if rgbMode[0] then
                        local t = os.clock() * rgbSpeed[0]
                        r = math.floor(((math.sin(t)          + 1) / 2) * 255)
                        g = math.floor(((math.sin(t + 2.0944) + 1) / 2) * 255)
                        b = math.floor(((math.sin(t + 4.1888) + 1) / 2) * 255)
                    else
                        r = math.floor(col[0] * 255)
                        g = math.floor(col[1] * 255)
                        b = math.floor(col[2] * 255)
                    end
                    applyColor(weapClump, r, g, b, math.floor(col[3] * 255))
                else
                    applyColor(weapClump, 255, 255, 255, 255)
                end
            end
        end

        pedRenderHook(ped)
    end,
    cast('uintptr_t', cast('void*', gta._ZN4CPed6RenderEv))
)

imgui.OnFrame(
    function() return WinState[0] end,
    function()
        imgui.SetNextWindowPos(imgui.ImVec2(SW / 2, SH / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.Begin(u8'Weapon Color', WinState, imgui.WindowFlags.NoCollapse)

        imgui.Checkbox(u8'Enable', enabled)
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.Checkbox(u8'RGB Mode', rgbMode)
        if rgbMode[0] then
            imgui.PushItemWidth(imgui.GetContentRegionAvail().x)
            imgui.SliderFloat(u8'##speed', rgbSpeed, 0.5, 10.0, u8'Speed: %.1f')
            imgui.PopItemWidth()
        else
            imgui.PushItemWidth(imgui.GetContentRegionAvail().x)
            imgui.ColorEdit4(u8'##color', col)
            imgui.PopItemWidth()
        end

        imgui.End()
    end
)

function main()
    sampRegisterChatCommand('weaprgb', function()
        WinState[0] = not WinState[0]
    end)
    while true do wait(0) end
end
