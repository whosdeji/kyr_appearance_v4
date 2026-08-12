local cam = nil
local camZoom = Config.DefaultZoom
local focusPed = nil
local currentFocus = 'head' -- 'head' | 'body' | 'legs' | 'feet'

local BONES = {
    head = 0x796e,  -- SKEL_Head
    body = 0x60F2,  -- SKEL_Spine3 (upper torso)
    legs = 0xE0FD,  -- SKEL_Pelvis
    feet = 0xCC4D,  -- SKEL_R_Foot
}

local HEIGHT_OFFSET = {
    head = 0.02,
    body = 0.10,
    legs = 0.05,
    feet = 0.08,
}

local DEFAULT_ZOOM = {
    head = 1.4,
    body = 2.4,
    legs = 2.2,
    feet = 1.8,
}

local CAM_ANGLE = 0.0

local function getCamPositions(ped)
    local bone = BONES[currentFocus] or BONES.head
    local coords = GetPedBoneCoords(ped, bone, 0.0, 0.0, 0.0)
    local rad = math.rad(CAM_ANGLE)
    local height = HEIGHT_OFFSET[currentFocus] or 0.02

    local camCoords = vector3(
        coords.x + (math.sin(rad) * camZoom),
        coords.y - (math.cos(rad) * camZoom),
        coords.z + height
    )

    return camCoords, coords
end

function CreateAppearanceCam(ped)
    focusPed = ped
    currentFocus = 'head'
    camZoom = DEFAULT_ZOOM.head or Config.DefaultZoom

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    local camCoords, lookAt = getCamPositions(ped)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
    SetCamFov(cam, 45.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
end

function UpdateAppearanceCam()
    if not cam or not focusPed then return end

    local camCoords, lookAt = getCamPositions(focusPed)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
end

function SetCamFocus(focus)
    if not focus or not BONES[focus] then return end
    currentFocus = focus
    camZoom = DEFAULT_ZOOM[focus] or Config.DefaultZoom
    UpdateAppearanceCam()
end

function RotatePed(delta)
    if not focusPed then return end

    local heading = (GetEntityHeading(focusPed) + (delta or 0.0)) % 360.0
    SetEntityHeading(focusPed, heading)
    UpdateAppearanceCam()
end

function ZoomAppearanceCam(delta)
    camZoom = math.max(Config.MinZoom, math.min(Config.MaxZoom, camZoom + (delta or 0.0)))
    UpdateAppearanceCam()
end

function DestroyAppearanceCam()
    if cam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    focusPed = nil
    currentFocus = 'head'
end